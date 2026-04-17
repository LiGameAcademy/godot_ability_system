extends GameplayAbilityDefinition
class_name ToggleAbilityDefinition

"""
Root Sequence
├── AbilityNodePlayAnimation      # 1. 播放动画
├── GAS_BTWait                        # 2. 前摇等待
├── AbilityNodeTargetSearch       # 3. 查找目标
├── GAS_BTRepeatUntilFailure          # 4. 循环执行直到关闭
│   └── GAS_BTSelector                # 5. 切换选择器
│       ├── Turn Off Sequence    # 分支1：关闭逻辑
│       │   ├── GAS_BTCheckVar        # toggle_action == "turn_off"
│       │   ├── AbilityNodeRemoveStatus
│       │   ├── GAS_BTSetVar (clear icon)
│       │   ├── AbilityNodeCommitCooldown
│       │   └── GAS_BTCheckVar (end marker, 返回 FAILURE)
│       ├── Turn On Sequence      # 分支2：开启逻辑
│       │   ├── GAS_BTCheckVar        # toggle_action == "turn_on"
│       │   ├── AbilityNodeCommitCost
│       │   ├── AbilityNodeApplyStatus
│       │   ├── GAS_BTSetVar (icon_when_active)
│       │   └── GAS_BTSetVar (set toggle_action = "on")
│       └── Keep On Sequence      # 分支3：保持状态（事件驱动）
│           ├── GAS_BTCheckVar        # toggle_action == "on"
│           └── GAS_BTWaitSignal      # timeout = -1（无限等待），收到输入后进入关闭分支
└── GAS_BTWait                        # 6. 后摇等待
"""

@export_group("Quick Config")
@export var animation_name : StringName = &""
@export var animation_speed : float = 1.0
## 技能前摇时间（开启/关闭前的等待）
@export var pre_cast_delay : float = 0.0
## 技能后摇时间（开启/关闭后的僵直）
@export var post_cast_delay : float = 0.0
## 技能冷却时间（切换时触发冷却）
@export var cooldown_duration : float = 0.0
## 技能消耗
@export var costs : Array[AbilityCostBase] = []

@export_group("Toggle Settings")
## 切换时应用的状态（开启时应用，关闭时移除）
@export var toggle_statuses : Dictionary[GameplayStatusData, int] = {}
## 目标获取策略（通常使用 SelfTargetingStrategy）
@export var targeting_strategy: TargetingStrategy = null
## 目标 Key
@export var target_key: String = "targets"
## 激活时的图标（当状态存在时显示的图标）
@export var icon_when_active: Texture = null

## 缓存的默认行为树（所有实例共享，避免重复构建）
var _cached_default_tree: GAS_BTNode = null

## 重写基类的工厂方法
## 在创建实例时自动注入 Feature 和构建行为树（不修改 Definition，避免资源污染）
func create_instance(owner: Node) -> GameplayAbilityInstance:
	# 1. 验证配置
	_validate_configuration()

	# 2. 获取执行树（优先使用用户配置，否则使用缓存的默认树）
	var tree_to_use = _get_execution_tree()

	# 3. 临时设置 execution_tree（仅用于创建 Instance，不污染资源）
	var original_tree = execution_tree
	execution_tree = tree_to_use

	# 4. 调用父类创建实例（这会复制 features 到 instance）
	var instance = super(owner)

	# 5. 立即恢复 execution_tree（避免资源污染）
	execution_tree = original_tree

	# 6. 在 Instance 中动态注入 Feature（不修改 Definition，避免资源污染）
	_inject_features_to_instance(instance)

	return instance

## 获取执行树（优先使用用户配置，否则使用缓存的默认树）
## 符合享元模式：所有实例共享同一个行为树
func _get_execution_tree() -> GAS_BTNode:
	# 如果用户手动配置了，使用用户的
	if is_instance_valid(execution_tree):
		return execution_tree

	# 如果已缓存，使用缓存的（享元模式）
	if is_instance_valid(_cached_default_tree):
		return _cached_default_tree

	# 构建并缓存（只构建一次，之后所有实例共享）
	_cached_default_tree = _build_default_behavior_tree()
	return _cached_default_tree

## 动态构建行为树结构 (构建的是 GAS_BTNode 资源图，而不是 Instance)
func _build_default_behavior_tree() -> GAS_BTNode:
	var sequence = GAS_BTSequence.new()
	var nodes: Array[GAS_BTNode] = []

	# 1. 播放动画（异步，不等待）
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
		
	# 3. 查找目标
	if is_instance_valid(targeting_strategy):
		var target_search_node = AbilityNodeTargetSearch.new()
		target_search_node.strategy = targeting_strategy
		target_search_node.node_id = "target_search"
		nodes.append(target_search_node)

	# 4. 切换逻辑：使用 GAS_BTRepeatUntilFailure + GAS_BTSelector 实现
	# 循环执行直到关闭分支返回 FAILURE（结束技能）
	var repeat_node = GAS_BTRepeatUntilFailure.new()
	repeat_node.node_id = "toggle_loop"
	repeat_node.return_success = true  # 结束时返回 SUCCESS

	var toggle_selector = GAS_BTSelector.new()
	toggle_selector.node_id = "toggle_selector"

	# 收集状态ID（用于移除状态）
	var status_ids: Array[StringName] = []
	for status_data in toggle_statuses:
		if is_instance_valid(status_data) and not status_data.status_id.is_empty():
			status_ids.append(status_data.status_id)
	
	# 分支1：关闭（移除状态）
	var turn_off_sequence = _build_turn_off_sequence()
	toggle_selector.children.append(turn_off_sequence)
	
	# 分支2：开启（应用状态）
	var turn_on_sequence = _build_turn_on_sequence()
	toggle_selector.children.append(turn_on_sequence)

	# 分支3：保持状态（当 toggle_action == "on" 时，保持 RUNNING）
	var keep_on_sequence = _build_keep_on_sequence()
	toggle_selector.children.append(keep_on_sequence)

	repeat_node.child = toggle_selector
	nodes.append(repeat_node)

	# 5. 后摇等待
	if post_cast_delay > 0.0:
		var wait = GAS_BTWait.new()
		wait.duration = post_cast_delay
		wait.node_id = "post_cast_delay"
		nodes.append(wait)
	
	# 赋值子节点
	sequence.children = nodes
	sequence.node_id = "toggle_ability_sequence"
	return sequence

func _build_turn_off_sequence() -> GAS_BTSequence:
	# 收集状态ID（用于移除状态）
	var status_ids: Array[StringName] = []
	for status_data in toggle_statuses:
		if is_instance_valid(status_data) and not status_data.status_id.is_empty():
			status_ids.append(status_data.status_id)
	
	var turn_off_sequence = GAS_BTSequence.new()
	turn_off_sequence.node_id = "turn_off_sequence"

	# 检查黑板变量，判断是否为"关闭"操作
	var check_toggle_action_off = GAS_BTCheckVar.new()
	check_toggle_action_off.key = "toggle_action"
	check_toggle_action_off.value = "turn_off"
	check_toggle_action_off.node_id = "check_toggle_action_off"
	turn_off_sequence.children.append(check_toggle_action_off)

	# 移除状态
	if not status_ids.is_empty():
		var remove_status_node = AbilityNodeRemoveStatus.new()
		remove_status_node.status_ids = status_ids.duplicate()
		remove_status_node.target_key = target_key
		remove_status_node.node_id = "remove_status"
		turn_off_sequence.children.append(remove_status_node)

	# 清除激活图标（恢复默认图标）
	if is_instance_valid(icon_when_active):
		var clear_icon_node = GAS_BTSetVar.new()
		clear_icon_node.variable_key = "current_icon_id"
		clear_icon_node.value = null  # null 表示恢复默认图标
		clear_icon_node.node_id = "clear_active_icon"
		turn_off_sequence.children.append(clear_icon_node)

	# 提交冷却（关闭时触发冷却）
	if cooldown_duration > 0.0:
		var commit_cd = AbilityNodeCommitCooldown.new()
		commit_cd.node_id = "commit_cooldown"
		turn_off_sequence.children.append(commit_cd)

	# 关闭完成后，返回 FAILURE 来结束 GAS_BTRepeatUntilFailure 循环
	var end_combo_node = GAS_BTCheckVar.new()
	end_combo_node.key = "__toggle_end_marker__"  # 使用一个不存在的变量
	end_combo_node.check_exist_only = true  # 只检查存在性，变量不存在会返回 FAILURE
	end_combo_node.node_id = "end_toggle"
	turn_off_sequence.children.append(end_combo_node)

	return turn_off_sequence

func _build_turn_on_sequence() -> GAS_BTSequence:
	# 分支2：开启（应用状态）
	var turn_on_sequence = GAS_BTSequence.new()
	turn_on_sequence.node_id = "turn_on_sequence"

	# 检查黑板变量，判断是否为"开启"操作
	var check_toggle_action_on = GAS_BTCheckVar.new()
	check_toggle_action_on.key = "toggle_action"
	check_toggle_action_on.value = "turn_on"
	check_toggle_action_on.node_id = "check_toggle_action_on"
	turn_on_sequence.children.append(check_toggle_action_on)
	
	# 提交消耗（开启时消耗资源，如魔法值）
	if not costs.is_empty():
		var commit_cost_node = AbilityNodeCommitCost.new()
		commit_cost_node.node_id = "commit_cost"
		turn_on_sequence.children.append(commit_cost_node)

	# 应用状态
	if not toggle_statuses.is_empty():
		var apply_status_node = AbilityNodeApplyStatus.new()
		apply_status_node.statuses = toggle_statuses.duplicate()
		apply_status_node.target_key = target_key
		apply_status_node.node_id = "apply_status"
		turn_on_sequence.children.append(apply_status_node)

	# 设置激活图标（如果配置了）
	if is_instance_valid(icon_when_active):
		var set_icon_node = GAS_BTSetVar.new()
		set_icon_node.variable_key = "current_icon_id"
		set_icon_node.value = "active"  # 设置图标ID为 "active"
		set_icon_node.node_id = "set_active_icon"
		turn_on_sequence.children.append(set_icon_node)

	# 开启完成后，设置 toggle_action 为 "on"，进入保持状态
	var set_keep_on = GAS_BTSetVar.new()
	set_keep_on.variable_key = "toggle_action"
	set_keep_on.value = "on"
	set_keep_on.node_id = "set_keep_on"
	turn_on_sequence.children.append(set_keep_on)

	return turn_on_sequence

func _build_keep_on_sequence() -> GAS_BTSequence:
	# 保持状态分支：当 toggle_action == "on" 时，事件驱动等待关闭输入
	var keep_on_sequence = GAS_BTSequence.new()
	keep_on_sequence.node_id = "keep_on_sequence"

	# 检查是否为保持状态
	var check_keep_on = GAS_BTCheckVar.new()
	check_keep_on.key = "toggle_action"
	check_keep_on.value = "on"
	check_keep_on.node_id = "check_keep_on"
	keep_on_sequence.children.append(check_keep_on)

	# 事件驱动等待：timeout < 0 表示无限等待，只在收到信号时返回 SUCCESS
	var wait_signal = GAS_BTWaitSignal.new()
	wait_signal.signal_key = "event_input_received"
	wait_signal.timeout = -1.0  # 无限等待，避免轮询
	wait_signal.consume_signal = true
	wait_signal.node_id = "wait_toggle_off_signal"
	keep_on_sequence.children.append(wait_signal)

	return keep_on_sequence

## 在 Instance 中注入 Feature（不修改 Definition，避免资源污染）
func _inject_features_to_instance(instance: GameplayAbilityInstance) -> void:
	# 注入 ToggleFeature（如果不存在）
	var toggle_feature = ToggleFeature.new()
	if not instance.has_feature(toggle_feature.feature_name):
		instance.add_feature(toggle_feature.feature_name, toggle_feature)

	if not costs.is_empty():
		var cost_feature = CostFeature.new()
		if not instance.has_feature(cost_feature.feature_name):
			cost_feature.costs = costs.duplicate(true)
			instance.add_feature(cost_feature.feature_name, cost_feature)

	# 注入 CooldownFeature（如果配置了冷却时间且不存在）
	if cooldown_duration > 0.0:
		var cd_feature = CooldownFeature.new()
		if not instance.has_feature(cd_feature.feature_name):
			cd_feature.cooldown_duration = cooldown_duration
			instance.add_feature(cd_feature.feature_name, cd_feature)

	# 注入 DynamicIconFeature（如果配置了激活图标）
	if is_instance_valid(icon_when_active):
		_inject_icon_feature(instance)

## 注入图标 Feature
func _inject_icon_feature(instance: GameplayAbilityInstance) -> void:
	var icon_feature = DynamicIconFeature.new()
	var existing_feature = instance.get_feature(icon_feature.feature_name)
	if is_instance_valid(existing_feature):
		# 如果已存在，更新图标映射
		icon_feature = existing_feature as DynamicIconFeature
		if not icon_feature.icon_map.has("active"):
			icon_feature.icon_map["active"] = icon_when_active
	else:
		icon_feature.icon_map["active"] = icon_when_active
		icon_feature.icon_id_key = "current_icon_id"
		instance.add_feature(icon_feature.feature_name, icon_feature)

## 验证配置的合理性
func _validate_configuration() -> void:
	# 验证：前摇和后摇时间应该非负
	if pre_cast_delay < 0.0:
		push_error("ToggleAbilityDefinition [%s]: pre_cast_delay 不能为负数 (%.2f)" % [ability_id, pre_cast_delay])
		pre_cast_delay = 0.0

	if post_cast_delay < 0.0:
		push_error("ToggleAbilityDefinition [%s]: post_cast_delay 不能为负数 (%.2f)" % [ability_id, post_cast_delay])
		post_cast_delay = 0.0

	# 验证：冷却时间应该非负
	if cooldown_duration < 0.0:
		push_error("ToggleAbilityDefinition [%s]: cooldown_duration 不能为负数 (%.2f)" % [ability_id, cooldown_duration])
		cooldown_duration = 0.0

	# 验证：动画速度应该为正
	if animation_speed <= 0.0:
		push_error("ToggleAbilityDefinition [%s]: animation_speed 必须为正数 (%.2f)" % [ability_id, animation_speed])
		animation_speed = 1.0

	# 验证：如果配置了 targeting_strategy，应该配置了 toggle_statuses
	if is_instance_valid(targeting_strategy):
		if toggle_statuses.is_empty():
			push_warning(
				"ToggleAbilityDefinition [%s]: 配置了 targeting_strategy 但没有配置 toggle_statuses。\n" % ability_id +
				"targeting_strategy 可能不会被使用。"
			)

	# 验证：应该配置状态
	if toggle_statuses.is_empty():
		push_warning(
			"ToggleAbilityDefinition [%s]: 没有配置 toggle_statuses，技能可能不会产生任何效果。\n" % ability_id +
			"请确保这是预期的行为。"
		)
