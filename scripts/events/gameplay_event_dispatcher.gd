extends RefCounted
class_name GameplayEventDispatcher

## 可由角色自己持有，无需 Autoload。所有同步嵌套的派发共用当前链预算。
const MAX_EVENTS_PER_CHAIN: int = 64
const MAX_NESTING_DEPTH: int = 16
static var _depth: int = 0
static var _delivered: int = 0
static var _chain_id: int = 0
static var _root_event: StringName = &""
static var _reported_budget: bool = false
static var _reporting_rejection: bool = false

signal event_delivered(event: GameplayEvent)
signal event_rejected(event_id: StringName, reason: StringName, diagnostic: Dictionary)

## true 表示接受派发，不代表某个状态监听或应用了效果。
func dispatch(event: GameplayEvent) -> bool:
	# 角色可能在接收效果时退出；派发栈仍需拥有此 RefCounted，完成预算收尾。
	var _keep_alive: GameplayEventDispatcher = self
	# 诊断订阅者不能通过诊断再制造事件链。
	if _reporting_rejection:
		return false
	if _depth == 0:
		_chain_id += 1
		_delivered = 0
		_root_event = event.get_event_id() if is_instance_valid(event) else &""
		_reported_budget = false
	if not is_instance_valid(event) or not event.is_valid():
		_reject(event, &"invalid_event")
		return false
	if _depth >= MAX_NESTING_DEPTH or _delivered >= MAX_EVENTS_PER_CHAIN:
		if not _reported_budget:
			_reported_budget = true
			_reject(event, &"chain_budget_exceeded")
		return false
	_depth += 1
	_delivered += 1
	# 同步交付保留受击前修改等既有时序；深度与总数共同限制循环。
	event_delivered.emit(event)
	_depth -= 1
	return true

func _reject(event: GameplayEvent, reason: StringName) -> void:
	var event_id: StringName = event.get_event_id() if is_instance_valid(event) else &""
	var source: Node = event.get_source() if is_instance_valid(event) else null
	var target: Node = event.get_target() if is_instance_valid(event) else null
	var diagnostic: Dictionary = {
		"chain_id": _chain_id, "root_event": _root_event, "event_id": event_id,
		"source_id": source.get_instance_id() if is_instance_valid(source) else 0,
		"target_id": target.get_instance_id() if is_instance_valid(target) else 0,
		"depth": _depth, "delivered": _delivered,
	}
	_reporting_rejection = true
	push_warning("GameplayEvent: %s; chain=%d root=%s event=%s source=%d target=%d depth=%d delivered=%d" % [reason, _chain_id, _root_event, event_id, diagnostic["source_id"], diagnostic["target_id"], _depth, _delivered])
	event_rejected.emit(event_id, reason, diagnostic)
	_reporting_rejection = false
