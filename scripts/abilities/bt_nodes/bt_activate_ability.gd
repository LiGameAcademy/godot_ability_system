extends GAS_BTAction
class_name GAS_BTActivateAbility

## 要激活的技能 ID
@export var ability_id: StringName = &""

## [配置] 黑板变量映射到 Context (Key: Context中的Key, Value: 黑板中的Key)
## 例如: {"threat_level": "threat", "custom_param": "my_var"}
## 默认映射: 
## - input_target: 映射到 target (单体目标)
## - targets: 映射到 targets (复数目标)
@export var context_mapping: Dictionary[String, String] = {
	"input_target": "target",
	"targets": "targets" 
}
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
	# 1. 尝试查找名为 GameplayAbilityComponent 的子节点
	var comp = instance.agent.get_node_or_null("GameplayAbilityComponent")
	if comp is GameplayAbilityComponent:
		return comp
	
	# 2. 尝试直接获取（如果 agent 本身有方法）
	if instance.agent.has_method("get_ability_component"):
		return instance.agent.get_ability_component()	
	
	# 3. 遍历查找
	for child in instance.agent.get_children():
		if child is GameplayAbilityComponent:
			return child
	
	return null

func _get_node_name() -> StringName:
	return "ActivateAbility: %s" % ability_id if not ability_id.is_empty() else "ActivateAbility"
