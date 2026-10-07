extends RegressionCase

class ReentrantSet extends GameplayAttributeSet:
	var resolutions: int = 0
	func resolve_dependencies(component: GameplayAttributeComponent) -> void:
		resolutions += 1
		if resolutions == 1:
			component.initialize()

func run() -> void:
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	var initial: ReentrantSet = ReentrantSet.new()
	var maximum: GameplayAttribute = GameplayAttribute.new()
	maximum.attribute_id = &"max_mana"
	initial.attributes[maximum] = 100.0
	component._active_sets = [initial]
	component._vitals = [ManaVital.new()]
	component.initialize()
	var attribute: GameplayAttributeInstance = component.get_attribute(&"max_mana")
	var vital: GameplayVital = component.get_vital(&"mana")
	var modifier: GameplayAttributeModifier = GameplayAttributeModifier.new()
	modifier.attribute_id = &"max_mana"
	modifier.value = 20.0
	component.add_modifier(modifier)
	component.modify_vital(&"mana", -30.0)
	var paid_balance: float = component.get_vital_value(&"mana")
	var changed: GameplayAttributeSet = GameplayAttributeSet.new()
	changed.attributes[maximum] = 500.0
	component.initialize([changed], [ManaVital.new()])
	component.initialize()
	expect(initial.resolutions == 1, "Dependency resolution must run once, including reentrant initialize")
	expect(component._active_sets[0] == initial, "Repeated initialize must not replace active configuration")
	expect(component.get_attribute(&"max_mana") == attribute, "Attribute identity must remain stable")
	expect(component.get_value(&"max_mana") == 120.0, "Existing modifiers must remain effective")
	expect(component.get_vital(&"mana") == vital, "Repeated initialization must not recreate Vitals")
	expect(component.get_vital_value(&"mana") == paid_balance, "Repeated initialization must not refill mana")
	component.auto_initialize = true
	(Engine.get_main_loop() as SceneTree).root.add_child(component)
	expect(component.get_vital(&"mana") == vital, "Ready auto-initialize must preserve manually initialized Vitals")
	component.set_base_value(&"max_mana", 10.0)
	expect(vital.get_max_value() == component.get_value(&"max_mana"), "Original Vital must still observe attribute changes")
	expect(vital.current_value <= vital.get_max_value(), "Maximum reduction must still clamp current Vital")
	component.free()
