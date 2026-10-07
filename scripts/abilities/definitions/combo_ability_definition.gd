extends GameplayAbilityDefinition
class_name ComboAbilityDefinition

@export_group("Combo Config")
@export var combo_steps: Array[ActiveAbilityDefinition] = []  	## 连击段列表
@export var window_duration: float = 0.8                     	## 连击窗口期（秒）
@export var costs : Array[AbilityCostBase] = []             	## 技能消耗
@export var cooldown_duration: float = 0.0                   	## 冷却时间
@export var input_action : StringName = &""						## 技能快捷键


"""
Root Sequence
├── AbilityNodeCommitCost          # 1. 应用消耗（连击开始时）
├── GAS_BTRepeatUntilFailure            # 2. 循环执行连击段，直到超时失败
│   └── GAS_BTSwitch                    # 3. 根据 combo_index 选择连击段
│       ├── Combo Step 1 (Sequence)
│       │   ├── Step 1 Execution Tree  # 执行第一段攻击
│       │   ├── GAS_BTWaitSignal            # 等待连击输入（窗口期）
│       │   ├── AbilityNodeAdvanceCombo # 推进到下一段
│       │   └── GAS_BTSetVar                # 设置下一段图标
│       ├── Combo Step 2 (Sequence)
│       │   ├── Step 2 Execution Tree
│       │   ├── GAS_BTWaitSignal
│       │   ├── AbilityNodeAdvanceCombo
│       │   └── GAS_BTSetVar
│       └── Combo Step 3 (Sequence)
│           ├── Step 3 Execution Tree
│           ├── GAS_BTWaitSignal
│           ├── AbilityNodeAdvanceCombo  # 终结技，重置索引
│           └── GAS_BTSetVar
└── AbilityNodeCommitCooldown      # 4. 应用冷却（连击结束后）
"""

## 重写基类的工厂方法
## 在创建实例时自动注入 Feature 和构建行为树（不修改 Definition，避免资源污染）
func create_instance(owner: Node) -> GameplayAbilityInstance:
	var instance: GameplayAbilityInstance = super(owner)
	if not is_instance_valid(instance):
		return null
	_initialize_blackboard(instance)
	_inject_features_to_instance(instance)
	return instance

func _get_execution_tree() -> GAS_BTNode:
	if is_instance_valid(execution_tree):
		return execution_tree
	return _build_combo_tree()

## 在 Instance 中注入 Feature（不修改 Definition，避免资源污染）
## [param] instance: GameplayAbilityInstance 技能实例
func _inject_features_to_instance(instance: GameplayAbilityInstance) -> void:
	# 注入 CostFeature（如果配置了消耗且不存在）
	if not costs.is_empty():
		var cost_feature = CostFeature.new()
		if not instance.has_feature(cost_feature.feature_name):
			cost_feature.costs = costs.duplicate()
			instance.add_feature(cost_feature.feature_name, cost_feature)

	# 注入 CooldownFeature（如果配置了冷却时间且不存在）
	if cooldown_duration > 0.0:
		var cooldown_feature = CooldownFeature.new()
		if not instance.has_feature(cooldown_feature.feature_name):
			cooldown_feature.cooldown_duration = cooldown_duration
			instance.add_feature(cooldown_feature.feature_name, cooldown_feature)

	# 注入技能 InputFeature
	var input_feature = AbilityInputFeature.new()
	if not input_action.is_empty() and not instance.has_feature(input_feature.feature_name):
		input_feature.input_action = input_action
		instance.add_feature(input_feature.feature_name, input_feature)

	# 注入 DynamicIconFeature（如果连击段有图标）
	_inject_icon_feature(instance)

## 注入图标 Feature
## [param] instance: GameplayAbilityInstance 技能实例
func _inject_icon_feature(instance: GameplayAbilityInstance) -> void:
	var icon_map: Dictionary[StringName, Texture] = {}
	# 收集所有连击段的图标
	for i in range(combo_steps.size()):
		var step_def = combo_steps[i]
		if is_instance_valid(step_def) and is_instance_valid(step_def.icon):
			icon_map["combo_%d" % (i + 1)] = step_def.icon

	# 如果至少有一个图标，则注入 Feature
	if not icon_map.is_empty():
		# 创建新的 Feature
		var icon_feature = DynamicIconFeature.new()
		# 检查是否已存在 DynamicIconFeature
		var existing_feature = instance.get_feature(icon_feature.feature_name)
		if is_instance_valid(existing_feature):
			# 如果已存在，移除旧的并创建新的（确保使用最新的图标映射）
			instance.remove_feature(existing_feature.feature_name)

		icon_feature.icon_map = icon_map.duplicate()
		icon_feature.icon_id_key = "current_icon_id"
		instance.add_feature(icon_feature.feature_name, icon_feature)

## 初始化黑板变量
## [param] instance: GameplayAbilityInstance 技能实例
func _initialize_blackboard(instance: GameplayAbilityInstance) -> void:
	instance.set_blackboard_var("combo_index", 0)
	instance.set_blackboard_var("combo_expiry_time", 0)
	instance.set_blackboard_var("combo_next_icon", null) # 初始为空，UI应显示默认图标
	# 初始化第一段图标（确保初始状态显示正确的图标）
	if combo_steps.size() > 0:
		instance.set_blackboard_var("current_icon_id", "combo_1")
	else:
		instance.set_blackboard_var("current_icon_id", null)

## 验证配置的合理性
func get_configuration_errors() -> PackedStringArray:
	var errors: PackedStringArray = super()
	_check_number(errors, "window_duration", window_duration, true)
	_check_number(errors, "cooldown_duration", cooldown_duration)
	_check_quick_features(errors, costs, cooldown_duration, input_action)
	if not is_instance_valid(execution_tree) and combo_steps.is_empty():
		errors.append("combo_steps cannot be empty without a custom execution_tree")
	for index: int in range(combo_steps.size()):
		var step: ActiveAbilityDefinition = combo_steps[index]
		if not is_instance_valid(step):
			errors.append("combo_steps[%d] is empty" % index)
		else:
			for error: String in step.get_configuration_errors():
				errors.append("combo_steps[%d].%s" % [index, error])
	return errors

func _build_combo_tree() -> GAS_BTNode:
	# --- 最外层 Sequence ---
	# 结构: [Cost -> RepeatUntilFailure(Switch) -> Cooldown]
	var root_sequence = GAS_BTSequence.new()

	# 1. 【头部】应用消耗 (无论第几段，只要触发技能就检查消耗)
	# 如果你想只在第一段消耗，可以在 Switch 内部的第一段里加 Cost
	var cost_node = AbilityNodeCommitCost.new()
	cost_node.node_id = "commit_cost"
	root_sequence.children.append(cost_node)

	# 2. 【中部】RepeatUntilFailure 包裹 Switch 选择器
	# 逻辑：循环执行连击段，直到某一段超时失败（GAS_BTWaitSignal 返回 FAILURE）
	var repeat_node = GAS_BTRepeatUntilFailure.new()
	repeat_node.node_id = "combo_loop"

	var switch_node = GAS_BTSwitch.new()
	switch_node.variable_key = "combo_index"
	switch_node.node_id = "combo_switch"
	# 注意：GAS_BTSwitch 只负责根据索引选择子节点，不处理超时逻辑
	# 超时由连击段内部的 GAS_BTWaitSignal 返回 FAILURE 来处理
	var switch_children: Array[GAS_BTNode] = []
	
	for i in range(combo_steps.size()):
		var step_def = combo_steps[i]
		var is_last_step = (i == combo_steps.size() - 1)
		# 构建子树包装器
		var wrapper = GAS_BTSequence.new()
		wrapper.node_id = "combo_step_%d" % (i + 1)
		
		# A. 【关键】在执行段之前设置当前段的图标
		# 当 combo_index = i 时，执行第 i 段，应该显示第 i+1 段的图标（下一段）
		# 这样在执行当前段时，UI 已经显示下一段的图标，提示玩家可以继续连击
		var icon_node = GAS_BTSetVar.new()
		icon_node.variable_key = "current_icon_id"
		if is_last_step:
			# 如果是终结技，执行完后会直接结束连击，不需要设置下一段图标
			# 保持当前段的图标（combo_i+1），或者设置为 null 使用默认图标
			icon_node.value = "combo_%d" % (i + 1)  # 保持当前段的图标
		else:
			# 如果是中间段，设置为下一段的图标ID
			# 当前是第 i 段（索引从0开始），下一段是第 i+1 段，对应图标 combo_i+2（图标ID从1开始）
			icon_node.value = "combo_%d" % (i + 2)
		icon_node.node_id = "set_combo_icon"
		wrapper.children.append(icon_node)
		
		# B. 执行段的能力树（包含前摇、打击、后摇等）
		# 注意：连击段不应该包含CD、Cost，CD只在连击整体结束时应用
		var step_tree = step_def.execution_tree
		if step_tree == null:
			# 构建不带CD的行为树（连击段不需要单独的CD）
			step_tree = step_def.call("_build_default_behavior_tree", false, false)
		if is_instance_valid(step_tree):
			# 为段树设置名称
			var duplicated_tree = step_tree.duplicate(true)
			# 移除可能存在的CD节点（如果用户手动配置了execution_tree）
			_remove_cooldown_nodes(duplicated_tree)
			if duplicated_tree.node_id.is_empty():
				duplicated_tree.node_id = "step_%d_execution_tree" % (i + 1)
			wrapper.children.append(duplicated_tree)

		# C. 【关键】对于最后一段，执行完后直接结束，不等待输入
		# 对于中间段，等待连击输入，如果收到输入则继续下一段，如果超时则结束连击
		if not is_last_step:
			# 添加 GAS_BTWaitSignal 等待连击输入
			# 这是连击系统的核心：等待玩家在窗口期内输入，或超时失败
			var wait_signal = GAS_BTWaitSignal.new()
			wait_signal.signal_key = "event_input_received"
			wait_signal.timeout = window_duration  # 使用连击窗口期作为超时时间
			wait_signal.consume_signal = true  # 消费信号，避免重复触发
			wait_signal.node_id = "wait_combo_input"
			wrapper.children.append(wait_signal)

			# D. 推进索引（只有在 GAS_BTWaitSignal 返回 SUCCESS（收到输入）时才会执行到这里）
			# 如果 GAS_BTWaitSignal 返回 FAILURE（超时），整个 wrapper 会返回 FAILURE，结束连击
			var advance_node = GAS_BTSetVar.new()
			advance_node.variable_key = "combo_index"
			advance_node.value = i + 1
			advance_node.node_id = "advance_combo"
			wrapper.children.append(advance_node)
		else:
			# 最后一段：执行完后还原图标，然后结束连击
			# 还原图标为第一段的图标（combo_1），这样下次激活技能时，图标就是正确的
			var reset_icon_node = GAS_BTSetVar.new()
			reset_icon_node.variable_key = "current_icon_id"
			reset_icon_node.value = "combo_1" if combo_steps.size() > 0 else null
			reset_icon_node.node_id = "reset_combo_icon"
			wrapper.children.append(reset_icon_node)
			
			# 使用 GAS_BTCheckVar 检查一个不存在的变量，让它返回 FAILURE
			# 这样 GAS_BTSequence 会返回 FAILURE，GAS_BTRepeatUntilFailure 会停止循环
			var end_combo_node = GAS_BTCheckVar.new()
			end_combo_node.key = "__combo_end_marker__"  # 使用一个不存在的变量
			end_combo_node.check_exist_only = true  # 只检查存在性，变量不存在会返回 FAILURE
			end_combo_node.node_id = "end_combo"
			wrapper.children.append(end_combo_node)
		switch_children.append(wrapper)
		
	switch_node.children = switch_children
	repeat_node.child = switch_node  # 使用 child 属性（Decorator 模式）
	root_sequence.children.append(repeat_node)

	# 3. 【尾部】应用冷却
	# 当 RepeatUntilFailure 返回 FAILURE（某一段超时）时，执行 CD 并完成技能
	var cd_node = AbilityNodeCommitCooldown.new()
	cd_node.node_id = "commit_cooldown"
	root_sequence.children.append(cd_node)

	# 为根序列设置名称
	root_sequence.node_id = "combo_root_sequence"
	return root_sequence

## 递归移除行为树中的冷却节点（用于连击段）
func _remove_cooldown_nodes(node: GAS_BTNode) -> void:
	if not is_instance_valid(node):
		return

	# 如果是组合节点，递归处理子节点
	if node is GAS_BTComposite:
		var composite = node as GAS_BTComposite
		# 从后往前遍历，避免删除时索引问题
		for i in range(composite.children.size() - 1, -1, -1):
			var child = composite.children[i]
			if child is AbilityNodeCommitCooldown:
				# 移除CD节点
				composite.children.remove_at(i)
			else:
				# 递归处理子节点
				_remove_cooldown_nodes(child)
	elif node is GAS_BTDecorator:
		var decorator = node as GAS_BTDecorator
		if is_instance_valid(decorator.child):
			if decorator.child is AbilityNodeCommitCooldown:
				# 如果装饰器的子节点是CD节点，移除它（这通常不会发生，但为了安全）
				decorator.child = null
			else:
				_remove_cooldown_nodes(decorator.child)
