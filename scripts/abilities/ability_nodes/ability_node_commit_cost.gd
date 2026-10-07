extends AbilityNodeBase
class_name AbilityNodeCommitCost

## 提交消耗节点
## 职责：检查并消耗技能所需的资源（如魔法值、体力等）
##
## 原理：
## 该节点适配技能实例的统一提交入口，仅请求费用阶段。
## 如果消耗失败，节点返回 FAILURE，中断技能执行。

@export var cost_feature_name: String = "CostFeature"

func _tick(instance: GAS_BTInstance, _delta: float) -> int:
	var ability: GameplayAbilityInstance = _get_var(instance, "ability_instance") as GameplayAbilityInstance
	if not is_instance_valid(ability):
		push_error("AbilityNodeCommitCost: ability is not valid!")
		return Status.FAILURE
	var success: bool = ability.try_commit(_get_context(instance), true, false, cost_feature_name)
	return Status.SUCCESS if success and ability.is_active else Status.FAILURE
