extends GameplayEffect
class_name GE_AttributeModifier

@export var modifiers: Array[GameplayAttributeModifier] = []
## 配置标识，用于查询；每次应用使用独立 application_id。
@export var source_id: StringName = &""
@export var attribute_component_name: StringName = &"GameplayVitalAttributeComponent"

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	_apply_result(target, instigator, context)

func _apply_result(target: Node, _instigator: Node, context: Dictionary) -> GameplayEffectResult:
	var component: GameplayAttributeComponent = GameplayAbilitySystem.get_component_by_interface(target, attribute_component_name) as GameplayAttributeComponent
	if not is_instance_valid(component):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.MISSING_DEPENDENCY)
	var stacks: Variant = context.get("stacks", 1)
	var source: Variant = context.get("source_id", &"")
	if not stacks is int or stacks < 1 or not (source is String or source is StringName):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	for modifier: GameplayAttributeModifier in modifiers:
		if not is_instance_valid(modifier) or not is_finite(modifier.value) or not is_finite(modifier.value * int(stacks)):
			return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
		if modifier.modifier_type not in GameplayAttributeModifier.ModifierType.values():
			return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
		if not component.has_attribute(modifier.attribute_id):
			return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.MISSING_DEPENDENCY)
	var application: AttributeModifierApplication = AttributeModifierApplication.new()
	application.config_id = source_id
	application.source_group = StringName(source)
	application.initialize(component, modifiers, int(stacks))
	var count: int = application.get_modifier_count()
	var result: GameplayEffectResult = GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED if count > 0 else GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.NONE if count > 0 else GameplayEffectResult.Reason.NO_CHANGE)
	if not is_instance_valid(component):
		result.status = GameplayEffectResult.Status.PARTIAL if count > 0 else GameplayEffectResult.Status.FAILED
		result.reason = GameplayEffectResult.Reason.INVALID_TARGET
	if count > 0:
		result.application = application
	result.outputs = {"modifier_count": count}
	return result

func _update_stacks(_target: Node, _instigator: Node, context: Dictionary, remove_previous: bool) -> void:
	if not remove_previous:
		var application: Variant = context.get("application")
		var stacks: Variant = context.get("stacks", 1)
		if application is GameplayEffectApplication and stacks is int:
			(application as GameplayEffectApplication).set_stacks(int(stacks))

func _remove(_target: Node, _instigator: Node, _context: Dictionary) -> void:
	push_warning("GE_AttributeModifier: remove requires the returned application handle; use result.application.revoke()")
