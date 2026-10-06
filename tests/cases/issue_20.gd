extends RegressionCase

func run() -> void:
	var actor_a: Node = Node.new()
	var actor_b: Node = Node.new()
	var component_a: GameplayVitalAttributeComponent = _attach_vital(actor_a, 50.0)
	var component_b: GameplayVitalAttributeComponent = _attach_vital(actor_b, 5.0)
	var cost: VitalCost = VitalCost.new()
	cost.amount = 10.0
	expect(cost.can_pay(component_a, actor_a), "Actor A can afford the cost")
	expect(not cost.can_pay(component_b, actor_b), "Actor B must not use A's balance")
	expect(not cost.try_pay(component_b, actor_b), "Actor B must not debit A")
	expect(component_a.get_vital_value(&"mana") == 50.0, "Failed B payment must leave A untouched")
	expect(cost.try_pay(component_a, actor_a), "Actor A payment must succeed")
	expect(component_a.get_vital_value(&"mana") == 40.0 and component_b.get_vital_value(&"mana") == 5.0, "Only the payer balance may change")
	actor_a.free()
	actor_b.free()

func _attach_vital(actor: Node, value: float) -> GameplayVitalAttributeComponent:
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	component.name = "GameplayVitalAttributeComponent"
	actor.add_child(component)
	var maximum: GameplayAttribute = GameplayAttribute.new()
	maximum.attribute_id = &"max_mana"
	var attributes: GameplayAttributeSet = GameplayAttributeSet.new()
	attributes.attributes[maximum] = value
	component.initialize([attributes], [ManaVital.new()])
	return component
