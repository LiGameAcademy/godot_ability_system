extends Node

## 项目级事件入口。角色也可用自己的 StatusComponent.trigger_event，绕开此总线。
var _dispatcher: GameplayEventDispatcher = GameplayEventDispatcher.new()

# ========== 统一游戏事件系统 ==========
## 统一游戏事件信号
## 兼容旧观察接口；状态路由使用下面的带类型信号。
## [param] event_type: StringName 事件类型，如 "damage_applied", "vital_modified" 等
## [param] context: Dictionary 事件上下文，包含事件相关的所有信息
signal game_event_occurred(event_type: StringName, context: Dictionary)
signal gameplay_event_occurred(event: GameplayEvent)
signal event_rejected(event_id: StringName, reason: StringName, diagnostic: Dictionary)

func _init() -> void:
	_dispatcher.event_delivered.connect(_on_event_delivered)
	_dispatcher.event_rejected.connect(_on_event_rejected)

func send_event(event: GameplayEvent) -> bool:
	return _dispatcher.dispatch(event)

func trigger_local_event(event_id: StringName, target: Node, context: Dictionary = {}, source: Node = null) -> bool:
	return send_event(GameplayEvent.new(event_id, target, source, GameplayEvent.Scope.LOCAL, context))

func trigger_global_event(event_id: StringName, context: Dictionary = {}, source: Node = null) -> bool:
	return send_event(GameplayEvent.new(event_id, null, source, GameplayEvent.Scope.GLOBAL, context))

## 触发游戏事件（统一接口）
## [param] event_or_type: Variant 事件类型（StringName）
## [param] context: Variant 事件上下文（Dictionary，可选）
func trigger_game_event(event_type: StringName, context: Variant = {}) -> void:
	if not context is Dictionary:
		push_warning("AbilityEventBus: Event context must be a Dictionary")
		return
	var data: Dictionary = context
	var scope_value: Variant = data.get("scope", &"local")
	var scope: StringName = &""
	if scope_value is String or scope_value is StringName:
		scope = StringName(scope_value)
	elif scope_value is int:
		if int(scope_value) == GameplayEvent.Scope.LOCAL:
			scope = &"local"
		elif int(scope_value) == GameplayEvent.Scope.GLOBAL:
			scope = &"global"
	var target_value: Variant = data.get("target", data.get("entity"))
	var source_value: Variant = data.get("source", data.get("instigator", target_value))
	if source_value != null and not source_value is Node:
		push_warning("AbilityEventBus: Event source must be a Node or null")
		return
	var source: Node = source_value as Node if is_instance_valid(source_value) else null
	if scope == &"global":
		trigger_global_event(event_type, data, source)
	elif scope == &"local":
		var target: Node = target_value as Node if target_value is Node and is_instance_valid(target_value) else null
		trigger_local_event(event_type, target, data, source)
	else:
		push_warning("AbilityEventBus: Unknown event scope")

func _on_event_delivered(event: GameplayEvent) -> void:
	gameplay_event_occurred.emit(event)
	game_event_occurred.emit(event.get_event_id(), event.get_context())

func _on_event_rejected(event_id: StringName, reason: StringName, diagnostic: Dictionary) -> void:
	event_rejected.emit(event_id, reason, diagnostic)
