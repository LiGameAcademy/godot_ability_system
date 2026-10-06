extends RegressionCase

func run() -> void:
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	component.cancel_ability()
	component.cancel_ability()
	component.cancel_ability(&"unknown")
	expect(component.get_all_ability_instances().is_empty(), "Idle cancel must remain an empty safe no-op")
	component.free()
