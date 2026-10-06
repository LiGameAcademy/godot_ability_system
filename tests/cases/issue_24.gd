extends RegressionCase

func run() -> void:
	var missing: Node = Node.new()
	var wrong_component: Node = Node.new()
	var unrelated: Node = Node.new()
	unrelated.name = "GameplayVitalAttributeComponent"
	wrong_component.add_child(unrelated)
	var empty: Node = Node.new()
	var vitals: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	vitals.name = "GameplayVitalAttributeComponent"
	empty.add_child(vitals)
	var wrong_vital: GameplayVital = GameplayVital.new()
	wrong_vital.vital_id = &"health"
	wrong_vital.current_value = 50.0
	vitals._active_vitals[&"health"] = wrong_vital
	var effect: GE_ApplyDamage = GE_ApplyDamage.new()
	for actor: Node in [missing, wrong_component, empty]:
		var context: Dictionary = {}
		effect.apply(actor, actor, context)
		expect(not context.has("final_damage"), "Invalid dependency must not report applied damage")
	expect(wrong_vital.current_value == 50.0, "A non-HealthVital must not be modified")
	vitals._active_vitals.clear()
	effect.apply(empty, empty, {})
	missing.free()
	wrong_component.free()
	empty.free()
