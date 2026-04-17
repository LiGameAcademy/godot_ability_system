extends AbilityNodeBase
class_name AbilityNodeApplyCost

## 检查并应用消耗节点
## 直接检查并扣除目标的 Vital（不经过 CostFeature）
##
## 用途：
## - 周期性检查并消耗资源（如献祭技能每秒检查并消耗1点生命值）
## - 与 GAS_BTRepeatPeriodic 配合使用
##
## 注意：
## - 先检查是否可以支付消耗，如果可以则支付
## - 直接访问目标的 Vital 组件，不经过 CostFeature
## - 如果检查失败或支付失败，返回 FAILURE

@export_group("Cost Settings")
## 要消耗的 Vital ID（如 "health", "mana"）
@export var vital_id: StringName = &"health"
## 消耗数量
@export var cost_amount: float = 1.0
## 是否允许透支（如果为 false，当前值必须 >= cost_amount）
@export var allow_overdraft: bool = false
## 是否只检查不消耗（如果为 true，只检查不实际扣除）
@export var check_only: bool = false
## Vital 组件名称（用于查找组件）
@export var vital_comp_name: StringName = &"GameplayVitalAttributeComponent"

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	if not _validate_context(instance, "AbilityNodeApplyCost"):
		return Status.FAILURE

	# 获取目标列表（默认使用自身）
	var target_list = _get_target_list(instance, true)  # use_instigator_as_fallback = true
	if target_list.is_empty():
		push_warning("AbilityNodeApplyCost: 没有找到目标")
		return Status.FAILURE

	# 处理第一个目标的 Vital（通常只有一个目标）
	var target = target_list[0]
	if not is_instance_valid(target):
		return Status.FAILURE

	# 获取 Vital 组件
	var vital_comp = GameplayAbilitySystem.get_component_by_interface(target, vital_comp_name)
	if not is_instance_valid(vital_comp):
		push_warning("AbilityNodeApplyCost: 目标 %s 没有 %s 组件" % [target.name, vital_comp_name])
		return Status.FAILURE

	# 获取 Vital 实例
	var vital = vital_comp.get_vital(vital_id)
	if not is_instance_valid(vital):
		push_warning("AbilityNodeApplyCost: 目标 %s 没有 %s Vital" % [target.name, vital_id])
		return Status.FAILURE

	# 检查是否可以支付消耗
	if not allow_overdraft and vital.current_value < cost_amount:
		# 消耗不足，返回失败
		return Status.FAILURE

	# 如果只检查不消耗，直接返回成功
	if check_only:
		return Status.SUCCESS

	# 扣除 Vital（modify_value 会自动处理边界值）
	vital.modify_value(-cost_amount)

	return Status.SUCCESS
