extends RegressionCase

class CountEffect extends GameplayEffect:
	func _apply_result(target: Node, _instigator: Node, _context: Dictionary) -> GameplayEffectResult:
		target.set_meta("initial_calls", int(target.get_meta("initial_calls", 0)) + 1)
		return GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED)

class RemoveStatusEffect extends GameplayEffect:
	func _apply_result(target: Node, _instigator: Node, _context: Dictionary) -> GameplayEffectResult:
		var instance: GameplayStatusInstance = target.get_meta("remove_during_apply") as GameplayStatusInstance
		instance.remove()
		return GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED)

func run() -> void:
	var actor: Node = Node.new()
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	component.name = "GameplayVitalAttributeComponent"
	actor.add_child(component)
	var definition: GameplayAttribute = GameplayAttribute.new()
	definition.attribute_id = &"power"
	var values: GameplayAttributeSet = GameplayAttributeSet.new()
	values.attributes[definition] = 10.0
	component.initialize([values])
	var first: GE_AttributeModifier = _effect(2.0)
	var second: GE_AttributeModifier = _effect(3.0)
	var a: GameplayEffectResult = first.apply(actor, actor)
	var b: GameplayEffectResult = second.apply(actor, actor)
	expect(component.get_value(&"power") == 15.0, "Two independent effects must both apply")
	expect(a.application.application_id != b.application.application_id and not a.application.application_id.is_empty(), "Ownership must be unique even when configuration ID is empty")
	first.remove(actor, actor)
	expect(component.get_value(&"power") == 15.0, "Template remove without an application must refuse ambiguous group deletion")
	a.application.revoke()
	expect(component.get_value(&"power") == 13.0, "Revoking A must preserve independent B even with default configuration IDs")
	a.copy().application.revoke()
	expect(component.get_value(&"power") == 13.0, "Revocation through copied results must be idempotent")
	b.application.revoke()
	first.source_id = &"shared.config"
	a = first.apply(actor, actor, {"source_id": &"same.group"})
	b = first.apply(actor, actor, {"source_id": &"same.group"})
	expect(a.application.application_id != b.application.application_id and a.application.config_id == first.source_id and a.application.source_group == &"same.group", "Repeated use of one configuration and source label must still create distinct applications")
	first.remove(actor, actor, {"application": a.application})
	expect(component.get_value(&"power") == 12.0, "Compatibility remove with an explicit handle must revoke exactly one application")
	b.application.revoke()
	expect(first.modifiers[0].source_id.is_empty() and first.modifiers[0].value == 2.0, "Applying and revoking must not mutate modifier configuration")
	_test_status_ownership(actor, component, first)
	_test_reentrant_revocation(actor, component, first)
	a = first.apply(actor, actor)
	actor.free()
	a.application.revoke()
	a.application.set_stacks(2)
	expect(a.application.is_revoked(), "Revocation after target destruction must safely complete")

func _test_status_ownership(actor: Node, component: GameplayVitalAttributeComponent, effect: GE_AttributeModifier) -> void:
	var statuses: GameplayStatusComponent = GameplayStatusComponent.new()
	actor.add_child(statuses)
	var initial: CountEffect = CountEffect.new()
	initial.sub_effects = [effect]
	var data: GameplayStatusData = GameplayStatusData.new()
	data.duration = 10.0
	data.max_stacks = 3
	data.apply_effects = [initial]
	var a: GameplayStatusInstance = GameplayStatusInstance.new(data, statuses, actor, 1)
	var b: GameplayStatusInstance = GameplayStatusInstance.new(data, statuses, actor, 1)
	a.apply()
	b.apply()
	a.apply()
	expect(component.get_value(&"power") == 14.0, "Independent status instances must each own their nested modifier application")
	a.add_stack()
	expect(component.get_value(&"power") == 16.0 and int(actor.get_meta("initial_calls", 0)) == 2, "Stack updates must adjust only A's persistent modifiers without replaying initial logic")
	a.remove()
	a.remove()
	expect(component.get_value(&"power") == 12.0, "Removing status A must preserve B and repeated removal must do nothing")
	b.apply_effects([effect])
	expect(component.get_value(&"power") == 14.0, "Event or periodic modifier application must be owned by its status")
	b.remove()
	expect(component.get_value(&"power") == 10.0, "Status end must revoke initial and later owned applications")
	expect(b.apply_effects([effect]).is_empty() and component.get_value(&"power") == 10.0, "Removed status must reject new applications")
	data.remove_effects = [_effect(5.0)]
	var c: GameplayStatusInstance = GameplayStatusInstance.new(data, statuses, actor, 1)
	c.apply()
	c.remove()
	expect(component.get_value(&"power") == 15.0, "Removal-time application must not be accidentally deleted with initial effects")
	c.get_last_effect_results()[0].application.revoke()
	expect(component.get_value(&"power") == 10.0, "Removal-time result must expose its separate application handle")
	data.remove_effects = []
	var removal: RemoveStatusEffect = RemoveStatusEffect.new()
	removal.sub_effects = [effect]
	data.apply_effects = [removal]
	var d: GameplayStatusInstance = GameplayStatusInstance.new(data, statuses, actor, 1)
	actor.set_meta("remove_during_apply", d)
	d.apply()
	expect(component.get_value(&"power") == 10.0, "Handle returned after reentrant status removal must be revoked immediately")
	actor.remove_meta("remove_during_apply")

func _test_reentrant_revocation(actor: Node, component: GameplayVitalAttributeComponent, effect: GE_AttributeModifier) -> void:
	var result: GameplayEffectResult = effect.apply(actor, actor)
	var application: GameplayEffectApplication = result.application
	var callback: Callable = func(id: StringName, value: float) -> void:
		if id == &"power" and value >= 14.0:
			application.revoke()
	component.attribute_value_changed.connect(callback)
	application.set_stacks(2)
	expect(application.is_revoked() and component.get_value(&"power") == 10.0, "Reentrant revocation during stack update must not leave a modifier installed")
	component.attribute_value_changed.disconnect(callback)

func _effect(amount: float) -> GE_AttributeModifier:
	var effect: GE_AttributeModifier = GE_AttributeModifier.new()
	effect.modifiers = [GameplayAttributeModifier.new(&"power", amount)]
	return effect
