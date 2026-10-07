extends RegressionCase

class CountEffect extends GameplayEffect:
	func _apply_result(target: Node, _instigator: Node, context: Dictionary) -> GameplayEffectResult:
		target.set_meta(&"event_calls", int(target.get_meta(&"event_calls", 0)) + 1)
		var nested: Dictionary = context.get("nested", {})
		nested["value"] = 99
		return GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED)

class ChainEffect extends GameplayEffect:
	@export var via_bus: bool = false
	func _apply_result(target: Node, _instigator: Node, context: Dictionary) -> GameplayEffectResult:
		target.set_meta(&"chain_calls", int(target.get_meta(&"chain_calls", 0)) + 1)
		var other: GameplayStatusComponent = target.get_meta(&"chain_other") as GameplayStatusComponent
		if via_bus:
			AbilityEventBus.trigger_local_event(&"issue_45.loop", other.get_parent(), context, target)
		else:
			other.trigger_event(&"issue_45.loop", context, target)
		return GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED)

class ContextFeature extends StatusFeature:
	var writes: bool = false
	func can_trigger_on_event(event_id: StringName) -> bool:
		return event_id == &"issue_45.features"
	func has_event_listening() -> bool:
		return true
	func _handle_event(instance: GameplayStatusInstance, _event_id: StringName, context: Dictionary) -> void:
		if writes:
			context["nested"]["value"] = 99
		else:
			instance.owner_component.get_parent().set_meta(&"observed_value", context["nested"]["value"])

class FreeTargetEffect extends GameplayEffect:
	func _apply_result(target: Node, _instigator: Node, _context: Dictionary) -> GameplayEffectResult:
		target.free()
		return GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED)

class DamageAdjustment extends GameplayEffect:
	func _apply_result(target: Node, _instigator: Node, context: Dictionary) -> GameplayEffectResult:
		var info: GameplayDamageInfo = context["damage_info"] as GameplayDamageInfo
		info.final_damage = 3.0
		target.set_meta(&"damage_events", int(target.get_meta(&"damage_events", 0)) + 1)
		return GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED)

class ReplaceStatusEffect extends GameplayEffect:
	func _apply_result(target: Node, _instigator: Node, context: Dictionary) -> GameplayEffectResult:
		var component: GameplayStatusComponent = context["component"] as GameplayStatusComponent
		var data: GameplayStatusData = context["replacement"] as GameplayStatusData
		component.apply_status(data, target)
		return GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED)

func run() -> void:
	var a: Node = _actor("A")
	var b: Node = _actor("B")
	var first: GameplayStatusComponent = a.get_node("Statuses") as GameplayStatusComponent
	var second: GameplayStatusComponent = b.get_node("Statuses") as GameplayStatusComponent
	first.apply_status(_status(&"issue_45.a"), a)
	second.apply_status(_status(&"issue_45.b"), b)
	var context: Dictionary = {"entity": a, "nested": {"value": 1}}
	AbilityEventBus.trigger_game_event(&"issue_45.hit", context)
	expect(int(a.get_meta(&"event_calls", 0)) == 1, "A local event must trigger A's listening status")
	expect(int(b.get_meta(&"event_calls", 0)) == 0, "A local event must not trigger B's listening status")
	expect(context["nested"]["value"] == 1 and not context.has("stacks") and not context.has("source_id"), "Delivery must not mutate the caller's context or nested dictionaries")
	_test_global_and_snapshots(a, b, first, context)
	_test_chain_budget(a, b, first, second)
	_test_feature_isolation(a, first)
	_test_damage_routing(a, b, first, second)
	_test_replacement_during_delivery(a, first)
	a.free()
	b.free()
	_test_local_without_bus()
	_test_invalid_and_exit()
	_test_damage_target_exit()

func _actor(actor_name: String) -> Node:
	var actor: Node = Node.new()
	actor.name = actor_name
	var component: GameplayStatusComponent = GameplayStatusComponent.new()
	component.name = "Statuses"
	actor.add_child(component)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(actor)
	return actor

func _status(id: StringName, event_id: StringName = &"issue_45.hit", effect: GameplayEffect = null) -> GameplayStatusData:
	var data: GameplayStatusData = GameplayStatusData.new()
	data.status_id = id
	data.duration = 10.0
	var listener: FeatureEventListener = FeatureEventListener.new()
	listener.trigger_on_events = [event_id]
	listener.event_triggered_effects = [effect if is_instance_valid(effect) else CountEffect.new()]
	data.features = [listener]
	return data

func _test_global_and_snapshots(a: Node, b: Node, first: GameplayStatusComponent, context: Dictionary) -> void:
	var global_status: GameplayStatusData = _status(&"issue_45.global")
	global_status.listen_to_global_events = true
	first.apply_status(global_status, a)
	AbilityEventBus.trigger_global_event(&"issue_45.hit", context, b)
	expect(int(a.get_meta(&"event_calls", 0)) == 2 and int(b.get_meta(&"event_calls", 0)) == 0, "A global event must reach only statuses that explicitly accept global scope")
	var event: GameplayEvent = GameplayEvent.new(&"issue_45.hit", b, a, GameplayEvent.Scope.LOCAL, context)
	context["nested"]["value"] = 2
	var snapshot: Dictionary = event.get_context()
	snapshot["nested"]["value"] = 3
	snapshot["target"] = a
	expect(event.get_context()["nested"]["value"] == 1 and event.get_target() == b and event.get_source() == a, "Caller and observer changes must not rewrite a captured route or nested event data")
	AbilityEventBus.send_event(event)
	expect(int(b.get_meta(&"event_calls", 0)) == 1 and int(a.get_meta(&"event_calls", 0)) == 2, "An explicit cross-entity target must route to B while preserving A as source")
	AbilityEventBus.trigger_game_event(&"issue_45.hit", {"scope": "global"})
	expect(int(a.get_meta(&"event_calls", 0)) == 3 and int(b.get_meta(&"event_calls", 0)) == 1, "An explicit legacy global event may omit an entity but still requires listener opt-in")
	AbilityEventBus.trigger_game_event(&"issue_45.hit", {"scope": GameplayEvent.Scope.LOCAL, "target": b, "source": a})
	expect(int(b.get_meta(&"event_calls", 0)) == 2, "Legacy input must accept a typed scope and separate source/target")
	first.remove_status(global_status.status_id)

func _test_chain_budget(a: Node, b: Node, first: GameplayStatusComponent, second: GameplayStatusComponent) -> void:
	var to_b: ChainEffect = ChainEffect.new()
	to_b.via_bus = true
	var to_a: ChainEffect = ChainEffect.new()
	a.set_meta(&"chain_other", second)
	b.set_meta(&"chain_other", first)
	first.apply_status(_status(&"issue_45.loop_a", &"issue_45.loop", to_b), a)
	second.apply_status(_status(&"issue_45.loop_b", &"issue_45.loop", to_a), b)
	var diagnostics: Array[Dictionary] = []
	var on_rejected: Callable = func(id: StringName, reason: StringName, data: Dictionary) -> void:
		if reason == &"chain_budget_exceeded":
			diagnostics.append(data)
			expect(not first.trigger_event(id), "Diagnostic callbacks must not restart a rejected chain")
	AbilityEventBus.event_rejected.connect(on_rejected)
	first.event_rejected.connect(on_rejected)
	second.event_rejected.connect(on_rejected)
	first.trigger_event(&"issue_45.loop", {}, a)
	var calls: int = int(a.get_meta(&"chain_calls", 0)) + int(b.get_meta(&"chain_calls", 0))
	expect(calls == GameplayEventDispatcher.MAX_NESTING_DEPTH and diagnostics.size() == 1, "A cycle spanning local and bus dispatch must stop once at the shared depth budget")
	if not diagnostics.is_empty():
		expect(diagnostics[0]["root_event"] == &"issue_45.loop" and diagnostics[0]["source_id"] != 0 and diagnostics[0]["target_id"] != 0, "Rejected-chain diagnostics must identify its root event, source and target")
	first.remove_status(&"issue_45.loop_a")
	second.remove_status(&"issue_45.loop_b")
	a.remove_meta(&"chain_other")
	b.remove_meta(&"chain_other")
	diagnostics.clear()
	var before: int = int(b.get_meta(&"event_calls", 0))
	var on_burst: Callable = func(event: GameplayEvent) -> void:
		if event.get_event_id() == &"issue_45.burst":
			for _index: int in range(GameplayEventDispatcher.MAX_EVENTS_PER_CHAIN + 5):
				second.trigger_event(&"issue_45.hit", {}, a)
	first.gameplay_event_occurred.connect(on_burst)
	first.trigger_event(&"issue_45.burst", {}, a)
	expect(int(b.get_meta(&"event_calls", 0)) - before == GameplayEventDispatcher.MAX_EVENTS_PER_CHAIN - 1 and diagnostics.size() == 1, "Wide event chains must obey the shared total budget and report only once")
	first.gameplay_event_occurred.disconnect(on_burst)
	AbilityEventBus.event_rejected.disconnect(on_rejected)
	first.event_rejected.disconnect(on_rejected)
	second.event_rejected.disconnect(on_rejected)
	before = int(b.get_meta(&"event_calls", 0))
	second.trigger_event(&"issue_45.hit")
	expect(int(b.get_meta(&"event_calls", 0)) == before + 1, "A new root event must receive a fresh chain budget")

func _test_feature_isolation(actor: Node, component: GameplayStatusComponent) -> void:
	var writer: ContextFeature = ContextFeature.new()
	writer.writes = true
	var reader: ContextFeature = ContextFeature.new()
	var data: GameplayStatusData = GameplayStatusData.new()
	data.status_id = &"issue_45.features"
	data.features = [writer, reader]
	component.apply_status(data, actor)
	component.trigger_event(&"issue_45.features", {"nested": {"value": 1}})
	expect(int(actor.get_meta(&"observed_value", 0)) == 1, "One feature must not rewrite another feature's input")
	component.remove_status(data.status_id)

func _test_local_without_bus() -> void:
	var actor: Node = Node.new()
	var component: GameplayStatusComponent = GameplayStatusComponent.new()
	component.receive_bus_events = false
	actor.add_child(component)
	component.apply_status(_status(&"issue_45.direct"), actor)
	var observations: Array[StringName] = []
	var on_bus: Callable = func(id: StringName, _context: Dictionary) -> void:
		observations.append(id)
	AbilityEventBus.game_event_occurred.connect(on_bus)
	component.trigger_event(&"issue_45.hit")
	expect(int(actor.get_meta(&"event_calls", 0)) == 1 and observations.is_empty(), "Direct local dispatch must work outside the tree without publishing to the bus")
	AbilityEventBus.game_event_occurred.disconnect(on_bus)
	component.remove_status(&"issue_45.direct")
	actor.free()

func _test_damage_routing(a: Node, b: Node, first: GameplayStatusComponent, second: GameplayStatusComponent) -> void:
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	var attribute: GameplayAttribute = GameplayAttribute.new()
	attribute.attribute_id = &"max_health"
	var values: GameplayAttributeSet = GameplayAttributeSet.new()
	values.attributes[attribute] = 100.0
	component.initialize([values], [HealthVital.new()])
	a.add_child(component)
	var health: HealthVital = component.get_vital(&"health") as HealthVital
	first.apply_status(_status(&"issue_45.damage_a", &"damage_received", DamageAdjustment.new()), a)
	second.apply_status(_status(&"issue_45.damage_b", &"damage_received", DamageAdjustment.new()), b)
	var routes: Array[Dictionary] = []
	var on_damage: Callable = func(event: GameplayEvent) -> void:
		if event.get_event_id() == &"damage_received":
			routes.append(event.get_context())
	AbilityEventBus.gameplay_event_occurred.connect(on_damage)
	var info: GameplayDamageInfo = GameplayDamageInfo.new(b, null, 10.0)
	info.final_damage = 10.0
	var applied: float = health.apply_damage(info, a)
	expect(applied == 3.0 and health.current_value == 97.0, "Synchronous damage-received effects must still adjust damage before it is applied")
	expect(int(a.get_meta(&"damage_events", 0)) == 1 and int(b.get_meta(&"damage_events", 0)) == 0, "Health events must carry the receiving entity, not trigger every character")
	if not routes.is_empty():
		expect(routes[0]["target"] == a and routes[0]["source"] == b, "Health events must identify receiver and damage instigator separately")
	else:
		expect(false, "Damage notification must remain observable through the bus")
	AbilityEventBus.gameplay_event_occurred.disconnect(on_damage)
	first.remove_status(&"issue_45.damage_a")
	second.remove_status(&"issue_45.damage_b")

func _test_replacement_during_delivery(actor: Node, component: GameplayStatusComponent) -> void:
	var old: GameplayStatusData = _status(&"issue_45.replace", &"issue_45.replace_event", ReplaceStatusEffect.new())
	var next: GameplayStatusData = _status(old.status_id, &"issue_45.replace_event")
	next.priority = 1
	var original: GameplayStatusInstance = component.apply_status(old, actor)
	var before: int = int(actor.get_meta(&"event_calls", 0))
	component.trigger_event(&"issue_45.replace_event", {"component": component, "replacement": next})
	expect(component.get_status(old.status_id) != original and component.get_status(old.status_id).status_data == next, "A replaced status must not be removed again by its old event receiver")
	expect(int(actor.get_meta(&"event_calls", 0)) == before, "The new instance must wait until the next event instead of receiving the event in progress")
	component.trigger_event(&"issue_45.replace_event")
	expect(int(actor.get_meta(&"event_calls", 0)) == before + 1, "The replacement must receive the next event normally")
	component.remove_status(old.status_id)

func _test_invalid_and_exit() -> void:
	var ghost: Node = Node.new()
	var stale: GameplayEvent = GameplayEvent.new(&"issue_45.hit", ghost)
	ghost.free()
	expect(not AbilityEventBus.send_event(stale), "A captured event with a freed target must be rejected safely")
	expect(not AbilityEventBus.trigger_local_event(&"issue_45.hit", null), "A local event needs an explicit live target")
	AbilityEventBus.trigger_game_event(&"issue_45.hit", "invalid context")
	AbilityEventBus.trigger_game_event(&"issue_45.hit", {"scope": true})
	var actor: Node = _actor("Exit")
	var component: GameplayStatusComponent = actor.get_node("Statuses") as GameplayStatusComponent
	component.apply_status(_status(&"issue_45.free", &"issue_45.exit", FreeTargetEffect.new()), actor)
	component.trigger_event(&"issue_45.exit")
	expect(not is_instance_valid(actor), "Target exit during direct dispatch must retain the dispatcher until its stack finishes")

func _test_damage_target_exit() -> void:
	var actor: Node = _actor("HealthExit")
	var statuses: GameplayStatusComponent = actor.get_node("Statuses") as GameplayStatusComponent
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	var attribute: GameplayAttribute = GameplayAttribute.new()
	attribute.attribute_id = &"max_health"
	var values: GameplayAttributeSet = GameplayAttributeSet.new()
	values.attributes[attribute] = 100.0
	component.initialize([values], [HealthVital.new()])
	actor.add_child(component)
	var health: HealthVital = component.get_vital(&"health") as HealthVital
	statuses.apply_status(_status(&"issue_45.damage_exit", &"damage_received", FreeTargetEffect.new()), actor)
	var info: GameplayDamageInfo = GameplayDamageInfo.new()
	info.final_damage = 10.0
	var applied: float = health.apply_damage(info, actor)
	expect(applied == 0.0 and health.current_value == 100.0 and not is_instance_valid(actor), "Target removal in damage-received handling must cancel pending damage without routing to a freed node")
