extends GameplayEffectApplication
class_name AttributeModifierApplication

var _component: WeakRef = null
var _templates: Array[GameplayAttributeModifier] = []
var _modifiers: Array[GameplayAttributeModifier] = []
var _initialized: bool = false

func initialize(component: GameplayAttributeComponent, templates: Array[GameplayAttributeModifier], stacks: int) -> void:
	if _initialized or is_revoked() or not is_instance_valid(component):
		return
	_initialized = true
	_component = weakref(component)
	for template: GameplayAttributeModifier in templates:
		_templates.append(template.duplicate() as GameplayAttributeModifier)
	set_stacks(stacks)

func get_modifier_count() -> int:
	return _modifiers.size()

func _get_component() -> GameplayAttributeComponent:
	return _component.get_ref() as GameplayAttributeComponent if is_instance_valid(_component) else null

func _revoke() -> void:
	_clear_modifiers()
	_templates.clear()
	_component = null

func _set_stacks(stacks: int) -> void:
	for template: GameplayAttributeModifier in _templates:
		if not is_finite(template.value * stacks):
			return
	_clear_modifiers()
	for template: GameplayAttributeModifier in _templates.duplicate():
		var component: GameplayAttributeComponent = _get_component()
		if is_revoked() or not is_instance_valid(component) or not component.has_attribute(template.attribute_id):
			break
		var modifier: GameplayAttributeModifier = template.duplicate() as GameplayAttributeModifier
		modifier.source_id = application_id
		modifier.value *= stacks
		# 回调可能撤销当前应用；先登记所有权，再通知组件。
		_modifiers.append(modifier)
		component.add_modifier(modifier)

func _clear_modifiers() -> void:
	var previous: Array[GameplayAttributeModifier] = _modifiers.duplicate()
	_modifiers.clear()
	for modifier: GameplayAttributeModifier in previous:
		var component: GameplayAttributeComponent = _get_component()
		if not is_instance_valid(component):
			break
		var attribute: GameplayAttributeInstance = component.get_attribute(modifier.attribute_id)
		# 其他代码可能已经移除本项，不重复发出修改通知。
		if is_instance_valid(attribute) and attribute.get_modifers().has(modifier):
			component.remove_modifier(modifier)
