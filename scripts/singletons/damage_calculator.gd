extends Node

## 伤害计算中心（单例）
## 使用策略模式，支持自定义伤害公式

var _strategy: DamageLogicStrategy = SimpleDamageLogic.new()

## 设置伤害计算策略
## [param] strategy: DamageLogicStrategy 自定义策略
func set_strategy(strategy: DamageLogicStrategy) -> void:
	_strategy = strategy

## 计算最终伤害
## [param] damage_info: GameplayDamageInfo 伤害信息
## [param] target_comp: GameplayAttributeComponent 目标的属性组件
## [return] float 最终伤害值
func calculate_final_damage(target: Node, instigator: Node, context: Dictionary, strategy: DamageLogicStrategy = null) -> float:
	var strategy_to_use = strategy if is_instance_valid(strategy) else _strategy
	if not is_instance_valid(strategy_to_use):
		return 0.0
	
	# 只计算，不应用
	return max(0.0, strategy_to_use.calculate(target, instigator, context))
