extends RefCounted
class_name GameplayAbilityInstance

## 技能的运行时实例，管理执行状态

var _owner: Node
var _definition: GameplayAbilityDefinition
var _features: Dictionary[String, GameplayAbilityFeature] = {}
var _bt_instance : GAS_BTInstance = null
var _blackboard: GAS_BTBlackboard = null

# 【核心状态】技能是否正在执行（行为树是否在跑）
var is_active: bool = false
var disabled : bool = false:
	get:
		return _definition.disabled

var _indicator_instance: Node3D = null
var _is_targeting: bool = false

## 技能完成信号
signal ability_completed(ability: GameplayAbilityInstance)
## 技能数据改变
signal ability_data_changed(ability: GameplayAbilityInstance)

func _init(owner: Node, definition: GameplayAbilityDefinition) -> void:
	_owner = owner
	_definition = definition
	# 初始化行为树黑板
	_blackboard = GAS_BTBlackboard.new()
	_blackboard.value_changed.connect(_on_blackboard_value_changed)
	_blackboard.set_var("ability_instance", self)
	if is_instance_valid(_definition.execution_tree):
		_bt_instance = GAS_BTInstance.new(_owner, _definition.execution_tree, _blackboard)
	#else:
		#push_warning("AbilityInstance: execution_tree is not valid!")

func get_definition() -> GameplayAbilityDefinition:
	return _definition

## 尝试激活技能 (由 Player/Component 调用)
func try_activate(context: Dictionary = {}) -> bool:
	if is_active:
		# 如果技能已激活，无论是否允许重新激活，都应该处理连击输入
		# 触发信号，确保 GAS_BTWaitSignal 能够收到通知（用于连击系统）
		var current_value = _blackboard.get_var("event_input_received", false)
		if not current_value:
			_blackboard.set_var("event_input_received", true)
		else:
			# 如果已经是 true，先设置为 false 再设置为 true，确保触发信号
			_blackboard.set_var("event_input_received", false)
			_blackboard.set_var("event_input_received", true)

		# 检查所有特性的 can_activate
		# 某些特性（如 ToggleFeature）可能允许在已激活时重新激活
		if not can_activate(context):
			return true
		
		# 有特性允许重新激活，注入上下文数据并调用 on_activate
		if is_instance_valid(_blackboard):
			_blackboard.set_var("context", context)

		# 调用所有特性的 on_activate 钩子
		for feature in _features.values():
			if not is_instance_valid(feature):
				continue

			feature.on_activate(self, context)

		return true

	# 1. 检查能不能放 (Cost, CD, Tags, Features)
	if not can_activate(context):
		return false

	# 2. 注入初始黑板数据（在设置 is_active 之前）
	if is_instance_valid(_blackboard):
		_blackboard.clear() # 清理上一轮的残留
		
		# [第一步] 自动合并 Context 中的所有参数到黑板
		# 先注入用户传递的参数，作为基础数据
		for key in context:
			_blackboard.set_var(key, context[key])
			
		# [第二步] 注入系统关键变量 (覆盖潜在的同名用户参数，确保安全性)
		_blackboard.set_var("ability_instance", self)
		_blackboard.set_var("context", context)
		
		# [第三步] 智能映射 target (基于 input_target)
		# input_target 可能是 Node 或 null
		# 我们只设置 'target' (单数)，供 TargetSearch 节点作为输入使用
		# 'targets' (复数) 应由行为树中的索敌策略(TargetingStrategy)生成，而不应在此处硬编码
		_blackboard.set_var("target", context.get("input_target"))
		
		# 设置标志，表示这是首次激活（开启操作）
		_blackboard.set_var("is_first_activation", true)

	# 3. 调用所有特性的 on_activate 钩子（在设置 is_active 之前）
	for feature in _features.values():
		if not is_instance_valid(feature):
			continue
		feature.on_activate(self, context)

	# 4. 【关键】启动行为树（在调用 on_activate 之后）
	# 注意：这里我们只"启动"状态，不扣蓝，也不产生效果。
	# 扣蓝和效果由树里面的节点决定何时发生。
	is_active = true
	return true

# 每帧更新（用于需要持续更新的技能，如连击计时器、引导技能）
func update(delta: float) -> void:
	# 调用所有特性的 update（通用钩子，对所有技能类型有效）
	for feature in _features.values():
		if not is_instance_valid(feature):
			continue
		feature.update(self, delta)
	# 更新行为树
	if is_active and is_instance_valid(_bt_instance):
		var result = _bt_instance.tick(delta)
		if result != GAS_BTNode.Status.RUNNING:
			end_ability(result)

## 结束技能
func end_ability(final_status: int = GAS_BTNode.Status.SUCCESS) -> void:
	if not is_active: return

	is_active = false
	
	# 通知特性技能结束了
	for feature in _features.values():
		if is_instance_valid(feature): 
			feature.on_completed(self)
			
	# 发出信号
	ability_completed.emit(self)

	# (可选) 如果树还在跑但被强制结束，重置树
	if is_instance_valid(_bt_instance):
		_bt_instance.reset_tree()

## 检查是否可以施法
func can_activate(context: Dictionary = {}) -> bool:
	# 如果技能已激活，先让所有特性有机会设置 skip 标志（如 ToggleFeature 设置 skip_cost/skip_cooldown）
	# 然后再进行实际的检查
	if is_active:
		for feature : GameplayAbilityFeature in _features.values():
			if not is_instance_valid(feature):
				continue
			# 先调用一次，让特性有机会设置 skip 标志（不检查返回值）
			feature.can_activate(self, context)

	# 调用所有特性的 can_activate（主动技能钩子）
	# 所有特性的 can_activate 都必须返回 true
	for feature : GameplayAbilityFeature in _features.values():
		if not is_instance_valid(feature):
			continue
		if not feature.can_activate(self, context):
			return false
	return true

#region ========== 特性管理 ==========
## 添加特性
func add_feature(feature_name: String, feature: GameplayAbilityFeature) -> void:
	if _features.has(feature_name):
		push_warning("Feature already exists: ", feature_name)
		return
	_features[feature_name] = feature
	feature.initialize(self)

## 删除特性
func remove_feature(feature_name : StringName) -> bool:
	if _features.has(feature_name):
		_features.erase(feature_name)
		return true
	return false

## 获取特性
func get_feature(feature_name: String) -> GameplayAbilityFeature:
	return _features.get(feature_name, null)

## 是否存在特性
func has_feature(feature_name: String) -> bool:
	return _features.has(feature_name)
#endregion

## 处理技能学习事件（被动技能）
func handle_learned(ability_comp: Node) -> void:
	for feature : GameplayAbilityFeature in _features.values():
		if not is_instance_valid(feature):
			continue
		feature.on_learned(self, ability_comp)

## 处理技能遗忘事件（被动技能）
func handle_forgotten(ability_comp: Node,) -> void:
	for feature in _features.values():
		if not is_instance_valid(feature):
			continue
		feature.on_forgotten(self, ability_comp)

#region ========== 行为树管理 ==========
func get_bt_instance() -> GAS_BTInstance:
	return _bt_instance

func get_blackboard() -> GAS_BTBlackboard:
	return _blackboard

func set_blackboard_var(key: String, value: Variant) -> void:
	_blackboard.set_var(key, value)

func get_blackboard_var(key: String, default: Variant = null) -> Variant:
	return _blackboard.get_var(key, default)

func clear_blackboard() -> void:
	_blackboard.clear()

#endregion

#region ========== 瞄准/预览逻辑 (Targeting) ==========
## 检查是否配置了预览策略
func has_targeting() -> bool:
	return is_instance_valid(_definition.preview_strategy)

## 检查是否应该智能施法
func should_smart_cast() -> bool:
	if GameplayAbilitySystem.smart_cast:
		return true
	return _definition.smart_cast

## [API] 开始预览模式
func start_targeting() -> void:
	if not has_targeting(): 
		return
	_is_targeting = true
	# 使用策略创建视觉指示器
	_indicator_instance = _definition.preview_strategy.create_indicator(_owner)

## [API] 更新预览 (每帧调用)
## [param] mouse_pos: 鼠标在世界空间的坐标
func update_targeting(mouse_pos: Vector3) -> void:
	if not _is_targeting or not is_instance_valid(_indicator_instance):
		return

	_definition.preview_strategy.update_indicator(
		_indicator_instance, 
		_owner, 
		mouse_pos
	)
	
## [API] 确认预览 -> 返回 Context 数据
## [param] mouse_pos: 最终确定的位置
func confirm_targeting(mouse_pos: Vector3) -> Dictionary:
	var context = {}
	if has_targeting():
		# 使用策略计算最终数据
		context = _definition.preview_strategy.get_targeting_context(_owner, mouse_pos)
	_stop_targeting_visuals()
	return context

## [API] 取消预览
func cancel_targeting() -> void:
	# 如果是光标策略，需要恢复默认光标
	if is_instance_valid(_definition.preview_strategy):
		_definition.preview_strategy.cancel_targeting()
		
	_stop_targeting_visuals()

## 内部清理
func _stop_targeting_visuals() -> void:
	_is_targeting = false

	# 清理 3D 指示器（如果有）
	if is_instance_valid(_indicator_instance):
		_indicator_instance.queue_free()
		_indicator_instance = null

#endregion

func get_current_icon() -> Texture:
	for feature in _features.values():
		if not feature.has_method("get_current_icon"):
			continue
		var icon : Texture = feature.get_current_icon(self)
		if is_instance_valid(icon):
			return icon

	# 回退到 Definition 的默认图标
	return _definition.icon

func _on_blackboard_value_changed(key: String, value: Variant) -> void:
	ability_data_changed.emit(self)
