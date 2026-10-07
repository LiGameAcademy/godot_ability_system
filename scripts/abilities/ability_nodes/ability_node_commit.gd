extends AbilityNodeBase
class_name AbilityNodeCommit

## 一次提交费用与冷却；可关闭一项，以保留分阶段提交的技能流程。
@export var pay_cost: bool = true
@export var start_cooldown: bool = true
@export var cost_feature_name: String = "CostFeature"
@export var cooldown_feature_name: String = "CooldownFeature"

func _tick(instance: GAS_BTInstance, _delta: float) -> int:
	var ability: GameplayAbilityInstance = _get_var(instance, "ability_instance") as GameplayAbilityInstance
	if not is_instance_valid(ability):
		return Status.FAILURE
	var success: bool = ability.try_commit(_get_context(instance), pay_cost, start_cooldown, cost_feature_name, cooldown_feature_name)
	return Status.SUCCESS if success and ability.is_active else Status.FAILURE
