extends Node
class_name GameplayStatusComponent

## 状态组件
## 管理实体的所有状态（Buff/Debuff）

var _active_statuses: Dictionary[StringName, GameplayStatusInstance] = {}
var _has_event_listening_statuses: bool = false  # 是否有需要监听事件的状态
var _exiting: bool = false
var _replacing: bool = false
@export var receive_bus_events: bool = true
var _event_dispatcher: GameplayEventDispatcher = GameplayEventDispatcher.new()

signal status_applied(status_id: StringName, instance: GameplayStatusInstance)
signal status_removed(status_id: StringName)
signal status_stacked(status_id: StringName, new_stacks: int)
signal gameplay_event_occurred(event: GameplayEvent)
signal event_rejected(event_id: StringName, reason: StringName, diagnostic: Dictionary)

func _init() -> void:
	_event_dispatcher.event_delivered.connect(_on_local_event)
	_event_dispatcher.event_rejected.connect(_on_event_rejected)

func _ready() -> void:
	_exiting = false
	if receive_bus_events and not AbilityEventBus.gameplay_event_occurred.is_connected(_on_gameplay_event):
		AbilityEventBus.gameplay_event_occurred.connect(_on_gameplay_event)

func _exit_tree() -> void:
	_exiting = true
	if AbilityEventBus.gameplay_event_occurred.is_connected(_on_gameplay_event):
		AbilityEventBus.gameplay_event_occurred.disconnect(_on_gameplay_event)
	for status_id: StringName in _active_statuses.keys():
		remove_status(status_id)

func _process(delta: float) -> void:
	# 统一更新所有状态的计时器
	var statuses_to_remove: Array[StringName] = []

	for status_id: StringName in _active_statuses.keys():
		var instance: GameplayStatusInstance = _active_statuses.get(status_id)
		if not is_instance_valid(instance):
			statuses_to_remove.append(status_id)
			continue
		# 调用状态的 update 方法
		var should_remove: bool = instance.update(delta)
		if should_remove:
			statuses_to_remove.append(status_id)

	# 移除已过期的状态
	for status_id: StringName in statuses_to_remove:
		remove_status(status_id)

func apply_status(gsd: GameplayStatusData, instigator: Node, stacks: int = 1, context: Dictionary = {}) -> GameplayStatusInstance:
	if _exiting or _replacing or not is_instance_valid(get_parent()):
		return null
	if not is_instance_valid(gsd):
		push_error("GameplayStatusComponent: GameplayStatusData is not valid!")
		return null
	
	var existing: GameplayStatusInstance = get_status(gsd.status_id) if not gsd.status_id.is_empty() else null
	if is_instance_valid(existing) and is_instance_valid(existing.status_data):
		if existing.status_data.priority > gsd.priority:
			return null
		if existing.status_data.priority == gsd.priority and _apply_stacking_for_existing_status(gsd.status_id, gsd, stacks):
			return null
	var removals: Array[GameplayStatusInstance] = _get_conflicting_statuses(gsd)
	if is_instance_valid(existing) and not removals.has(existing):
		removals.append(existing)
	var ignored_sources: Array[StringName] = []
	for instance: GameplayStatusInstance in removals:
		if instance.status_data.priority > gsd.priority:
			return null
		ignored_sources.append(instance.get_tag_source_id())
	# 先排除本容器将释放的来源，其他来源仍然有权阻止新增标签。
	if gsd.duration != 0.0 and not TagManager.can_add_tags(get_parent(), gsd.tags, ignored_sources):
		return null
	_replacing = true
	for instance: GameplayStatusInstance in removals:
		if get_status(instance.status_data.status_id) == instance:
			remove_status(instance.status_data.status_id)
		if not is_instance_valid(self):
			return null
	_replacing = false
	if not is_instance_valid(get_parent()) or _exiting:
		return null
	# 移除通知里的外部修改不属于可回滚事务；再次确认新的标签仍可获得。
	if gsd.duration != 0.0 and not TagManager.can_add_tags(get_parent(), gsd.tags):
		return null
	return _create_and_apply_new_status_instance(gsd, instigator, stacks, context)

func remove_status(status_id: StringName) -> bool:
	var instance: GameplayStatusInstance = _active_statuses.get(status_id)
	if not is_instance_valid(instance): 
		return false
		
	_active_statuses.erase(status_id)
	instance.remove()
	if not is_instance_valid(self):
		return true
	status_removed.emit(status_id)

	# 检查是否还有需要监听事件的状态
	_update_event_listening_status()

	# 触发统一游戏事件：status_removed
	AbilityEventBus.trigger_game_event(&"status_removed", {
		"entity": get_parent(),
		"status_id": status_id
	})
	return true
	
func remove_statuses_by_tags(tags_to_remove: Array[StringName]) -> void:
	for status_id: StringName in _active_statuses.keys():
		var instance: GameplayStatusInstance = _active_statuses.get(status_id)
		if not is_instance_valid(instance): 
			continue
		var gsd: GameplayStatusData = instance.status_data
		# 检查这个Status的tags是否与我们要移除的tags有交集
		for tag: StringName in gsd.tags:
			if tags_to_remove.has(tag):
				# 找到了一个匹配！移除这个Status
				remove_status(status_id)
				break  # 移动到下一个状态实例

## 获取所有激活的状态
func get_active_statuses() -> Array[GameplayStatusInstance]:
	return _active_statuses.values()

## 获取指定状态
func get_status(status_id: StringName) -> GameplayStatusInstance:
	return _active_statuses.get(status_id, null)

## 检查是否有指定状态
func has_status(status_id: StringName) -> bool:
	return _active_statuses.has(status_id)

## 获取随机状态
## [param] is_debuff: bool 是否只获取Debuff
func get_random_status(is_debuff: bool = false, debuff_tag : String = "status.debuff") -> GameplayStatusInstance:
	if _active_statuses.size() == 0:
		return null

	var statuses: Array[GameplayStatusInstance] = []
	for status: GameplayStatusInstance in _active_statuses.values():
		if is_debuff and status.status_data.tags.has(debuff_tag):
			statuses.append(status)

	if statuses.size() == 0:
		return null

	return statuses.pick_random()

## 处理事件（供外部调用，触发事件监听型效果）
func handle_event(event_id: StringName, context: Dictionary) -> void:
	trigger_event(event_id, context)

## 角色自己的局部入口：不通过全局总线，也能与嵌套的总线事件共用链预算。
func trigger_event(event_id: StringName, context: Dictionary = {}, source: Node = null) -> bool:
	if _exiting:
		return false
	return _event_dispatcher.dispatch(GameplayEvent.new(event_id, get_parent(), source, GameplayEvent.Scope.LOCAL, context))

func _on_gameplay_event(event: GameplayEvent) -> void:
	if _exiting or not _has_event_listening_statuses or not is_instance_valid(event):
		return
	if event.get_scope() == GameplayEvent.Scope.LOCAL and event.get_target() != get_parent():
		return
	# 快照固定本轮接收者，新建状态留到下一次事件；旧实例不能移除同 ID 的替代者。
	for instance: GameplayStatusInstance in get_active_statuses():
		if not is_instance_valid(self) or _exiting:
			return
		if not is_instance_valid(instance) or not is_instance_valid(instance.status_data):
			continue
		var status_id: StringName = instance.status_data.status_id
		if _active_statuses.get(status_id) != instance:
			continue
		if event.get_scope() == GameplayEvent.Scope.GLOBAL and not instance.status_data.listen_to_global_events:
			continue
		var should_remove: bool = instance.handle_event(event.get_event_id(), event.get_context())
		if not is_instance_valid(self):
			return
		if should_remove and _active_statuses.get(status_id) == instance:
			remove_status(status_id)

func _on_local_event(event: GameplayEvent) -> void:
	_on_gameplay_event(event)
	if is_instance_valid(self):
		gameplay_event_occurred.emit(event)

func _on_event_rejected(event_id: StringName, reason: StringName, diagnostic: Dictionary) -> void:
	event_rejected.emit(event_id, reason, diagnostic)

func _apply_stacking_for_existing_status(status_id: StringName, gsd: GameplayStatusData, stacks: int) -> bool:
	if not _active_statuses.has(status_id):
		return false

	var existing_instance: GameplayStatusInstance = _active_statuses[status_id]
	if not is_instance_valid(existing_instance):
		_active_statuses.erase(status_id)
		return false
	
	# 使用策略模式处理堆叠
	if is_instance_valid(gsd) and is_instance_valid(gsd.stacking_policy):
		var context: Dictionary = {}
		return gsd.stacking_policy.handle_stacking(existing_instance, gsd, stacks, context)

	return true

func _get_conflicting_statuses(gsd: GameplayStatusData) -> Array[GameplayStatusInstance]:
	var result: Array[GameplayStatusInstance] = []
	if gsd.duration == 0.0:
		return result
	for instance: GameplayStatusInstance in get_active_statuses():
		if not is_instance_valid(instance) or not is_instance_valid(instance.status_data):
			continue
		for incoming: StringName in gsd.tags:
			for held: StringName in instance.status_data.tags:
				if TagManager.tags_conflict(incoming, held) and not result.has(instance):
					result.append(instance)
	return result

## 创建并应用新的状态实例
## - 对于有 ID 的状态：根据 duration 决定是否写入 _active_statuses
## - 对于 ID 为空的状态：不会写入 _active_statuses，持续实例由调用方负责移除
func _create_and_apply_new_status_instance(gsd: GameplayStatusData, instigator: Node, stacks: int, context: Dictionary) -> GameplayStatusInstance:
	var instance: GameplayStatusInstance = GameplayStatusInstance.new(gsd, self, instigator, stacks)
	var status_id: StringName = gsd.status_id
	
	# 检查是否需要监听事件
	if gsd.has_event_listening():
		_has_event_listening_statuses = true

	# 仅当状态 ID 非空且有持续时间时才记录到激活状态表
	if not status_id.is_empty() and gsd.duration != 0.0:
		_active_statuses[status_id] = instance

	# 先应用状态（执行效果）
	instance.apply(context)
	if not is_instance_valid(self):
		return instance
	if not instance.is_applied() or instance.is_removed():
		if _active_statuses.get(status_id) == instance:
			_active_statuses.erase(status_id)
		_update_event_listening_status()
		return instance if instance.is_applied() else null
	
	# 发信号和事件（即便 ID 为空，也允许外部根据实例做自定义逻辑）
	status_applied.emit(status_id, instance)

	# 触发统一游戏事件：status_applied
	AbilityEventBus.trigger_game_event(&"status_applied", {
		"entity": get_parent(),
		"status_id": status_id
	})
	
	return instance

## 更新事件监听状态（检查是否还有需要监听事件的状态）
func _update_event_listening_status() -> void:
	_has_event_listening_statuses = false
	for instance : GameplayStatusInstance in _active_statuses.values():
		if is_instance_valid(instance) and is_instance_valid(instance.status_data):
			if instance.has_event_listening():
				_has_event_listening_statuses = true
				break

