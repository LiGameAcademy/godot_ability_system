extends AbilityNodeBase
class_name AbilityNodeCommitCooldown 

@export var cooldown_feature_name: String = "CooldownFeature"

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	var ability = _get_var(instance, "ability_instance")
	if not is_instance_valid(ability):
		push_error("AbilityNodeCommitCooldown: ability is not valid!")
		return Status.FAILURE
	var cooldown_feature : CooldownFeature = ability.get_feature(cooldown_feature_name)
	if not is_instance_valid(cooldown_feature):
		push_error("AbilityNodeCommitCooldown: cooldown_feature is not valid!")
		return Status.FAILURE
	# 进 CD 通常不会失败
	cooldown_feature.start_cooldown(ability)
	return Status.SUCCESS
