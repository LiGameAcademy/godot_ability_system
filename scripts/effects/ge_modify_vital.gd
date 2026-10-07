extends GameplayEffect
class_name GE_ModifyVital

@export var vital_id: StringName = &""
@export var amount: float = 0.0
@export var vital_comp_name: StringName = &"GameplayVitalAttributeComponent"

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	_apply_result(target, instigator, context)

func _apply_result(target: Node, _instigator: Node, context: Dictionary) -> GameplayEffectResult:
	var stacks: Variant = context.get("stacks", 1)
	if not stacks is int or stacks < 1 or not is_finite(amount) or not is_finite(amount * int(stacks)):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	var component: GameplayVitalAttributeComponent = GameplayAbilitySystem.get_component_by_interface(target, vital_comp_name) as GameplayVitalAttributeComponent
	if not is_instance_valid(component) or not component.has_vital(vital_id):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.MISSING_DEPENDENCY)
	var vital: GameplayVital = component.get_vital(vital_id)
	var before: float = vital.current_value
	var paid: bool = component.modify_vital(vital_id, amount * int(stacks))
	var delta: float = vital.current_value - before
	var changed: bool = paid and delta != 0.0
	var result: GameplayEffectResult = GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED if changed else GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.NONE if changed else GameplayEffectResult.Reason.NO_CHANGE)
	result.outputs = {"vital_id": vital_id, "delta": delta, "remaining": vital.current_value}
	return result
