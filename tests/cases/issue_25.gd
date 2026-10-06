extends RegressionCase

class TrackingPreview extends AbilityPreviewStrategy:
	var owner: Node
	var active: bool = false
	func begin(caster: Node, _ability: GameplayAbilityInstance, _extra: Dictionary = {}) -> void:
		owner = caster
		active = true
	func is_targeting() -> bool:
		return active
	func get_result_context() -> Dictionary:
		return {"caster": owner}
	func cancel() -> void:
		active = false

func run() -> void:
	var actor_a: Node = Node.new()
	var actor_b: Node = Node.new()
	var template: TrackingPreview = TrackingPreview.new()
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.preview_strategy = template
	var ability_a: GameplayAbilityInstance = definition.create_instance(actor_a)
	var ability_b: GameplayAbilityInstance = definition.create_instance(actor_b)
	ability_a.start_targeting()
	ability_b.start_targeting()
	expect(ability_a.confirm_targeting().get("caster") == actor_a, "A preview must retain A owner")
	expect(ability_b.confirm_targeting().get("caster") == actor_b, "B preview must retain B owner")
	ability_a.cancel_targeting()
	expect(ability_b.is_targeting(), "Cancelling A must not cancel B")
	expect(not template.active and template.owner == null, "Preview template must stay unchanged")
	ability_b.cancel_targeting()
	ability_a.get_blackboard().clear()
	ability_b.get_blackboard().clear()
	actor_a.free()
	actor_b.free()
