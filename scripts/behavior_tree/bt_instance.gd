extends RefCounted
class_name GAS_BTInstance

var agent: Node
## [可选] 行为树的拥有者/上下文节点（通常是 AbilityComponent, AIController 或 AbilityInstance）
## 用于提供除 agent (操作对象) 之外的上下文信息
var owner_node: Object = null
var tree_root: GAS_BTNode
var blackboard: GAS_BTBlackboard

# 当前正在运行的节点路径（用于判断优先级）
var active_nodes: Array[GAS_BTNode] = []

# 已注册的观察者列表
var _observers: Array[GAS_BTNode] = []

# 节点状态记录（用于判断节点是否在运行）
var _node_status: Dictionary = {}

# 节点执行记录（用于调试面板）
var execution_history: Array[Dictionary] = []
var _max_history_size: int = 100
var _current_frame: int = 0

func _init(p_agent: Node, p_tree_root: GAS_BTNode, p_blackboard: GAS_BTBlackboard = null, p_owner_node: Object = null) -> void:
	agent = p_agent
	tree_root = p_tree_root
	blackboard = p_blackboard if is_instance_valid(p_blackboard) else GAS_BTBlackboard.new()
	owner_node = p_owner_node
	blackboard.value_changed.connect(_on_blackboard_changed)

func tick(delta: float) -> int:
	if not tree_root or not is_instance_valid(agent):
		return GAS_BTNode.Status.FAILURE

	_current_frame += 1

	# 从 Root 开始 Tick
	var result = tree_root.tick(self, delta)

	return result

# 只重置树的执行进度（软重置）
func reset_tree():
	if is_instance_valid(tree_root):
		tree_root.reset(self)

func set_node_status(node: GAS_BTNode, status: int) -> void:
	_node_status[node] = status

func get_node_status(node: GAS_BTNode, default: int = -1) -> int:
	return _node_status.get(node, default)

func has_node_status(node: GAS_BTNode) -> bool:
	return _node_status.has(node)

func erase_node_status(node: GAS_BTNode) -> void:
	_node_status.erase(node)

func clear_node_status() -> void:
	_node_status.clear()

## 记录节点执行（由 GAS_BTNode.tick 调用）
func record_node_execution(node: GAS_BTNode, status: int) -> void:
	_record_execution(node, status)

## 注册观察者
func register_observer(observer: GAS_BTNode) -> void:
	if not observer.has_method("on_blackboard_change"):
		push_warning("Observer does not have on_blackboard_change method")
		return
	if observer not in _observers:
		_observers.append(observer)

## 注销观察者
func unregister_observer(observer: GAS_BTNode) -> void:
	if not observer.has_method("on_blackboard_change"):
		push_warning("Observer does not have on_blackboard_change method")
		return
	_observers.erase(observer)

func evaluate_interruption(observer: GAS_BTNode, new_status: int):
	# 这里是基于事件行为树最复杂的地方：判定优先级
	# 注意：只有 GAS_BTObserver 类型的观察者才支持中断逻辑
	# GAS_BTWaitSignal 等节点只监听变化，不触发中断
	if not observer is GAS_BTObserver:
		return
	
	var bt_observer = observer as GAS_BTObserver
	match bt_observer.abort_type:
		GAS_BTObserver.AbortType.SELF:
			# 如果观察者自己正在运行（是 active_nodes 的一部分）
			# 且条件变成了 FAILURE，则中断自己
			if _is_active(observer) and new_status == GAS_BTNode.Status.FAILURE:
				_abort_execution(observer)

		GAS_BTObserver.AbortType.LOWER_PRIORITY:
			# 如果观察者当前没有运行（说明之前的条件是 Failure）
			# 现在条件变成了 SUCCESS，且当前运行的节点优先级比观察者低
			# 则中断当前节点，切回观察者所在的分支
			if not _is_active(observer) and new_status == GAS_BTNode.Status.SUCCESS:
				# 简单的优先级判定：在标准行为树中，
				# 如果 Observer 是 Selector 的左侧子节点，而当前运行的是右侧子节点，
				# 则 Observer 优先级更高。
				if _is_higher_priority(observer):
					_abort_execution(observer)

## 获取执行历史（用于调试面板）
func get_execution_history() -> Array[Dictionary]:
	return execution_history.duplicate()

## 内部方法：记录执行历史
func _record_execution(node: GAS_BTNode, status: int) -> void:
	if not is_instance_valid(node):
		return

	var timestamp = Time.get_ticks_msec() / 1000.0  # 转换为秒

	# 检查是否与上一条记录相同（避免重复记录）
	if execution_history.size() > 0:
		var last_record = execution_history[-1]
		if last_record.get("node") == node and last_record.get("status") == status:
			# 相同节点相同状态，只更新时间戳
			last_record["timestamp"] = timestamp
			last_record["frame"] = _current_frame
			return

	# 添加新记录
	execution_history.append({
		"node": node,
		"status": status,
		"timestamp": timestamp,
		"frame": _current_frame
	})

	# 限制历史记录大小
	if execution_history.size() > _max_history_size:
		execution_history.pop_front()

func _is_active(node: GAS_BTNode) -> bool:
	return node in active_nodes

func _is_higher_priority(observer: GAS_BTNode) -> bool:
	# 这是一个简化的逻辑，实际上需要根据树的结构判断
	# 只要 Observer 不在 active_nodes 里，通常意味着
	# 它是某个 Selector 左侧失败的分支，现在它想变成功，
	# 那么它就有资格打断右侧正在运行的分支。
	return true 

## 中断执行
func _abort_execution(source_node: GAS_BTNode):
	# 强制重置树，或者重置到特定节点
	print("ABORT triggered by: ", source_node)
	reset_tree() # 简单粗暴：重置整棵树，下一帧 tick 会自动走进新分支

## 黑板变化时通知观察者
func _on_blackboard_changed(key: String, value: Variant) -> void:
	# 当黑板变化时，通知所有注册的观察者
	# 注意：为了防止遍历中修改数组，最好用 duplicate
	for obs in _observers.duplicate():
		if is_instance_valid(obs) and obs.has_method("on_blackboard_change"):
			obs.on_blackboard_change(self, key)
