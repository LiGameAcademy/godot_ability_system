extends GameplayEffect
class_name GE_ApplyStatus

@export var status_data: GameplayStatusData = null
@export var stacks: int = 1

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	_apply_result(target, instigator, context)

func _apply_result(target: Node, instigator: Node, context: Dictionary) -> GameplayEffectResult:
	var configured: Variant = context.get("status_data", status_data)
	var data: GameplayStatusData = configured as GameplayStatusData if configured is GameplayStatusData else null
	var amount: Variant = context.get("status_stacks", stacks)
	if not is_instance_valid(data) or not amount is int or amount < 1 or data.max_stacks < 1 or not is_finite(data.duration):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	var component: GameplayStatusComponent = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent") as GameplayStatusComponent
	if not is_instance_valid(component):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.MISSING_DEPENDENCY)
	var previous: GameplayStatusInstance = component.get_status(data.status_id)
	if is_instance_valid(previous) and is_instance_valid(previous.status_data) and previous.status_data.priority > data.priority:
		return GameplayEffectResult.new(GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.FILTERED)
	var before_stacks: int = previous.stacks if is_instance_valid(previous) else 0
	var before_time: float = previous.remaining_duration if is_instance_valid(previous) else 0.0
	var instance: GameplayStatusInstance = component.apply_status(data, instigator, int(amount), context.duplicate(true))
	if not is_instance_valid(instance):
		if not is_instance_valid(component) or not is_instance_valid(previous):
			return GameplayEffectResult.new(GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.FILTERED)
		var changed: bool = previous.stacks != before_stacks or previous.remaining_duration != before_time
		var refresh: GameplayEffectResult = GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED if changed else GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.NONE if changed else GameplayEffectResult.Reason.NO_CHANGE)
		refresh.outputs = {"status_id": data.status_id, "stacks": previous.stacks}
		return refresh
	var applied: GameplayEffectResult = GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED)
	applied.outputs = {"status_id": data.status_id, "stacks": instance.stacks}
	var parts: Array[GameplayEffectResult] = [applied]
	parts.append_array(instance.get_last_effect_results())
	var result: GameplayEffectResult = GameplayEffectResult.aggregate(parts)
	result.outputs = applied.outputs.duplicate()
	return result

func _get_description() -> String:
	return "Apply status %s" % status_data.status_display_name if is_instance_valid(status_data) else "Apply status to target"
