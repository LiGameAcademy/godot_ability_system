extends GameplayAbilityDefinition
class_name ActiveAbilityDefinition

## 简易主动技能模板
## 
## 用途：
## 快速创建标准的 "动画 -> 前摇 -> 冷却 -> 效果 -> 后摇" 流程的技能。
## 如果需要更复杂的逻辑，请直接使用基类 GameplayAbilityDefinition 并手动配置 Execution Tree。

@export_group("Quick Config")
@export var animation_name : StringName = &""
@export var animation_speed : float = 1.0
## 技能前摇时间 (伤害生效前的等待)
@export var pre_cast_delay : float = 0.0
## 技能后摇时间 (伤害生效后的僵直)
@export var post_cast_delay : float = 0.0
## 技能冷却时间
@export var cooldown_duration : float = 0.0
## 技能消耗
@export var costs : Array[AbilityCostBase] = []
## 技能效果列表
@export var effects : Array[GameplayEffect] = []
## 目标 Key
@export var target_key: String = "targets"
## 目标获取策略
@export var targeting_strategy: TargetingStrategy = null
## 技能快捷键
@export var input_action : StringName = &""

## 重写基类的工厂方法
func create_instance(owner: Node) -> GameplayAbilityInstance:
	var instance: GameplayAbilityInstance = super(owner)
	if not is_instance_valid(instance):
		return null
	_inject_features_to_instance(instance)
	return instance

## 获取执行树：自定义树保持只读，标准流程按本次配置构建。
func _get_execution_tree() -> GAS_BTNode:
	if is_instance_valid(execution_tree):
		return execution_tree
	return _build_default_behavior_tree()

## 动态构建行为树结构 (构建的是 GAS_BTNode 资源图，而不是 Instance)
func _build_default_behavior_tree(include_cooldown: bool = true, include_cost: bool = true) -> GAS_BTNode:
	var sequence = GAS_BTSequence.new()
	var nodes: Array[GAS_BTNode] = []

	# 1. 播放动画 (异步，不等待)
	if not animation_name.is_empty():
		var anim_node = AbilityNodePlayAnimation.new()
		anim_node.animation_name = animation_name
		anim_node.animation_speed = animation_speed
		anim_node.node_id = "play_animation"
		nodes.append(anim_node)

	# 2. 前摇等待
	if pre_cast_delay > 0.0:
		var wait = GAS_BTWait.new()
		wait.duration = pre_cast_delay
		wait.node_id = "pre_cast_delay"
		nodes.append(wait)

	# 3. 前摇结束后统一提交：费用失败时不进入冷却。
	var has_cost: bool = not costs.is_empty()
	var has_cooldown: bool = cooldown_duration > 0.0
	for feature: GameplayAbilityFeature in features:
		if is_instance_valid(feature):
			has_cost = has_cost or feature.feature_name == "CostFeature"
			has_cooldown = has_cooldown or feature.feature_name == "CooldownFeature"
	if (include_cooldown and has_cooldown) or (include_cost and has_cost):
		var commit: AbilityNodeCommit = AbilityNodeCommit.new()
		commit.pay_cost = include_cost
		commit.start_cooldown = include_cooldown
		commit.node_id = "commit"
		nodes.append(commit)
	
	# 5. 查找目标
	if is_instance_valid(targeting_strategy):
		var target_search_node = AbilityNodeTargetSearch.new()
		target_search_node.strategy = targeting_strategy
		target_search_node.write_to_key = target_key
		target_search_node.node_id = "target_search"
		nodes.append(target_search_node)

	# 6. 应用效果
	var effect_node := _build_effect_nodes()
	if is_instance_valid(effect_node):
		nodes.append(effect_node)

	# 7. 后摇等待
	if post_cast_delay > 0.0:
		var wait = GAS_BTWait.new()
		wait.duration = post_cast_delay
		wait.node_id = "post_cast_delay"
		nodes.append(wait)

	# 赋值子节点
	sequence.children = nodes
	sequence.node_id = "ability_sequence"
	return sequence

func _build_effect_nodes() -> GAS_BTNode:
	if not effects.is_empty():
		var effect_node = AbilityNodeApplyEffect.new()
		effect_node.effects = effects.duplicate()
		effect_node.target_key = target_key
		effect_node.node_id = "apply_effect"
		return effect_node
	return null

## 在 Instance 中注入 Feature（不修改 Definition，避免资源污染）
func _inject_features_to_instance(instance: GameplayAbilityInstance) -> void:
	if not is_instance_valid(instance):
		push_error("ActiveAbilityDefinition: ability instance is not valid!")
		return

	# 注入 CooldownFeature（如果配置了冷却时间且不存在）
	var cd_feature = CooldownFeature.new()
	if cooldown_duration > 0.0 and not instance.has_feature(cd_feature.feature_name):
		cd_feature.cooldown_duration = cooldown_duration
		instance.add_feature(cd_feature.feature_name, cd_feature)

	# 注入 CostFeature
	var cost_feature = CostFeature.new()
	if not costs.is_empty() and not instance.has_feature(cost_feature.feature_name):
		cost_feature.costs = costs.duplicate(true)
		instance.add_feature(cost_feature.feature_name, cost_feature)

	# 注入技能 InputFeature
	var input_feature = AbilityInputFeature.new()
	if not input_action.is_empty() and not instance.has_feature(input_feature.feature_name):
		input_feature.input_action = input_action
		instance.add_feature(input_feature.feature_name, input_feature)

## 验证配置的合理性
func get_configuration_errors() -> PackedStringArray:
	var errors: PackedStringArray = super()
	_check_number(errors, "pre_cast_delay", pre_cast_delay)
	_check_number(errors, "post_cast_delay", post_cast_delay)
	_check_number(errors, "cooldown_duration", cooldown_duration)
	_check_number(errors, "animation_speed", animation_speed, true)
	_check_quick_features(errors, costs, cooldown_duration, input_action)
	if target_key.is_empty() and (not effects.is_empty() or is_instance_valid(targeting_strategy)):
		errors.append("target_key cannot be empty when targeting or effects are configured")
	for effect: GameplayEffect in effects:
		if not is_instance_valid(effect):
			errors.append("effects contains an empty resource")
	return errors
