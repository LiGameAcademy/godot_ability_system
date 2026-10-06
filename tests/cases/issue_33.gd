extends RegressionCase

class CountEffect extends GameplayEffect:
	@export var counter_key: StringName = &"apply_count"
	func _apply(target: Node, _instigator: Node, _context: Dictionary) -> void:
		target.set_meta(counter_key, int(target.get_meta(counter_key, 0)) + 1)

func run() -> void:
	var actor: Node = Node.new()
	var attributes: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	attributes.name = "GameplayVitalAttributeComponent"
	actor.add_child(attributes)
	var attribute: GameplayAttribute = GameplayAttribute.new()
	attribute.attribute_id = &"power"
	var attribute_set: GameplayAttributeSet = GameplayAttributeSet.new()
	attribute_set.attributes[attribute] = 10.0
	attributes.initialize([attribute_set])
	var statuses: GameplayStatusComponent = GameplayStatusComponent.new()
	actor.add_child(statuses)
	var initial_effect: CountEffect = CountEffect.new()
	var removal_effect: CountEffect = CountEffect.new()
	removal_effect.counter_key = &"remove_count"
	var modifier_effect: GE_AttributeModifier = _modifier(2.0)
	var second_modifier: GE_AttributeModifier = _modifier(3.0)
	var data: GameplayStatusData = GameplayStatusData.new()
	data.max_stacks = 3
	data.duration = 10.0
	initial_effect.sub_effects = [second_modifier]
	data.apply_effects = [initial_effect, modifier_effect]
	data.remove_effects = [removal_effect]
	var instance: GameplayStatusInstance = GameplayStatusInstance.new(data, statuses, actor, 1)
	instance.apply()
	expect(attributes.get_value(&"power") == 15.0, "Initial modifiers must both apply")
	instance.add_stack()
	expect(int(actor.get_meta(&"apply_count", 0)) == 1 and int(actor.get_meta(&"remove_count", 0)) == 0, "Stack must not replay initial or removal side effects")
	expect(attributes.get_value(&"power") == 20.0, "Both persistent modifiers must scale to two stacks")
	var unrelated: GameplayAttributeModifier = GameplayAttributeModifier.new()
	unrelated.attribute_id = &"power"
	unrelated.value = 7.0
	unrelated.source_id = &"other_status"
	attributes.add_modifier(unrelated)
	instance.update(2.0)
	instance.add_stack(9, false)
	expect(instance.remaining_duration == 8.0, "No-refresh stack change must preserve remaining duration")
	instance.add_stack()
	expect(instance.remaining_duration == 10.0, "Full-stack reapplication must still refresh duration")
	expect(instance.stacks == 3 and attributes.get_value(&"power") == 32.0, "Max-stack refresh must not duplicate modifiers")
	instance.remove()
	expect(attributes.get_value(&"power") == 17.0, "Removal must preserve unrelated sources")
	expect(int(actor.get_meta(&"remove_count", 0)) == 1, "Real removal must fire once")
	actor.free()

func _modifier(value: float) -> GE_AttributeModifier:
	var modifier: GameplayAttributeModifier = GameplayAttributeModifier.new()
	modifier.attribute_id = &"power"
	modifier.value = value
	var effect: GE_AttributeModifier = GE_AttributeModifier.new()
	effect.modifiers = [modifier]
	return effect
