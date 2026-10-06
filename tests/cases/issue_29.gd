extends RegressionCase

class Gate extends GameplayAbilityFeature:
	var allowed: bool = true
	func can_activate(_ability: GameplayAbilityInstance, _context: Dictionary) -> bool:
		return allowed

class Preview extends AbilityPreviewStrategy:
	var active: bool = false
	func begin(_caster: Node, _ability: GameplayAbilityInstance, _extra: Dictionary = {}) -> void:
		active = true
	func is_targeting() -> bool:
		return active
	func cancel() -> void:
		active = false
	func get_result_context() -> Dictionary:
		return {"target_position": Vector3(3, 0, 4)}

func run() -> void:
	var actor: Node = Node.new()
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	actor.add_child(component)
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.ability_id = &"preview_test"
	definition.execution_tree = RegressionBTProbe.new()
	var gate: Gate = Gate.new()
	definition.features = [gate]
	definition.preview_strategy = Preview.new()
	component.learn_ability(definition)
	var ability: GameplayAbilityInstance = component.request_ability_preview(definition.ability_id)
	var activations: Array[Dictionary] = []
	component.ability_activated.connect(func(_ability: GameplayAbilityInstance, context: Dictionary) -> void:
		activations.append(context))
	gate.allowed = false
	expect(not component.try_activate_targeting_ability(), "Failed eligibility must be reported as false")
	expect(component.has_targeting_ability() and activations.is_empty(), "Failure must keep preview for retry without activation events")
	gate.allowed = true
	expect(component.try_activate_targeting_ability(), "Valid preview must activate via normal component API")
	expect(activations.size() == 1 and ability.is_active, "Successful preview must emit activation and run the ability")
	expect(ability.get_blackboard_var("context", {}).get("target_position") == Vector3(3, 0, 4), "Targeting context must reach execution")
	expect(not component.has_targeting_ability(), "Successful activation must release preview")
	ability.end_ability()
	ability.get_blackboard().clear()
	actor.free()
