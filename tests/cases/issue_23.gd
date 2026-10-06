extends RegressionCase

class ContextDamage extends DamageLogicStrategy:
	func calculate(_target: Node, _instigator: Node, context: Dictionary) -> float:
		return 10.0 * float(context.get("damage_multiplier", 1.0))

func run() -> void:
	var actor_a: Node = _target()
	var actor_b: Node = _target()
	var effect: GE_ApplyDamage = GE_ApplyDamage.new()
	effect.damage_multiplier = 2.0
	var default_strategy: ContextDamage = ContextDamage.new()
	var override_strategy: ContextDamage = ContextDamage.new()
	effect.damage_strategy = default_strategy
	var context: Dictionary = {"damage_multiplier": 3.0, "damage_strategy": override_strategy}
	effect.apply(actor_a, actor_a, context)
	effect.apply(actor_b, actor_a, context)
	var vital_a: GameplayVitalAttributeComponent = actor_a.get_node("GameplayVitalAttributeComponent")
	var vital_b: GameplayVitalAttributeComponent = actor_b.get_node("GameplayVitalAttributeComponent")
	expect(vital_a.get_vital_value(&"health") == 940.0 and vital_b.get_vital_value(&"health") == 940.0, "Each target must receive the same 10*2*3 damage")
	expect(effect.damage_multiplier == 2.0 and effect.damage_strategy == default_strategy, "Shared effect configuration must stay unchanged")
	expect(context["damage_multiplier"] == 3.0, "Input context multiplier must stay unchanged")
	expect(context.get("final_damage") == 60.0, "Existing final_damage output must remain available")
	actor_a.free()
	actor_b.free()

func _target() -> Node:
	var actor: Node = Node.new()
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	component.name = "GameplayVitalAttributeComponent"
	actor.add_child(component)
	var maximum: GameplayAttribute = GameplayAttribute.new()
	maximum.attribute_id = &"max_health"
	var attributes: GameplayAttributeSet = GameplayAttributeSet.new()
	attributes.attributes[maximum] = 1000.0
	component.initialize([attributes], [HealthVital.new()])
	return actor
