extends GameplayEffect
class_name GE_DispelStatus

@export var tags_to_remove: Array[StringName] = [&"magic", &"debuff"]

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	_apply_result(target, instigator, context)

func _apply_result(target: Node, _instigator: Node, _context: Dictionary) -> GameplayEffectResult:
	var component: GameplayStatusComponent = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent") as GameplayStatusComponent
	if not is_instance_valid(component):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.MISSING_DEPENDENCY)
	var count: int = 0
	for instance: GameplayStatusInstance in component.get_active_statuses():
		if not is_instance_valid(component):
			var interrupted: GameplayEffectResult = GameplayEffectResult.new(GameplayEffectResult.Status.PARTIAL if count > 0 else GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_TARGET)
			interrupted.outputs = {"removed_count": count}
			return interrupted
		if not is_instance_valid(instance) or not is_instance_valid(instance.status_data):
			continue
		for tag: StringName in tags_to_remove:
			if instance.status_data.tags.has(tag):
				if component.remove_status(instance.status_data.status_id):
					count += 1
				break
	var result: GameplayEffectResult = GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED if count > 0 else GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.NONE if count > 0 else GameplayEffectResult.Reason.NO_CHANGE)
	result.outputs = {"removed_count": count}
	return result
