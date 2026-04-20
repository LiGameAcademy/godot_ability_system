extends GameplayAbilityFeature
class_name TargetFeature

## 必须存在目标才能激活能力的特性
## 职责：在 can_activate 阶段进行索敌，并将结果存入 context

@export_group("Targeting Settings")
## 索敌策略
@export var strategy: TargetingStrategy
## 存入 context 的 Key
@export var context_key: String = "targets"
## 如果没有目标，是否允许激活？
@export var allow_empty: bool = false

func _init() -> void:
	super("TargetFeature")

func can_activate(ability: GameplayAbilityInstance, context: Dictionary) -> bool:
	if not is_instance_valid(strategy):
		push_warning("TargetFeature: Strategy is not valid.")
		return true # 如果没配策略，默认不拦截
	
	# 1. 获取基础信息
	var instigator = context.get("instigator")
	var input_target = context.get("input_target")
	
	# 2. 执行索敌
	var found_targets = strategy.resolve_targets(instigator, input_target, context)
	
	# 3. 写入 context (供后续 Feature 或行为树复用)
	context[context_key] = found_targets
	
	# 4. 判断是否拦截
	if not allow_empty and found_targets.is_empty():
		return false
		
	return true
