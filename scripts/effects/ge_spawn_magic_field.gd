extends GameplayEffect
class_name GE_SpawnMagicField

@export_group("Magic Field Config")
@export var magic_field_data: MagicFieldData = null
@export var position_key: String = "projectile_impact"
@export var attach_to_target: bool = false
@export var target_key: String = "targets"

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	_apply_result(target, instigator, context)

func _apply_result(target: Node, instigator: Node, context: Dictionary) -> GameplayEffectResult:
	if not is_instance_valid(magic_field_data) or not is_instance_valid(magic_field_data.magic_field_scene):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	var position: Vector3 = _get_spawn_position(context)
	if not position.is_finite():
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	var supplied_parent: Variant = context.get("spawn_parent")
	var parent: Node = target if attach_to_target else (supplied_parent as Node if supplied_parent is Node else null)
	if not attach_to_target and not is_instance_valid(parent) and is_instance_valid(instigator) and instigator.is_inside_tree():
		parent = instigator.get_tree().current_scene
	if not is_instance_valid(parent):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.MISSING_DEPENDENCY)
	var node: Node = magic_field_data.magic_field_scene.instantiate()
	var field: MagicFieldBase = node as MagicFieldBase
	if not is_instance_valid(field):
		if is_instance_valid(node):
			node.free()
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	field.instigator = instigator
	magic_field_data.apply_to_magic_field(field)
	parent.add_child(field)
	if not is_instance_valid(field):
		return GameplayEffectResult.new(GameplayEffectResult.Status.UNVERIFIED, GameplayEffectResult.Reason.INVALID_TARGET)
	if attach_to_target:
		field.position = Vector3.ZERO
	elif field.is_inside_tree():
		field.global_position = position
	else:
		field.position = position
	var result: GameplayEffectResult = GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED)
	result.outputs = {"spawned_node_id": field.get_instance_id(), "position": position}
	return result

func _get_spawn_position(context: Dictionary) -> Vector3:
	var value: Variant = context.get(position_key)
	return value as Vector3 if value is Vector3 else Vector3.INF
