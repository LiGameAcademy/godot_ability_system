extends RefCounted
class_name GAS_BTInstance

var agent: Node
var tree_root: GAS_BTNode
var blackboard: GAS_BTBlackboard

# 当前正在运行的节点路径（用于判断优先级）
var active_nodes: Array[GAS_BTNode] = []

# 已注册的观察者列表
var _observers: Array[GAS_BTNode] = []
var _parents: Dictionary[GAS_BTNode, GAS_BTNode] = {}
var _failed_observers: Array[GAS_BTObserver] = []
var _pending_interruptions: Array[GAS_BTObserver] = []
var _is_ticking: bool = false
var _processing_abort: bool = false

# 节点状态记录（用于判断节点是否在运行）
var _node_status: Dictionary = {}

# 节点执行记录（用于调试面板）
var execution_history: Array[Dictionary] = []
var _max_history_size: int = 100
var _current_frame: int = 0

func _init(p_agent: Node, p_tree_root: GAS_BTNode, p_blackboard: GAS_BTBlackboard = null) -> void:
	agent = p_agent
	tree_root = p_tree_root
	blackboard = p_blackboard if is_instance_valid(p_blackboard) else GAS_BTBlackboard.new()
	blackboard.value_changed.connect(_on_blackboard_changed)
	for warning: String in get_configuration_warnings():
		push_warning("BehaviorTree: " + warning)
	_index_tree(tree_root)

## 配置诊断只读，可以供编辑器或宿主工具展示。
func get_configuration_warnings() -> PackedStringArray:
	return GAS_BTTreeValidator.get_warnings(tree_root)

func tick(delta: float) -> int:
	if not tree_root or not is_instance_valid(agent):
		return GAS_BTNode.Status.FAILURE

	_current_frame += 1

	# 从 Root 开始 Tick
	_is_ticking = true
	var result: int = tree_root.tick(self, delta)
	var pending: Array[GAS_BTObserver] = _pending_interruptions.duplicate()
	_pending_interruptions.clear()
	for observer: GAS_BTObserver in pending:
		var status: int = GAS_BTNode.Status.SUCCESS if observer.check_condition(self) else GAS_BTNode.Status.FAILURE
		_apply_interruption(observer, status)
	_is_ticking = false
	if result != GAS_BTNode.Status.RUNNING:
		_failed_observers.clear()
	return result

# 只重置树的执行进度（软重置）
func reset_tree() -> void:
	if is_instance_valid(tree_root):
		tree_root.reset(self)
	_failed_observers.clear()
	_pending_interruptions.clear()

func set_node_status(node: GAS_BTNode, status: int) -> void:
	if not _node_status.has(node) and (node is GAS_BTSelector or node is GAS_BTDynamicSelector):
		_forget_failed_observers(node)
	_node_status[node] = status
	if node not in active_nodes:
		active_nodes.append(node)

func get_node_status(node: GAS_BTNode, default: int = -1) -> int:
	return _node_status.get(node, default)

func has_node_status(node: GAS_BTNode) -> bool:
	return _node_status.has(node)

func erase_node_status(node: GAS_BTNode) -> void:
	_node_status.erase(node)
	active_nodes.erase(node)

func clear_node_status() -> void:
	_node_status.clear()
	active_nodes.clear()

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

func evaluate_interruption(observer: GAS_BTNode, new_status: int) -> void:
	if not observer is GAS_BTObserver:
		return
	var condition: GAS_BTObserver = observer as GAS_BTObserver
	if _is_ticking or _processing_abort:
		if condition not in _pending_interruptions:
			_pending_interruptions.append(condition)
		return
	_apply_interruption(condition, new_status)

## 只有实际检查失败的高优先级条件才参与后续事件检查。
func watch_failed_observer(observer: GAS_BTObserver) -> void:
	if observer.abort_type == GAS_BTObserver.AbortType.LOWER_PRIORITY and observer not in _failed_observers:
		_failed_observers.append(observer)

func _apply_interruption(observer: GAS_BTObserver, new_status: int) -> void:
	match observer.abort_type:
		GAS_BTObserver.AbortType.SELF:
			if _is_active(observer) and new_status == GAS_BTNode.Status.FAILURE:
				_abort_execution(observer)
		GAS_BTObserver.AbortType.LOWER_PRIORITY:
			if not _is_active(observer) and new_status == GAS_BTNode.Status.SUCCESS and _is_higher_priority(observer):
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
	return is_instance_valid(_find_priority_scope(observer))

## 找到真正拥有更低优先级活动分支的公共 Selector。
func _find_priority_scope(observer: GAS_BTNode) -> GAS_BTComposite:
	var branch: GAS_BTNode = observer
	var parent: GAS_BTNode = _parents.get(branch)
	while is_instance_valid(parent):
		if parent is GAS_BTSelector or parent is GAS_BTDynamicSelector:
			var selector: GAS_BTComposite = parent as GAS_BTComposite
			var observer_index: int = selector.children.find(branch)
			var active_index: int = selector.children.size()
			for active: GAS_BTNode in active_nodes:
				var active_branch: GAS_BTNode = _branch_under(selector, active)
				var index: int = selector.children.find(active_branch)
				if index >= 0:
					active_index = mini(active_index, index)
			if observer_index >= 0 and active_index > observer_index and active_index < selector.children.size():
				return selector
		branch = parent
		parent = _parents.get(branch)
	return null

func _branch_under(parent: GAS_BTNode, node: GAS_BTNode) -> GAS_BTNode:
	var branch: GAS_BTNode = node
	while is_instance_valid(branch):
		var ancestor: GAS_BTNode = _parents.get(branch)
		if ancestor == parent:
			return branch
		branch = ancestor
	return null

func _index_tree(node: GAS_BTNode, parent: GAS_BTNode = null) -> void:
	if not is_instance_valid(node) or _parents.has(node):
		return
	_parents[node] = parent
	if node is GAS_BTComposite:
		for child: GAS_BTNode in (node as GAS_BTComposite).children:
			_index_tree(child, node)
	elif node is GAS_BTDecorator:
		_index_tree((node as GAS_BTDecorator).child, node)

func _forget_failed_observers(root: GAS_BTNode) -> void:
	for observer: GAS_BTObserver in _failed_observers.duplicate():
		if observer == root or is_instance_valid(_branch_under(root, observer)):
			_failed_observers.erase(observer)

## 只退出条件自身或所属 Selector，保留祖先 Sequence 的已完成进度。
func _abort_execution(source_node: GAS_BTNode) -> void:
	var observer: GAS_BTObserver = source_node as GAS_BTObserver
	var scope: GAS_BTNode = observer
	if observer.abort_type == GAS_BTObserver.AbortType.LOWER_PRIORITY:
		scope = _find_priority_scope(observer)
	if not is_instance_valid(scope):
		return
	_processing_abort = true
	scope.reset(self)
	_forget_failed_observers(scope)
	_processing_abort = false

## 活动观察者与当前 Selector 中实际失败过的条件共同接收变化。
func _on_blackboard_changed(key: String, _value: Variant) -> void:
	var observers: Array[GAS_BTNode] = _observers.duplicate()
	for observer: GAS_BTObserver in _failed_observers:
		if observer not in observers and _is_higher_priority(observer):
			observers.append(observer)
	for observer: GAS_BTNode in observers:
		if is_instance_valid(observer) and observer.has_method("on_blackboard_change"):
			observer.on_blackboard_change(self, key)
