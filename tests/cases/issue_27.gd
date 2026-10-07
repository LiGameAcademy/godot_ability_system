extends RegressionCase

func run() -> void:
	var actor: Node = Node.new()
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	actor.add_child(component)
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.ability_id = &"test"
	definition.execution_tree = RegressionBTProbe.new()
	component.learn_ability(definition)
	var ability: GameplayAbilityInstance = component.get_ability_instance(&"test")
	var other: GameplayAbilityInstance = definition.create_instance(actor)
	component.disable_ability(&"test")
	expect(ability.disabled and not other.disabled and not definition.disabled, "Disable must be per instance")
	expect(not ability.can_activate() and not ability.try_activate(), "Direct activation APIs must honor disabled")
	expect(not component.can_activate_ability(&"test") and not component.try_activate_ability(&"test"), "Component activation APIs must honor disabled")
	component.enable_ability(&"test")
	expect(ability.can_activate(), "Enable must restore eligibility")
	definition.disabled = true
	var initially_disabled: GameplayAbilityInstance = definition.create_instance(actor)
	expect(initially_disabled.disabled and not initially_disabled.try_activate(), "Definition flag must initialize runtime state")
	ability.get_blackboard().clear()
	other.get_blackboard().clear()
	initially_disabled.get_blackboard().clear()
	actor.free()
