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

## 缓存的默认行为树（所有实例共享，避免重复构建）
var _cached_default_tree: GAS_BTNode = null

## 重写基类的工厂方法
func create_instance(owner: Node) -> GameplayAbilityInstance:
	_validate_configuration()
	var tree_to_use = _get_execution_tree()
	var original_tree = execution_tree
	execution_tree = tree_to_use
	var instance = super(owner)
	execution_tree = original_tree
	_inject_features_to_instance(instance)
	return instance

## 获取执行树（优先使用用户配置，否则使用缓存的默认树）
func _get_execution_tree() -> GAS_BTNode:
	if is_instance_valid(execution_tree):
		return execution_tree
	if is_instance_valid(_cached_default_tree):
		return _cached_default_tree
	_cached_default_tree = _build_default_behavior_tree()
	return _cached_default_tree

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

	# 3. 提交冷却 (前摇结束后进CD)
	if include_cooldown and cooldown_duration > 0.0:
		var commit_cd = AbilityNodeCommitCooldown.new()
		commit_cd.node_id = "commit_cooldown"
		nodes.append(commit_cd)

	# 4. 应用消耗
	if include_cost and not costs.is_empty():
		var commit_cost = AbilityNodeCommitCost.new()
		commit_cost.node_id = "commit_cost"
		nodes.append(commit_cost)
	
	# 5. 查找目标
	if is_instance_valid(targeting_strategy):
		var target_search_node = AbilityNodeTargetSearch.new()
		target_search_node.strategy = targeting_strategy
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
func _validate_configuration() -> void:
	if is_instance_valid(targeting_strategy):
		if effects.is_empty():
			push_warning(
				"ActiveAbilityDefinition [%s]: 配置了 targeting_strategy 但没有配置 effects。\n" % ability_id +
				"targeting_strategy 可能不会被使用。"
			)
	if pre_cast_delay < 0.0:
		push_error("ActiveAbilityDefinition [%s]: pre_cast_delay 不能为负数 (%.2f)" % [ability_id, pre_cast_delay])
		pre_cast_delay = 0.0
	if post_cast_delay < 0.0:
		push_error("ActiveAbilityDefinition [%s]: post_cast_delay 不能为负数 (%.2f)" % [ability_id, post_cast_delay])
		post_cast_delay = 0.0
	if cooldown_duration < 0.0:
		push_error("ActiveAbilityDefinition [%s]: cooldown_duration 不能为负数 (%.2f)" % [ability_id, cooldown_duration])
		cooldown_duration = 0.0
	if animation_speed <= 0.0:
		push_error("ActiveAbilityDefinition [%s]: animation_speed 必须为正数 (%.2f)" % [ability_id, animation_speed])
		animation_speed = 1.0
	if effects.is_empty():
		push_warning(
			"ActiveAbilityDefinition [%s]: 没有配置 effects，技能可能不会产生任何效果。\n" % ability_id +
			"请确保这是预期的行为。"
		)
