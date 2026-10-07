extends RegressionCase

class LegacyCost extends AbilityCostBase:
	var payments: int = 0
	func _can_pay(_component: Node, _instigator: Node) -> bool:
		return true
	func _try_pay(_component: Node, _instigator: Node) -> bool:
		payments += 1
		return true

class CustomVitalCost extends VitalCost:
	var payments: int = 0
	func _try_pay(_component: Node, _instigator: Node) -> bool:
		payments += 1
		return false

func run() -> void:
	var actor: Node = Node.new()
	var component: GameplayVitalAttributeComponent = _attach_vitals(actor)
	component.modify_vital(&"mana", -85.0)
	var feature: CostFeature = CostFeature.new()
	var mana_cost: VitalCost = _cost(&"mana", 10.0)
	feature.costs = [mana_cost, mana_cost]
	var context: Dictionary = {"ability_component": actor, "instigator": actor}
	var balance: float = component.get_vital_value(&"mana")
	expect(not feature.can_activate(null, context), "Two 10 mana costs require 20 mana, not 10")
	expect(not feature.try_pay(null, context), "An unaffordable aggregate must fail")
	expect(component.get_vital_value(&"mana") == balance, "Failed aggregate must not debit the first payment")
	component.get_vital(&"mana").current_value = 30.0
	expect(feature.can_activate(null, context), "Sufficient aggregate must qualify")
	expect(component.get_vital_value(&"mana") == 30.0, "Qualification must remain read-only")
	expect(feature.try_pay(null, context), "An affordable aggregate must succeed")
	expect(component.get_vital_value(&"mana") == 10.0, "Repeated references must charge their full configured total")
	expect(mana_cost.amount == 10.0, "Shared cost configuration must remain unchanged")

	var health_cost: VitalCost = _cost(&"health", 6.0)
	feature.costs = [mana_cost, health_cost]
	expect(not feature.try_pay(null, context), "Insufficient second Vital must reject the whole batch")
	expect(component.get_vital_value(&"mana") == 10.0, "A failed health payment must leave mana unchanged")
	component.get_vital(&"mana").current_value = 10.0
	health_cost.amount = 2.0
	var observations: Array[Vector2] = []
	component.vital_value_changed.connect(func(_id: StringName, _current: float, _maximum: float, _percent: float, _regen: bool) -> void:
		observations.append(Vector2(component.get_vital_value(&"mana"), component.get_vital_value(&"health")))
	)
	expect(feature.try_pay(null, context), "Different Vitals must commit together")
	expect(observations.size() == 2, "Each changed Vital must notify once per batch")
	for observed: Vector2 in observations:
		expect(observed == Vector2(0.0, 3.0), "Observers must see all balances applied, never half a batch")
	actor.free()
	_test_late_check_and_isolation()
	_test_overdraft_and_invalid_costs()
	_test_custom_cost_boundary()

func _test_late_check_and_isolation() -> void:
	var actor_a: Node = Node.new()
	var actor_b: Node = Node.new()
	var component_a: GameplayVitalAttributeComponent = _attach_vitals(actor_a)
	var component_b: GameplayVitalAttributeComponent = _attach_vitals(actor_b)
	var feature: CostFeature = CostFeature.new()
	feature.costs = [_cost(&"mana", 10.0), _cost(&"health", 4.0)]
	var context_a: Dictionary = {"ability_component": actor_a, "instigator": actor_a}
	var context_b: Dictionary = {"ability_component": actor_b, "instigator": actor_b}
	expect(feature.can_activate(null, context_a), "Initial qualification must pass")
	component_a.modify_vital(&"health", -2.0)
	expect(not feature.try_pay(null, context_a), "Payment must recheck a balance changed after qualification")
	expect(component_a.get_vital_value(&"mana") == 100.0, "Late failure must leave another Vital untouched")
	expect(feature.try_pay(null, context_b), "Shared configuration must resolve B's current Vitals")
	expect(component_b.get_vital_value(&"mana") == 90.0 and component_b.get_vital_value(&"health") == 1.0, "Only B must pay")
	expect(component_a.get_vital_value(&"health") == 3.0, "B payment must leave A untouched")
	expect(not context_a.has("payment") and feature.costs[0].amount == 10.0, "Payment must not write caller context or configuration")
	actor_a.free()
	actor_b.free()

func _test_overdraft_and_invalid_costs() -> void:
	var actor: Node = Node.new()
	var component: GameplayVitalAttributeComponent = _attach_vitals(actor)
	var feature: CostFeature = CostFeature.new()
	var context: Dictionary = {"ability_component": actor, "instigator": actor}
	var strict_cost: VitalCost = _cost(&"mana", 4.0)
	var overdraft: VitalCost = _cost(&"mana", 20.0)
	overdraft.allow_overdraft = true
	feature.costs = [overdraft, strict_cost]
	component.get_vital(&"mana").current_value = 15.0
	expect(feature.try_pay(null, context), "Overdraft must clamp to zero after reserving strict costs, independent of array order")
	expect(component.get_vital_value(&"mana") == 0.0, "Overdraft must never make the balance negative")
	component.get_vital(&"mana").current_value = 4.0
	expect(not feature.try_pay(null, context), "Overdraft requires positive balance after strict costs are reserved")
	expect(component.get_vital_value(&"mana") == 4.0, "Rejected overdraft must not charge the strict cost")
	feature.costs = [_cost(&"mana", 0.0)]
	component.get_vital(&"mana").current_value = 0.0
	expect(feature.try_pay(null, context), "Zero cost may succeed with zero balance")
	component.get_vital(&"mana").current_value = 50.0
	for invalid: float in [-1.0, NAN, INF]:
		feature.costs = [_cost(&"mana", 10.0), _cost(&"health", invalid)]
		expect(not feature.can_activate(null, context) and not feature.try_pay(null, context), "Invalid amount must reject the whole batch")
		expect(component.get_vital_value(&"mana") == 50.0, "Invalid later cost must not debit earlier costs")
	feature.costs = [_cost(&"mana", 10.0), null]
	expect(not feature.try_pay(null, context), "Empty cost resource must fail instead of being skipped")
	feature.costs = [_cost(&"mana", 10.0), _cost(&"missing", 1.0)]
	expect(not feature.try_pay(null, context), "Missing Vital must reject the whole batch")
	expect(component.get_vital_value(&"mana") == 50.0, "Missing Vital must not leave a partial debit")
	feature.costs = [_cost(&"mana", 0.1), _cost(&"mana", 0.2)]
	expect(feature.try_pay(null, context), "Fractional costs must remain supported")
	expect(component.get_vital_value(&"mana") == 50.0 - (0.1 + 0.2), "Cost aggregation must retain float precision")
	expect(not feature.try_pay(null, {"ability_component": "wrong", "instigator": actor}), "Invalid context must fail cleanly")
	expect(feature.try_pay(null, {"skip_cost": true}), "Explicit skip_cost must preserve its old behavior")
	actor.free()

func _test_custom_cost_boundary() -> void:
	var actor: Node = Node.new()
	var component: GameplayVitalAttributeComponent = _attach_vitals(actor)
	var feature: CostFeature = CostFeature.new()
	var context: Dictionary = {"ability_component": actor, "instigator": actor}
	var legacy: LegacyCost = LegacyCost.new()
	feature.costs = [legacy]
	expect(feature.can_activate(null, context) and legacy.payments == 0, "Single legacy check must remain read-only")
	expect(feature.try_pay(null, context) and legacy.payments == 1, "Single legacy payment must keep its hook")
	for mixed: Array in [[_cost(&"mana", 10.0), legacy], [legacy, _cost(&"mana", 10.0)], [legacy, legacy]]:
		feature.costs.assign(mixed)
		expect(not feature.can_activate(null, context) and not feature.try_pay(null, context), "Unsupported custom batch must fail before any payment")
		expect(component.get_vital_value(&"mana") == 100.0 and legacy.payments == 1, "Rejected mixed batch must call no payment hooks")
	var custom: CustomVitalCost = CustomVitalCost.new()
	feature.costs = [custom]
	expect(not feature.try_pay(null, context) and custom.payments == 1, "VitalCost subclass must keep its overridden hook")
	expect(component.get_vital_value(&"mana") == 100.0, "Subclass must not be silently charged as a built-in cost")
	actor.free()

func _cost(id: StringName, amount: float) -> VitalCost:
	var cost: VitalCost = VitalCost.new()
	cost.vital_id = id
	cost.amount = amount
	return cost

func _attach_vitals(actor: Node) -> GameplayVitalAttributeComponent:
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	component.name = "GameplayVitalAttributeComponent"
	actor.add_child(component)
	var mana: GameplayAttribute = GameplayAttribute.new()
	mana.attribute_id = &"max_mana"
	var health: GameplayAttribute = GameplayAttribute.new()
	health.attribute_id = &"max_health"
	var attributes: GameplayAttributeSet = GameplayAttributeSet.new()
	attributes.attributes[mana] = 100.0
	attributes.attributes[health] = 5.0
	component.initialize([attributes], [ManaVital.new(), HealthVital.new()])
	return component
