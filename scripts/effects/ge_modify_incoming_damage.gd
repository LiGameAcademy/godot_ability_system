extends GameplayEffect
class_name GE_ModifyIncomingDamage

@export_range(0.0, 10.0, 0.01) var damage_multiplier: float = 0.5

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	_apply_result(target, instigator, context)

func _apply_result(_target: Node, _instigator: Node, context: Dictionary) -> GameplayEffectResult:
	var payload: Variant = context.get("damage_info")
	var info: GameplayDamageInfo = payload as GameplayDamageInfo if payload is GameplayDamageInfo else null
	if not is_instance_valid(info):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.MISSING_DEPENDENCY)
	var stacks: Variant = context.get("stacks", 1)
	if not stacks is int or stacks < 1 or not is_finite(damage_multiplier) or damage_multiplier < 0.0:
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	var before: float = info.final_damage
	var after: float = before * pow(damage_multiplier, int(stacks))
	if not is_finite(after):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	info.final_damage = after
	var result: GameplayEffectResult = GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED if before != after else GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.NONE if before != after else GameplayEffectResult.Reason.NO_CHANGE)
	result.outputs = {"final_damage": after}
	return result

func _get_description() -> String:
	return "Modify incoming damage by multiplier %.2f" % damage_multiplier
