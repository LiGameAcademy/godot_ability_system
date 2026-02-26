extends GameplayAbilityFeature
class_name ContextSourceFeature

## 上下文源特性
## 负责从不同来源（如黑板、属性、全局变量等）获取数据，并注入到技能上下文（Context）中
## 使得后续的技能逻辑（如 DamageEffect, ProjectileSpawn）能够使用这些动态数据

@export var context_key: String = "": ## 注入到 Context 的 Key
	set(value):
		context_key = value
		_update_feature_name()

@export var value_strategy: BTValueStrategy ## 获取值的策略

@export var min_value: float = -INF ## 最小值限制（仅对数字有效）
@export var max_value: float = INF ## 最大值限制（仅对数字有效）

func _init() -> void:
	super("ContextSourceFeature")

func _update_feature_name() -> void:
	if not context_key.is_empty():
		feature_name = "ContextSourceFeature_" + context_key
	else:
		feature_name = "ContextSourceFeature"

func on_activate(ability: GameplayAbilityInstance, context: Dictionary) -> void:
	# 1. 如果 Key 为空，无法注入
	if context_key.is_empty():
		return

	# 2. 如果 Context 中已经存在该 Key，则不覆盖（保留上游传递的值）
	if context.has(context_key):
		return

	# 3. 获取值（如果没有策略，则不执行任何操作）
	if not is_instance_valid(value_strategy):
		return
		
	var val = value_strategy.get_value(context, ability.get_blackboard())
	
	# 4. 如果获取到的值为 null，则不注入（假设策略负责处理默认值，若策略仍返回 null 表示确实无值）
	if val == null:
		return

	# 5. 如果是数字类型，进行钳制
	if val is float or val is int:
		val = clamp(val, min_value, max_value)

	# 6. 注入到 Context
	context[context_key] = val
