extends GAS_BTAction
class_name GAS_BTActivateAbility

## 缓存 AbilityComponent 实例的 Blackboard Key (直接缓存对象引用)
const CACHE_KEY_ABILITY_COMPONENT = "_gameplay_ability_component_ref"

## 要激活的技能 ID
@export var ability_id: StringName = &""

## [可选] GameplayAbilityComponent 所在的节点路径
## 如果为空，将尝试自动查找
@export var ability_component_path: NodePath = ^""

## [可选] 指定 Blackboard Key 来获取 GameplayAbilityComponent 的路径
## 如果设置了此 Key，且 ability_component_path 为空，将尝试从 Blackboard 读取该 Key 的值。
## 值通常是 NodePath，也可以直接是组件实例。
@export var ability_component_node_path_key: StringName = &"ability_component_path"

## [配置] 黑板变量映射到 Context (Key: Context中的Key, Value: 黑板中的Key)
## 例如: {"threat_level": "threat", "custom_param": "my_var"}
@export var context_mapping: Dictionary[String, String] = {}
## 是否等待技能执行完成
## true: 节点会保持 RUNNING 直到技能结束
## false: 技能激活成功后立即返回 SUCCESS
@export var wait_for_completion: bool = true
## 当节点退出时（包括被打断），是否强制取消技能
## 如果技能已经自然结束，此选项无效（安全）
@export var cancel_on_exit: bool = true


func _tick(instance: GAS_BTInstance, delta: float) -> int:
	var activated = _get_storage(instance)
	
	# 如果激活失败，直接返回失败
	if activated == false:
		return Status.FAILURE
		
	# 如果不等待完成，激活成功即成功
	if not wait_for_completion:
		return Status.SUCCESS
		
	# 检查技能状态
	var comp = _get_ability_component(instance)
	if not is_instance_valid(comp):
		return Status.FAILURE
		
	var ability = comp.get_ability_instance(ability_id)
	# 如果实例不存在，或者不再活跃，说明技能结束了
	if not is_instance_valid(ability) or not ability.is_active:
		return Status.SUCCESS
		
	return Status.RUNNING

func _enter(instance: GAS_BTInstance) -> void:
	var comp = _get_ability_component(instance)
	if not is_instance_valid(comp):
		push_warning("GAS_BTActivateAbility: AbilityComponent not found on agent ", instance.agent)
		_set_storage(instance, false)
		return
	# 准备上下文
	var context: Dictionary = {}
	
	# [处理 Context 映射]
	# 将黑板中的变量 (Value) 读取出来，作为 (Key) 存入 Context
	# 这包括 input_target, targets 以及其他任何自定义参数
	for context_key in context_mapping:
		var blackboard_key = context_mapping[context_key]
		
		# 只有当黑板中确实存在该 Key 时才传递
		# 避免传递 null 覆盖了技能默认值，或者产生意外的空数据
		if _has_var(instance, blackboard_key):
			var value = _get_var(instance, blackboard_key)
			context[context_key] = value
		
	# 先检查是否满足激活条件（如冷却、消耗、标签限制等）
	# 避免直接调用 try_activate_ability 可能产生的副作用或不必要的逻辑执行
	if not comp.can_activate_ability(ability_id, context):
		_set_storage(instance, false)
		return
	
	if comp.try_activate_ability(ability_id, context):
		_set_storage(instance, true)
	else:
		_set_storage(instance, false)

func _exit(instance: GAS_BTInstance) -> void:
	if cancel_on_exit:
		var comp = _get_ability_component(instance)
		if is_instance_valid(comp):
			var ability = comp.get_ability_instance(ability_id)
			# 只有当技能还在活跃时才取消
			# 如果技能自然结束，is_active 已经是 false，不会触发重复结束
			if is_instance_valid(ability) and ability.is_active:
				# 使用 cancel_ability 确保触发取消相关的逻辑
				comp.cancel_ability(ability_id)
	
	_clear_storage(instance)

func _get_ability_component(instance: GAS_BTInstance) -> GameplayAbilityComponent:
	# 1. [最高优先级] 尝试从 Blackboard 获取缓存的实例
	# 只要之前找到过一次并缓存了，就直接用，避免重复查找
	var cached_comp = instance.blackboard.get_var(CACHE_KEY_ABILITY_COMPONENT, null)
	if is_instance_valid(cached_comp) and cached_comp is GameplayAbilityComponent:
		return cached_comp

	# 2. [次优先级] 如果配置了固定的 NodePath，优先使用
	if not ability_component_path.is_empty():
		var node = instance.owner_node.get_node_or_null(ability_component_path)
		if node is GameplayAbilityComponent:
			instance.blackboard.set_var(CACHE_KEY_ABILITY_COMPONENT, node)
			return node
			
	# 3. [低优先级] 尝试从用户指定的 Blackboard Key 获取路径或实例
	# 这允许动态指定组件，在复用时NodePath不一时，有奇效
	if not ability_component_node_path_key.is_empty():
		var custom_val = instance.blackboard.get_var(ability_component_node_path_key, null)
			
		# 如果是 NodePath，则尝试获取节点
		if custom_val is NodePath and not custom_val.is_empty():
			var node = instance.owner_node.get_node_or_null(custom_val)
			if node is GameplayAbilityComponent:
				instance.blackboard.set_var(CACHE_KEY_ABILITY_COMPONENT, node)
				return node
	
	push_warning("GAS_BTActivateAbility: GameplayAbilityComponent not found on agent %s (Ability: %s)" % [instance.agent, ability_id])
	return null

func _get_node_name() -> StringName:
	return "ActivateAbility: %s" % ability_id if not ability_id.is_empty() else "ActivateAbility"
