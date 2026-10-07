@abstract
extends GAS_BTAction
class_name AbilityNodeBase

## [配置] 目标在黑板中的 Key
@export var target_key: String = "targets"

## 技能动作默认包含扣费、效果或表现等副作用。
func get_reevaluation_safety() -> int:
	return ReevaluationSafety.SIDE_EFFECTS

## 获取上下文（从黑板中获取 AbilityContext）
func _get_context(instance: GAS_BTInstance) -> Dictionary:
	var context : Dictionary = _get_var(instance, "context", {})
	return context

## 获取目标列表（统一化处理）
## 支持从黑板中获取单个 Node、Array[Node] 或空值
## 如果目标为空，且 use_instigator_as_fallback 为 true，则使用 instigator 作为目标（自施法）
func _get_target_list(instance: GAS_BTInstance, use_instigator_as_fallback: bool = false) -> Array[Node]:
	var context: Dictionary = _get_context(instance)
	var raw: Variant = instance.blackboard.get_var(target_key, context.get(target_key))
	var targets: Array[Node] = []
	if raw is Array:
		for item: Variant in raw:
			if item is Node and is_instance_valid(item) and not targets.has(item):
				targets.append(item as Node)
	elif raw is Node and is_instance_valid(raw):
		targets.append(raw as Node)
	var instigator_value: Variant = context.get("instigator")
	if targets.is_empty() and use_instigator_as_fallback and instigator_value is Node and is_instance_valid(instigator_value):
		targets.append(instigator_value as Node)
	return targets

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
