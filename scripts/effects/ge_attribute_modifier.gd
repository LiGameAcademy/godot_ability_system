extends GameplayEffect
class_name GE_AttributeModifier

@export var modifiers: Array[GameplayAttributeModifier] = []
## 来源ID（用于批量移除）
## 如果不设置，会从 context 中读取 source_id
## 如果 context 中也没有，则使用 "effect." + 效果资源路径
@export var source_id: StringName = &""
@export var attribute_component_name : StringName = "GameplayVitalAttributeComponent"

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	var attr_comp = GameplayAbilitySystem.get_component_by_interface(target, attribute_component_name)
	if not is_instance_valid(attr_comp):
		# 如果没有 AttributeComponent，静默失败（不是所有实体都需要属性）
		push_error("GE_AttributeModifier: attr comp is not valid!")
		return

	# 确定 source_id
	var final_source_id = context.get("source_id", "effect." + source_id)
	var stacks = context.get("stacks", 1)

	# 应用所有修改器
	for mod_template in modifiers:
		if not is_instance_valid(mod_template):
			continue
		# 创建修改器的副本（避免修改模板）
		var mod = mod_template.duplicate() as GameplayAttributeModifier
		if not is_instance_valid(mod):
			continue

		# 设置 source_id
		mod.source_id = final_source_id
		mod.value *= stacks
	
		# 应用修改器
		attr_comp.add_modifier(mod)

## 移除效果的具体实现
func _update_stacks(target: Node, instigator: Node, context: Dictionary, remove_previous: bool) -> void:
	if remove_previous:
		_remove_modifiers(target, context)
	else:
		_apply(target, instigator, context)

## 移除效果的具体实现
## 注意：Effect 保持无状态特性，通过 context 中的 source_id 来识别要移除的修改器
func _remove(target: Node, instigator: Node, context: Dictionary) -> void:
	_remove_modifiers(target, context)

## 移除修改器的核心逻辑（供 _apply 和 _remove 共用）
func _remove_modifiers(target: Node, context: Dictionary) -> void:
	var attr_comp = GameplayAbilitySystem.get_component_by_interface(target, attribute_component_name)
	if not is_instance_valid(attr_comp):
		# 如果没有 AttributeComponent，静默失败（不是所有实体都需要属性）
		push_error("GE_AttributeModifier: attr comp is not valid!")
		return
		
	# 确定 source_id
	var final_source_id = context.get("source_id", "effect." + source_id)

	# 批量移除修改器（通过 source_id）
	attr_comp.remove_modifiers_by_source(final_source_id)
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
