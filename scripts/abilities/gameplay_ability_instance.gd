extends RefCounted
class_name GameplayAbilityInstance

## 技能的运行时实例，管理执行状态

enum EndReason { COMPLETED, FAILED, CANCELLED, FORGOTTEN, OWNER_EXIT }

var _owner: Node
var _definition: GameplayAbilityDefinition
var _features: Dictionary[String, GameplayAbilityFeature] = {}
var _feature_storage: Dictionary[String, Dictionary] = {}
var _bt_instance : GAS_BTInstance = null
var _blackboard: GAS_BTBlackboard = null
var _preview_strategy: AbilityPreviewStrategy = null

# 【核心状态】技能是否正在执行（行为树是否在跑）
var is_active: bool = false
var disabled: bool = false
var _execution_id: int = 0
var _last_end_reason: int = -1
var _is_starting: bool = false
var _is_finalizing: bool = false
var _is_ticking_tree: bool = false
var _is_disposed: bool = false
var _disposal_complete: bool = false
var _forgotten_notified: bool = false
var _disposing_component: Node = null
var _has_pending_finish: bool = false
var _pending_end_status: int = GAS_BTNode.Status.SUCCESS
var _pending_end_context: Dictionary = {}

## 技能完成信号
signal ability_completed(success: bool)
## 技能数据改变
signal ability_data_changed(ability: GameplayAbilityInstance)

func _init(owner: Node, definition: GameplayAbilityDefinition, tree: GAS_BTNode = null) -> void:
	_owner = owner
	_definition = definition
	disabled = definition.disabled
	if is_instance_valid(definition.preview_strategy):
		_preview_strategy = definition.preview_strategy.duplicate(true) as AbilityPreviewStrategy
	# 初始化行为树黑板
	_blackboard = GAS_BTBlackboard.new()
	_blackboard.value_changed.connect(_on_blackboard_value_changed)
	clear_blackboard()
	var tree_to_use: GAS_BTNode = tree if is_instance_valid(tree) else definition.execution_tree
	if is_instance_valid(tree_to_use):
		_bt_instance = GAS_BTInstance.new(_owner, tree_to_use, _blackboard)
	#else:
		#push_warning("AbilityInstance: execution_tree is not valid!")

func get_definition() -> GameplayAbilityDefinition:
	return _definition

## 尝试激活技能 (由 Player/Component 调用)
func try_activate(context: Dictionary = {}) -> bool:
	if disabled or _is_disposed or _is_finalizing or _is_starting or not is_instance_valid(_bt_instance):
		return false
	context = _make_activation_context(context)
	if is_active:
		var generation: int = _execution_id
		# 如果技能已激活，无论是否允许重新激活，都应该处理连击输入
		# 触发信号，确保 GAS_BTWaitSignal 能够收到通知（用于连击系统）
		var current_value: bool = _blackboard.get_var("event_input_received", false)
		if not current_value:
			_blackboard.set_var("event_input_received", true)
		else:
			# 如果已经是 true，先设置为 false 再设置为 true，确保触发信号
			_blackboard.set_var("event_input_received", false)
			if not _is_current_execution(generation):
				return true
			_blackboard.set_var("event_input_received", true)
		if not _is_current_execution(generation):
			return true

		# 检查所有特性的 can_activate
		# 某些特性（如 ToggleFeature）可能允许在已激活时重新激活
		if not _can_activate_request(context):
			return true
		
		# 有特性允许重新激活，注入上下文数据并调用 on_activate
		if is_instance_valid(_blackboard):
			_blackboard.set_var("context", context)

		_activate_features(context, generation)
		return true

	# 1. 检查能不能放 (Cost, CD, Tags, Features)
	if not _can_activate_request(context):
		return false

	# 先占有本轮执行；初始化和收尾期间拒绝重入，避免半初始化状态被执行。
	_execution_id += 1
	is_active = true
	_is_starting = true
	if is_instance_valid(_blackboard):
		clear_blackboard() # 重置本次执行数据，保留 Feature 持久状态
		# 将 context 注入黑板，供树节点读取
		_blackboard.set_var("ability_instance", self)
		_blackboard.set_var("context", context)
		_blackboard.set_var("target", context.get("input_target"))
		# 设置标志，表示这是首次激活（开启操作）
		_blackboard.set_var("is_first_activation", true)

	_is_starting = false
	if _has_pending_finish:
		_complete_finish()
	else:
		_activate_features(context, _execution_id)
	return true

func _activate_features(context: Dictionary, generation: int) -> void:
	for feature: GameplayAbilityFeature in _features.values():
		if not _is_current_execution(generation):
			break
		if is_instance_valid(feature):
			feature.on_activate(self, context)

func _is_current_execution(generation: int) -> bool:
	return is_active and not _is_disposed and _execution_id == generation

# 每帧更新（用于需要持续更新的技能，如连击计时器、引导技能）
func update(delta: float) -> void:
	if _is_disposed or _is_finalizing or _is_starting or _is_ticking_tree:
		return
	var generation: int = _execution_id
	# 调用所有特性的 update（通用钩子，对所有技能类型有效）
	for feature: GameplayAbilityFeature in _features.values():
		if _is_disposed:
			return
		if not is_instance_valid(feature):
			continue
		feature.update(self, delta)
	# 更新行为树
	if _is_current_execution(generation) and is_instance_valid(_bt_instance):
		_is_ticking_tree = true
		var result: int = _bt_instance.tick(delta)
		_is_ticking_tree = false
		if _has_pending_finish:
			_complete_finish()
		elif _is_current_execution(generation) and result != GAS_BTNode.Status.RUNNING:
			end_ability(result)

## 结束技能
func end_ability(final_status: int = GAS_BTNode.Status.SUCCESS) -> void:
	var reason: int = EndReason.COMPLETED if final_status == GAS_BTNode.Status.SUCCESS else EndReason.FAILED
	_request_finish(final_status, reason, {})

## 取消执行。仅预览时只清理预览，不产生一次虚假的执行完成事件。
func cancel(context: Dictionary = {}) -> bool:
	if not is_active:
		cancel_targeting()
		return false
	return _request_finish(GAS_BTNode.Status.FAILURE, EndReason.CANCELLED, context)

func get_last_end_reason() -> int:
	return _last_end_reason

func is_disposed() -> bool:
	return _is_disposed

func _request_finish(status: int, reason: int, context: Dictionary) -> bool:
	if not is_active or _is_finalizing:
		return false
	is_active = false
	_is_finalizing = true
	_last_end_reason = reason
	_pending_end_status = status
	var stored_context: Variant = _blackboard.get_var("context", {})
	_pending_end_context = stored_context.duplicate(true) if stored_context is Dictionary else {}
	_pending_end_context.merge(context.duplicate(true), true)
	_pending_end_context["end_reason"] = reason
	_has_pending_finish = true
	if not _is_ticking_tree and not _is_starting:
		_complete_finish()
	return true

func _complete_finish() -> void:
	var status: int = _pending_end_status
	var context: Dictionary = _pending_end_context
	_pending_end_context = {}
	_has_pending_finish = false
	if is_instance_valid(_bt_instance):
		_bt_instance.reset_tree()
	cancel_targeting()
	var features: Array[GameplayAbilityFeature] = _features.values()
	for feature: GameplayAbilityFeature in features:
		if is_instance_valid(feature):
			if _last_end_reason in [EndReason.CANCELLED, EndReason.FORGOTTEN, EndReason.OWNER_EXIT]:
				feature.on_cancel(self, context.duplicate(true))
			feature.on_completed(self)
	_blackboard.clear()
	if _is_disposed:
		_finalize_disposal()
	_is_finalizing = false
	ability_completed.emit(status == GAS_BTNode.Status.SUCCESS)

## 遗忘和角色退出均释放实例；旧引用可以读取结束原因，不能再次激活。
func dispose(ability_comp: Node = null, reason: int = EndReason.FORGOTTEN) -> void:
	if _is_disposed:
		return
	_is_disposed = true
	_disposing_component = ability_comp
	if is_active:
		_request_finish(GAS_BTNode.Status.FAILURE, reason, {})
		if _has_pending_finish and reason == EndReason.OWNER_EXIT:
			# 角色在当前栈内释放时，组件稍后会失效；先移除学习时的被动效果。
			_notify_forgotten()
	elif not _is_finalizing:
		_finalize_disposal()
	elif reason == EndReason.OWNER_EXIT:
		_notify_forgotten()

func _notify_forgotten() -> void:
	if _forgotten_notified:
		return
	_forgotten_notified = true
	for feature: GameplayAbilityFeature in _features.values():
		if is_instance_valid(feature) and is_instance_valid(_disposing_component):
			feature.on_forgotten(self, _disposing_component)

func _finalize_disposal() -> void:
	if _disposal_complete:
		return
	_disposal_complete = true
	cancel_targeting()
	_notify_forgotten()
	if is_instance_valid(_bt_instance):
		_bt_instance.dispose()
		_bt_instance = null
	_blackboard.clear()
	if _blackboard.value_changed.is_connected(_on_blackboard_value_changed):
		_blackboard.value_changed.disconnect(_on_blackboard_value_changed)
	_feature_storage.clear()
	_features.clear()
	_preview_strategy = null
	_owner = null
	_disposing_component = null

## 检查是否可以施法
func can_activate(context: Dictionary = {}) -> bool:
	if disabled or _is_disposed or _is_finalizing or _is_starting or not is_instance_valid(_bt_instance):
		return false
	return _can_activate_request(_make_activation_context(context))

## 查询和执行都先解析输入意图，副本只用于本次请求。
func _make_activation_context(context: Dictionary) -> Dictionary:
	var request: Dictionary = context.duplicate(true)
	for feature: GameplayAbilityFeature in _features.values():
		if is_instance_valid(feature):
			request.merge(feature.get_activation_overrides(self), true)
	return request

func _can_activate_request(request: Dictionary) -> bool:
	if disabled:
		return false
	for feature: GameplayAbilityFeature in _features.values():
		if not is_instance_valid(feature):
			continue
		# 隔离旧扩展对 Dictionary 的写入，避免污染其他检查或执行输入。
		if not feature.can_activate(self, request.duplicate(true)):
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
		_feature_storage.erase(_features[feature_name].feature_name)
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
	if _is_disposed:
		return
	for feature : GameplayAbilityFeature in _features.values():
		if not is_instance_valid(feature):
			continue
		feature.on_learned(self, ability_comp)

## 处理技能遗忘事件（被动技能）
func handle_forgotten(ability_comp: Node) -> void:
	dispose(ability_comp, EndReason.FORGOTTEN)

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
	if _is_disposed:
		return
	var defaults: Dictionary = _definition.blackboard_defaults.duplicate(true)
	for key: Variant in defaults:
		if key is String or key is StringName:
			_blackboard.set_var(str(key), defaults[key])
	_blackboard.set_var("ability_instance", self)

## Feature 状态独立于行为树的每次执行数据。
func get_feature_data(feature_name: String, key: String, default: Variant = null) -> Variant:
	var storage: Dictionary = _feature_storage.get(feature_name, {})
	return storage.get(key, default)

func set_feature_data(feature_name: String, key: String, value: Variant) -> void:
	if not _feature_storage.has(feature_name):
		_feature_storage[feature_name] = {}
	var storage: Dictionary = _feature_storage[feature_name]
	if storage.has(key) and storage[key] == value:
		return
	storage[key] = value
	ability_data_changed.emit(self)

#endregion

#region ========== 瞄准/预览逻辑 (Targeting) ==========
## 检查是否配置了预览策略
func get_preview_strategy() -> AbilityPreviewStrategy:
	return _preview_strategy

func has_targeting() -> bool:
	return is_instance_valid(_preview_strategy)

## 检查是否应该智能施法
func should_smart_cast() -> bool:
	if GameplayAbilitySystem.smart_cast:
		return true
	return _definition.smart_cast

## [API] 开始预览模式
func start_targeting(extra_context: Dictionary = {}) -> void:
	if _is_disposed or _is_finalizing or not has_targeting():
		return
	_preview_strategy.begin(_owner, self, extra_context)

## [API] 更新预览 (每帧调用)
func update_targeting(delta: float, input_context: Dictionary = {}) -> void:
	if not is_targeting():
		return

	_preview_strategy.update(delta, input_context)
	
## [API] 确认预览 -> 返回 Context 数据
func confirm_targeting() -> Dictionary:
	var context: Dictionary = {}
	if has_targeting():
		# 使用策略计算最终数据
		context = _preview_strategy.get_result_context()
	return context

## [API] 取消预览
func cancel_targeting() -> void:
	if is_instance_valid(_preview_strategy):
		_preview_strategy.cancel()
		
func is_targeting() -> bool:
	if not is_instance_valid(_preview_strategy):
		return false
	return _preview_strategy.is_targeting()
#endregion

func get_current_icon() -> Texture:
	for feature: GameplayAbilityFeature in _features.values():
		if not feature.has_method("get_current_icon"):
			continue
		var icon : Texture = feature.get_current_icon(self)
		if is_instance_valid(icon):
			return icon

	# 回退到 Definition 的默认图标
	return _definition.icon

func _on_blackboard_value_changed(key: String, value: Variant) -> void:
	ability_data_changed.emit(self)
