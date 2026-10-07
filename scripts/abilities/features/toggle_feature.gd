extends GameplayAbilityFeature
class_name ToggleFeature

## 关闭意图在检查前解析，和 Feature 的添加顺序无关。
func get_activation_overrides(ability: GameplayAbilityInstance) -> Dictionary:
	if ability.is_active:
		return {"skip_cost": true, "skip_cooldown": true}
	return {}

## 在技能激活时处理切换逻辑
func on_activate(ability: GameplayAbilityInstance, context: Dictionary) -> void:
	var blackboard: GAS_BTBlackboard = ability.get_blackboard()
	if not is_instance_valid(blackboard):
		return
	# 检查是否是首次激活（开启操作）
	var is_first_activation: bool = blackboard.get_var("is_first_activation", false)
	if is_first_activation:
		# 首次激活（开启操作），设置"开启"标记
		blackboard.set_var("toggle_action", "turn_on")
		# 清除标志，避免影响后续判断
		blackboard.erase_var("is_first_activation")
	else:
		# 关闭操作（技能已激活时再次激活）
		blackboard.set_var("toggle_action", "turn_off")
		# 重置行为树，准备执行关闭逻辑
		var bt_instance: GAS_BTInstance = ability.get_bt_instance()
		if is_instance_valid(bt_instance):
			bt_instance.reset_tree()
