extends RefCounted
class_name GameplayEvent

## 一次事件的路由与数据快照。通过 getter 读取，不改写已发送的事件。
enum Scope { LOCAL, GLOBAL }

var _event_id: StringName
var _source: Node
var _target: Node
var _scope: Scope
var _context: Dictionary

func _init(event_id: StringName, target: Node = null, source: Node = null, scope: Scope = Scope.LOCAL, context: Dictionary = {}) -> void:
	_event_id = event_id
	_target = target
	_source = source
	_scope = scope
	_context = context.duplicate(true)

func get_event_id() -> StringName:
	return _event_id

func get_source() -> Node:
	return _source if is_instance_valid(_source) else null

func get_target() -> Node:
	return _target if is_instance_valid(_target) else null

func get_scope() -> Scope:
	return _scope

## 每个接收者取得独立字典；对象载荷仍按身份共享，不隐式复制游戏对象。
func get_context() -> Dictionary:
	var snapshot: Dictionary = _context.duplicate(true)
	snapshot["source"] = get_source()
	snapshot["target"] = get_target()
	snapshot["scope"] = &"global" if _scope == Scope.GLOBAL else &"local"
	if _scope == Scope.LOCAL:
		snapshot["entity"] = get_target()
	return snapshot

func is_valid() -> bool:
	return not _event_id.is_empty() and (_scope == Scope.GLOBAL or (_scope == Scope.LOCAL and is_instance_valid(_target)))
