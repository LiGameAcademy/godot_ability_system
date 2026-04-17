extends GameplayEffect
class_name GE_ModifyIncomingDamage

## 修改即将到来的伤害（在 HealthVital.apply_damage 中触发之前）
## 典型用法：
## - 减伤护盾：将伤害乘以 0.5
## - 易伤：将伤害乘以 1.5
## 要求：
## - 该 Effect 应该挂在监听 damage_received 事件的状态上

@export_range(0.0, 10.0, 0.01) var damage_multiplier: float = 0.5

func _apply(target: Node, _instigator: Node, context: Dictionary) -> void:
	var damage_info: GameplayDamageInfo = context.get("damage_info")
	if not is_instance_valid(damage_info):
		return

	# 【关键】读取层数并调整伤害倍率
	var stacks = context.get("stacks", 1)
	var final_multiplier = damage_multiplier
	if stacks > 1:
		# 指数放大：每层减少更多伤害
		# 例如：1 层 0.5，2 层 0.25，3 层 0.125
		final_multiplier = pow(damage_multiplier, stacks)
		# 或使用线性公式：final_multiplier = damage_multiplier * (1.0 - 0.1 * (stacks - 1))
	
	# GameplayDamageInfo 是引用类型，直接修改其 final_damage 即可影响后续计算
	damage_info.final_damage *= final_multiplier

func _get_description() -> String:
	return "Modify incoming damage by multiplier %.2f\n" % damage_multiplier
