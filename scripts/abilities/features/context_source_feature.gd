extends GameplayAbilityFeature
class_name ContextSourceFeature

## 上下文源特性
## 负责从不同来源（如黑板、属性、全局变量等）获取数据，并注入到技能上下文（Context）中
## 使得后续的技能逻辑（如 DamageEffect, ProjectileSpawn）能够使用这些动态数据

## 注入到 Context 的 Key
@export var context_key: String = "": 
	set(value):
		context_key = value
		_update_feature_name()
## 获取值的策略
@export var value_strategy: BTValueStrategy 
@export_group("Value Settings")
## 最小值限制（仅对数字有效）
@export var min_value: float = -INF 
## 最大值限制（仅对数字有效）
@export var max_value: float = INF 
## 如果 Context 中已存在该 Key，是否覆盖
@export var overwrite_existing: bool = true 
## 是否允许注入 null 值（若为 false，当值为 null 时视为失败）
@export var allow_null_value: bool = false 

func _init() -> void:
	super("ContextSourceFeature")

func _update_feature_name() -> void:
	if not context_key.is_empty():
		feature_name = "ContextSourceFeature_" + context_key
	else:
		feature_name = "ContextSourceFeature"

func can_activate(ability: GameplayAbilityInstance, context: Dictionary) -> bool:
	# 1. 如果 Key 为空，无法注入，视为配置错误
	if context_key.is_empty():
		push_warning("ContextSourceFeature: context_key is empty! Ability: %s" % ability)
		return false

	# 2. 如果 Context 中已经存在该 Key，且不允许覆盖，则保留上游值，视为成功
	if context.has(context_key) and not overwrite_existing:
		return true

	# 3. 获取值（如果没有策略，视为配置错误）
	if not is_instance_valid(value_strategy):
		push_warning("ContextSourceFeature: value_strategy is missing! Ability: %s" % ability)
		return false
		
	var val = value_strategy.get_value(context, ability.get_blackboard())
	
	# 4. 如果获取到的值为 null
	if val == null and not allow_null_value:
		return allow_null_value
	elif val is float or val is int:
			val = clamp(val, min_value, max_value)

	# 6. 注入到 Context
	context[context_key] = val
	return true
