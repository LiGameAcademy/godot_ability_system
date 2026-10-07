extends GameplayEffect
class_name GE_AttributeModifier

@export var modifiers: Array[GameplayAttributeModifier] = []
## 保留旧的批量来源语义；独立应用句柄在 #36 迁移。
@export var source_id: StringName = &""
@export var attribute_component_name: StringName = &"GameplayVitalAttributeComponent"

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	_apply_result(target, instigator, context)

func _apply_result(target: Node, _instigator: Node, context: Dictionary) -> GameplayEffectResult:
	var component: GameplayAttributeComponent = GameplayAbilitySystem.get_component_by_interface(target, attribute_component_name) as GameplayAttributeComponent
	if not is_instance_valid(component):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.MISSING_DEPENDENCY)
	var stacks: Variant = context.get("stacks", 1)
	var source: Variant = context.get("source_id", "effect." + String(source_id))
	if not stacks is int or stacks < 1 or not (source is String or source is StringName):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	for modifier: GameplayAttributeModifier in modifiers:
		if not is_instance_valid(modifier) or not is_finite(modifier.value) or not is_finite(modifier.value * int(stacks)):
			return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
		if modifier.modifier_type not in GameplayAttributeModifier.ModifierType.values():
			return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
		if not component.has_attribute(modifier.attribute_id):
			return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.MISSING_DEPENDENCY)
	var count: int = 0
	for template: GameplayAttributeModifier in modifiers:
		if not is_instance_valid(component):
			var interrupted: GameplayEffectResult = GameplayEffectResult.new(GameplayEffectResult.Status.PARTIAL if count > 0 else GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_TARGET)
			interrupted.outputs = {"modifier_count": count}
			return interrupted
		var modifier: GameplayAttributeModifier = template.duplicate() as GameplayAttributeModifier
		modifier.source_id = StringName(source)
		modifier.value *= int(stacks)
		component.add_modifier(modifier)
		count += 1
	var result: GameplayEffectResult = GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED if count > 0 else GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.NONE if count > 0 else GameplayEffectResult.Reason.NO_CHANGE)
	result.outputs = {"modifier_count": count}
	return result

func _update_stacks(target: Node, instigator: Node, context: Dictionary, remove_previous: bool) -> void:
	if remove_previous:
		_remove_modifiers(target, context)
	else:
		_apply_result(target, instigator, context)

func _remove(target: Node, _instigator: Node, context: Dictionary) -> void:
	_remove_modifiers(target, context)

func _remove_modifiers(target: Node, context: Dictionary) -> void:
	var component: GameplayAttributeComponent = GameplayAbilitySystem.get_component_by_interface(target, attribute_component_name) as GameplayAttributeComponent
	var source: Variant = context.get("source_id", "effect." + String(source_id))
	if is_instance_valid(component) and (source is String or source is StringName):
		component.remove_modifiers_by_source(StringName(source))
