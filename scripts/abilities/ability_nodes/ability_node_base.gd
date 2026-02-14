@abstract
extends GAS_BTAction
class_name AbilityNodeBase

## [配置] 目标在黑板中的 Key
@export var target_key: String = "targets"

## [配置] 目标获取策略（可选）
## 如果设置，将优先使用策略获取目标，忽略 target_key
@export var target_strategy: BTValueStrategy

## 获取上下文（从黑板中获取 AbilityContext）
func _get_context(instance: GAS_BTInstance) -> Dictionary:
	var context : Dictionary = _get_var(instance, "context", {})
	return context

## 获取目标列表（统一化处理）
## 支持从黑板中获取单个 Node、Array[Node] 或空值
## 如果目标为空，且 use_instigator_as_fallback 为 true，则使用 instigator 作为目标（自施法）
func _get_target_list(instance: GAS_BTInstance, use_instigator_as_fallback: bool = false) -> Array[Node]:
	var context = _get_context(instance)
	var raw_targets = null

	# 1. 优先使用策略获取
	if is_instance_valid(target_strategy):
		raw_targets = target_strategy.get_value(context, instance.blackboard)
	else:
		# 2. 回退到使用 target_key 从黑板获取
		raw_targets = instance.blackboard.get_var(target_key)
	
	var target_list: Array[Node] = []
	# 处理空值或空数组
	if raw_targets == null or (raw_targets is Array and raw_targets.is_empty()):
		if use_instigator_as_fallback and is_instance_valid(context.get("instigator")):
			target_list.append(context.instigator)
		return target_list

	# 处理数组
	if raw_targets is Array:
		for item in raw_targets:
			if item is Node and is_instance_valid(item):
				target_list.append(item as Node)
		return target_list

	# 处理单个节点
	if raw_targets is Node and is_instance_valid(raw_targets):
		target_list.append(raw_targets as Node)
		return target_list

	if use_instigator_as_fallback and is_instance_valid(context.get("instigator")):
		target_list.append(context.instigator)

	return target_list

## 获取第一个目标（用于只需要单个目标的场景）
func _get_first_target(instance: GAS_BTInstance, use_instigator_as_fallback: bool = false) -> Node:
	var target_list = _get_target_list(instance, use_instigator_as_fallback)
	if target_list.is_empty():
		return null
	return target_list[0]

## 验证上下文是否有效
## [param] instance: GAS_BTInstance 行为树实例
## [param] node_name: String 节点名称（用于错误提示）
## [return] bool 上下文是否有效
func _validate_context(instance: GAS_BTInstance, node_name: String = "") -> bool:
	var context = _get_context(instance)
	if context.is_empty():
		var name_str = node_name if not node_name.is_empty() else get_script().get_path().get_file()
		push_warning("%s: Context is empty!" % name_str)
		return false
	return true
