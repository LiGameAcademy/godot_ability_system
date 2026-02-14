extends Node
class_name GameplayAbilityComponent

## 技能组件 (GAS 核心容器)
## 
## 职责：
## 1. 充当技能实例的"容器"和"工厂"。
## 2. 调度 Update 循环，仅驱动活跃的技能。
## 3. 处理技能之间的互斥/打断逻辑 (通过 Tags 或简单 ID 互斥)。

@export_group("Initialization")
## 初始技能列表（在 _ready 时自动学习）
@export var _initial_abilities: Array[GameplayAbilityDefinition] = []

## 已学会的技能字典（运行时数据）
var _learned_abilities: Dictionary[StringName, GameplayAbilityInstance] = {}

## 当前正在执行的技能实例（用于后摇可取消机制）
## 注意：这通常是最新激活的技能，用于处理技能间的互斥逻辑
var _current_casting_ability: GameplayAbilityInstance = null
## 当前正在预览的技能实例（用于管理预览状态）
var _current_targeting_ability: GameplayAbilityInstance = null

#region ========== 信号定义 ==========
signal ability_learned(ability: GameplayAbilityInstance)				## 技能学会信号
signal ability_forgotten(ability_id: StringName)						## 技能遗忘信号
signal ability_activated(ability: GameplayAbilityInstance)				## 技能激活信号
signal ability_completed(ability: GameplayAbilityInstance)				## 技能完成信号（所有逻辑执行完毕，进入后摇阶段）
#endregion

#region ========== 生命周期 ==========
func _ready() -> void:
	# 学习初始技能
	for ability_data in _initial_abilities:
		learn_ability(ability_data)
	# 启用 process 以更新技能内部状态（冷却、连击计时器等）
	set_process(true)

func _process(delta: float) -> void:
	# 统一调用所有技能的 update 方法（符合开闭原则）
	# 技能会在自己的 update 中管理冷却时间
	for ability_id in _learned_abilities:
		var ability_instance : GameplayAbilityInstance = _learned_abilities[ability_id]
		if not is_instance_valid(ability_instance):
			continue

		# 更新技能（包括冷却时间）
		ability_instance.update(delta)
#endregion

#region ========== 公共API - 技能管理 ==========
## 初始化技能组件
## [param] 
func initialize(initial_abilities : Array[GameplayAbilityDefinition] =[]) -> void:
	if not initial_abilities.is_empty():
		_initial_abilities = initial_abilities.duplicate(true)
		
	# 学习初始技能
	for ability_data in _initial_abilities:
		learn_ability(ability_data)

## 匹配输入
func match_input(event: InputEvent) -> StringName:
	for instance : GameplayAbilityInstance in _learned_abilities.values():
		# 1. 获取输入特性
		var input_feature = instance.get_feature("AbilityInputFeature") as AbilityInputFeature
		if not is_instance_valid(input_feature):
			continue
		# 2. 筛选匹配的技能
		if input_feature.match_input(event):
			# 3. 找到目标！返回技能实例ID
			return instance.get_definition().ability_id
	return &""

## 学习技能
## [param] ability_data: GameplayAbilityDefinition 技能定义
func learn_ability(ability_data: GameplayAbilityDefinition) -> void:
	if not is_instance_valid(ability_data):
		push_error("GameplayAbilityComponent: Ability data is not valid")
		return

	var ability_id := ability_data.ability_id
	if _learned_abilities.has(ability_id):
		# 已经学会
		push_warning("GameplayAbilityComponent: Ability %s already learned." % ability_id)
		return

	var learned_ability : GameplayAbilityInstance = ability_data.create_instance(get_parent())
	if not is_instance_valid(learned_ability):
		push_error("GameplayAbilityComponent: Ability %s create instance failed." % ability_id)
		return

	_learned_abilities[ability_id] = learned_ability

	# 订阅技能完成信号
	if not learned_ability.ability_completed.is_connected(_on_ability_completed):
		learned_ability.ability_completed.connect(_on_ability_completed)

	# 检查并应用被动技能效果
	learned_ability.handle_learned(self)
	
	ability_learned.emit(learned_ability)
	AbilityEventBus.trigger_game_event(&"ability_learned", {
		"entity": get_parent(),
		"ability_id": ability_id
	})
	
## 遗忘技能
## [param] ability_id: StringName 技能ID
func forget_ability(ability_id: StringName) -> void:
	if not _learned_abilities.has(ability_id):
		push_warning("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return
	var ability_instance : GameplayAbilityInstance = _learned_abilities[ability_id]
	# 取消订阅信号
	if not is_instance_valid(ability_instance):
		push_warning("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return
	
	if ability_instance.ability_completed.is_connected(_on_ability_completed):
		ability_instance.ability_completed.disconnect(_on_ability_completed)
	# 移除被动技能效果
	ability_instance.handle_forgotten(self)
	_learned_abilities.erase(ability_id)

	ability_forgotten.emit(ability_id)
	AbilityEventBus.trigger_game_event(&"ability_forgotten", {
		"entity": get_parent(),
		"ability_id": ability_id
	})

## 禁用技能
## [param] ability_id: StringName 技能ID
func disable_ability(ability_id: StringName) -> void:
	var ability_instance : GameplayAbilityInstance = _learned_abilities[ability_id]
	if is_instance_valid(ability_instance):
		ability_instance.disabled = true
	else:
		push_warning("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return

## 启用技能
## [param] ability_id: StringName 技能ID
func enable_ability(ability_id: StringName) -> void:
	var ability_instance : GameplayAbilityInstance = _learned_abilities[ability_id]
	if is_instance_valid(ability_instance):
		ability_instance.disabled = false
	else:
		push_warning("GameplayAbilityComponent: Ability %s not found." % ability_id)
		return

## 获取技能实例
## [param] ability_id: StringName 技能ID
## [return] GameplayAbilityInstance 技能实例，如果不存在则返回 null
func get_ability_instance(ability_id: StringName) -> GameplayAbilityInstance:
	return _learned_abilities.get(ability_id, null)

## 获取所有技能实例
## [return] Dictionary[StringName, GameplayAbilityInstance] 技能实例字典
func get_all_ability_instances() -> Dictionary[StringName, GameplayAbilityInstance]:
	return _learned_abilities
#endregion

#region ========== 公共API - 技能执行 ==========
## 检查是否可以激活技能
## [param] ability_id: StringName 技能ID
## [param] context: 技能执行上下文
## [return] bool 是否可以激活
func can_activate_ability(ability_id: StringName, context: Dictionary = {}) -> bool:
	var ability_instance = get_ability_instance(ability_id)
	if not is_instance_valid(ability_instance):
		push_error("GameplayAbilityComponent: Ability instance is not valid.")
		return false

	if ability_instance.disabled:
		return false

	_prepare_context(ability_id, ability_instance, context)
	
	return ability_instance.can_activate(context)

## 尝试激活技能
## 注意：冷却相关逻辑由 AbilityInstance 自己处理，Component 不涉及冷却
## [param] ability_id: StringName 技能ID
## [param] context: 技能执行上下文
## [return] bool 是否成功激活
func try_activate_ability(ability_id: StringName, context: Dictionary = {}) -> bool:
	var ability_instance = get_ability_instance(ability_id)
	if not is_instance_valid(ability_instance):
		push_error("GameplayAbilityComponent: Ability instance is not valid.")
		return false
	
	_prepare_context(ability_id, ability_instance, context)
	
	# 正常执行技能：检查消耗和冷却（由 Ability 自己处理）
	# 注意：冷却检查、冷却时间计算、冷却缩减应用都由 Ability._commit_cast() 处理
	if not ability_instance.try_activate(context):
		push_error("GameplayAbilityComponent: Ability %s try activate failed." % ability_instance.get_definition().ability_id)
		return false

	_on_ability_activated(ability_instance)
	return true

## 强制激活技能（跳过 can_activate 检查）
## [param] ability_id: StringName 技能ID
## [param] context: 技能执行上下文
func activate_ability(ability_id: StringName, context: Dictionary = {}) -> void:
	var ability_instance = get_ability_instance(ability_id)
	if not is_instance_valid(ability_instance):
		push_error("GameplayAbilityComponent: Ability instance is not valid.")
		return
	
	_prepare_context(ability_id, ability_instance, context)
	
	ability_instance.activate(context)
	_on_ability_activated(ability_instance)

## 内部准备技能上下文
func _prepare_context(ability_id: StringName, ability_instance: GameplayAbilityInstance, context: Dictionary) -> void:
	context.ability = ability_instance
	context.ability_component = self
	context.ability_id = ability_id
	context.instigator = get_parent()

## 内部处理技能激活后的通用逻辑
func _on_ability_activated(ability_instance: GameplayAbilityInstance) -> void:
	# 设置当前正在执行的技能（用于后摇可取消机制）
	_current_casting_ability = ability_instance

	ability_activated.emit(ability_instance)
	AbilityEventBus.trigger_game_event(&"ability_activated", {
		"entity": get_parent(),
		"ability_id": ability_instance.get_definition().ability_id,
	})
	
	# 订阅技能完成信号（如果尚未订阅）
	if not ability_instance.ability_completed.is_connected(_on_ability_completed):
		ability_instance.ability_completed.connect(_on_ability_completed)
#endregion

## 强制中断当前技能（任何阶段都可以中断）
## 注意：这与后摇取消（can_interrupt）不同，强制中断可以在前摇阶段执行
## 但需要技能允许强制中断（can_be_force_cancelled = true）
## [param] ability_id: StringName 技能ID（可选，如果不提供则取消当前执行的技能）
## [param] context: Dictionary 技能执行上下文
func cancel_ability(ability_id: StringName = &"", context: Dictionary = {}) -> void:
	var target_id = ability_id
	if ability_id.is_empty():
		target_id = _current_casting_ability.get_definition().ability_id
		
	if target_id.is_empty():
		return

	var ability_instance = get_ability_instance(target_id)
	if not is_instance_valid(ability_instance):
		return

	ability_instance.end_ability(GAS_BTNode.Status.FAILURE)
	AbilityEventBus.trigger_game_event(&"ability_cancelled", {
		"entity": get_parent(),
		"ability_id": target_id
	})

func get_current_casting_ability() -> GameplayAbilityInstance:
	return _current_casting_ability

func get_all_ability_ids() -> Array:
	return _learned_abilities.keys()

func has_ability(ability_id: StringName) -> bool:
	return _learned_abilities.has(ability_id)

#region ========== 公共API - 交互与预览 ==========
## 请求使用技能（用户输入的入口）
## 根据配置决定是直接施法（智能施法/瞬发）还是进入预览模式
## [param] ability_id: 技能 ID
## [return] GameplayAbilityInstance 如果进入预览模式返回实例，否则返回 null
func request_ability_preview(ability_id: StringName) -> GameplayAbilityInstance:
	var ability_instance = get_ability_instance(ability_id)
	if not is_instance_valid(ability_instance):
		return null

	# 1. 前置检查：如果 CD 没好，就别预览了
	if not can_activate_ability(ability_id):
		# 这里可以触发 UI 提示 "技能冷却中"
		return null

	# 2. 分支判断
	if not ability_instance.has_targeting() or ability_instance.should_smart_cast():
		# 分支 A: 瞬发 或 智能施法 -> 返回 null
		# 控制器应该立即调用 try_activate_ability
		return null
	else:
		# 分支 B: 进入预览模式
		ability_instance.start_targeting()
		# 如果之前有技能在瞄准，先取消它
		if is_instance_valid(_current_targeting_ability) and _current_targeting_ability != ability_instance:
			_current_targeting_ability.cancel_targeting()
		_current_targeting_ability = ability_instance
		return ability_instance

## 取消指定技能的预览
## [param] ability_id: StringName 技能 ID（可选，如果不提供则取消当前预览的技能）
func cancel_ability_preview(ability_id: StringName = &"") -> void:
	var target_id = ability_id
	if target_id.is_empty():
		# 如果没有指定技能ID，取消当前预览的技能
		if is_instance_valid(_current_targeting_ability):
			_current_targeting_ability.cancel_targeting()
			_current_targeting_ability = null
		return

	# 取消指定技能的预览
	var ability_instance = get_ability_instance(target_id)
	if is_instance_valid(ability_instance):
		ability_instance.cancel_targeting()
		if _current_targeting_ability == ability_instance:
			_current_targeting_ability = null

## 检查是否有技能正在预览
## [return] bool 是否有技能正在预览
func has_targeting_ability() -> bool:
	return is_instance_valid(_current_targeting_ability)

## 获取当前正在预览的技能实例
## [return] GameplayAbilityInstance 当前预览的技能实例，如果没有则返回 null
func get_current_targeting_ability() -> GameplayAbilityInstance:
	return _current_targeting_ability

#endregion

#region ========== 私有方法 - 事件回调 ==========
## 处理技能完成信号（由 Ability 发出）
## [param] ability: GameplayAbilityInstance 完成的技能实例
func _on_ability_completed(ability: GameplayAbilityInstance) -> void:
	if not is_instance_valid(ability):
		return
		
	# 只有当前正在执行的技能才需要结束
	if _current_casting_ability != ability:
		return

	var ability_id = ability.get_definition().ability_id

	# 检查是否是临时订阅（链式调用未学习的技能）
	# 如果是临时订阅，需要断开连接
	var is_learned = _learned_abilities.has(ability_id)
	if not is_learned:
		if ability.ability_completed.is_connected(_on_ability_completed):
			ability.ability_completed.disconnect(_on_ability_completed)

	# 结束技能
	if _current_casting_ability == ability:
		ability_completed.emit(ability)
		AbilityEventBus.trigger_game_event(&"ability_completed", {
			"entity": get_parent(),
			"ability_id": ability_id
		})
		_current_casting_ability = null
		_current_targeting_ability = null
#endregion
