extends RegressionCase

class CheckProbe extends GameplayAbilityFeature:
	var checks: int = 0
	var activations: int = 0
	var last_context: Dictionary = {}

	func can_activate(_ability: GameplayAbilityInstance, context: Dictionary) -> bool:
		checks += 1
		last_context = context.duplicate(true)
		return true

	func on_activate(_ability: GameplayAbilityInstance, context: Dictionary) -> void:
		activations += 1
		last_context = context.duplicate(true)

class LegacyWriter extends GameplayAbilityFeature:
	func can_activate(_ability: GameplayAbilityInstance, context: Dictionary) -> bool:
		context["skip_cost"] = true
		context["nested"]["value"].append(99)
		return true

func run() -> void:
	for toggle_first: bool in [true, false]:
		_check_toggle(toggle_first)
	_check_component_input()
	_check_legacy_writer()

func _check_legacy_writer() -> void:
	var actor: Node = Node.new()
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.execution_tree = RegressionBTProbe.new()
	var ability: GameplayAbilityInstance = definition.create_instance(actor)
	var probe: CheckProbe = CheckProbe.new()
	ability.add_feature("LegacyWriter", LegacyWriter.new())
	ability.add_feature("Probe", probe)
	var request: Dictionary = {"nested": {"value": [1]}}
	expect(ability.can_activate(request), "Legacy hook still returns its eligibility")
	expect(request == {"nested": {"value": [1]}}, "Legacy hook cannot mutate caller nested containers")
	expect(not probe.last_context.has("skip_cost"), "One checker cannot change another checker's input")
	expect(probe.last_context["nested"]["value"] == [1], "Nested input is isolated between checkers")
	ability.get_blackboard().clear()
	actor.free()

func _check_toggle(toggle_first: bool) -> void:
	var actor: Node = Node.new()
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.execution_tree = RegressionBTProbe.new()
	var ability: GameplayAbilityInstance = definition.create_instance(actor)
	var toggle: ToggleFeature = ToggleFeature.new()
	var cooldown: CooldownFeature = CooldownFeature.new()
	var cost: CostFeature = CostFeature.new()
	var probe: CheckProbe = CheckProbe.new()
	if toggle_first:
		ability.add_feature("ToggleFeature", toggle)
	ability.add_feature("CostFeature", cost)
	ability.add_feature("CooldownFeature", cooldown)
	ability.add_feature("Probe", probe)
	if not toggle_first:
		ability.add_feature("ToggleFeature", toggle)
	# An already-running toggle must be closable even with no payment context.
	ability.is_active = true
	cooldown.start_cooldown(ability, 5.0)
	var request: Dictionary = {"nested": {"value": [1, 2]}}
	var original: Dictionary = request.duplicate(true)
	var timer: float = cooldown.get_cooldown_remaining(ability)
	expect(ability.can_activate(request), "Active toggle can close regardless of feature order")
	expect(ability.can_activate(request), "Repeated query has the same answer")
	expect(request == original, "Query must not add skip flags to caller context")
	expect(probe.checks == 2, "Each feature is checked once per query")
	expect(probe.activations == 0 and ability.is_active, "Query does not execute feature hooks")
	expect(cooldown.get_cooldown_remaining(ability) == timer, "Query leaves cooldown untouched")
	expect(ability.try_activate(request), "Actual toggle close still works")
	expect(probe.checks == 3 and probe.activations == 1, "Execution validates once then activates once")
	expect(probe.last_context.get("skip_cost", false), "Execution receives normalized closing intent")
	expect(request == original, "Execution does not leak normalization into caller input")
	ability.is_active = false
	expect(not ability.can_activate(request), "Same request cannot bypass costs for a new opening")
	ability.get_blackboard().clear()
	actor.free()

func _check_component_input() -> void:
	var actor: Node = Node.new()
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	actor.add_child(component)
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.ability_id = &"query"
	definition.execution_tree = RegressionBTProbe.new()
	component.learn_ability(definition)
	var request: Dictionary = {"nested": {"value": [1]}}
	var original: Dictionary = request.duplicate(true)
	expect(component.can_activate_ability(&"query", request), "Component query still finds ability")
	expect(request == original, "Component query must not inject actor or ability into caller input")
	component.get_ability_instance(&"query").get_blackboard().clear()
	actor.free()
