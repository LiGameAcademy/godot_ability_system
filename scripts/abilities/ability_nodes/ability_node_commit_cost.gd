extends AbilityNodeBase
class_name AbilityNodeCommitCost

## 提交消耗节点
## 职责：检查并消耗技能所需的资源（如魔法值、体力等）
##
## 原理：
## 该节点从 AbilityInstance 中获取 CostFeature，并调用其 try_pay 方法。
## 如果消耗失败，节点返回 FAILURE，中断技能执行。

@export var cost_feature_name: String = "CostFeature"

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	var ability = _get_var(instance, "ability_instance")
	if not is_instance_valid(ability):
		push_error("AbilityNodeCommitCooldown: ability is not valid!")
		return Status.FAILURE
	var cost_feature : CostFeature = ability.get_feature(cost_feature_name)
	if not is_instance_valid(cost_feature):
		push_error("AbilityNodeCommitCooldown: cost_feature is not valid!")
		return Status.FAILURE
	var context : Dictionary = _get_var(instance, "context", {})
	if context.is_empty():
		push_warning("AbilityNodeCommitCost: context is empty!")

	# 进 CD 通常不会失败
	cost_feature.try_pay(ability, context)
	return Status.SUCCESS
