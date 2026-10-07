extends GameplayEffect
class_name GE_SingleFrameMotion

enum DirectionType { FORWARD, INPUT, MOUSE, CUSTOM }
@export var direction_type: DirectionType = DirectionType.FORWARD
## 单次位移距离；周期效果的总距离还取决于调用次数。
@export var distance: float = 0.3
@export var ignore_gravity: bool = false

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	_apply_result(target, instigator, context)

func _apply_result(target: Node, _instigator: Node, context: Dictionary) -> GameplayEffectResult:
	var body: CharacterBody3D = target as CharacterBody3D
	if not is_instance_valid(body):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.MISSING_DEPENDENCY)
	if not body.is_inside_tree():
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_TARGET)
	if not is_finite(distance) or distance < 0.0:
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	if direction_type == DirectionType.INPUT and (TagManager.has_tag(body, &"state.rooted") or TagManager.has_tag(body, &"state.stunned")):
		return GameplayEffectResult.new(GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.IMMUNE)
	var direction: Vector3 = _resolve_direction(body, context)
	if not direction.is_finite() or direction == Vector3.ZERO:
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	var motion: Vector3 = direction * distance
	if not ignore_gravity and not body.is_on_floor():
		motion.y -= 0.5
	var previous: Vector3 = body.position
	var collision: KinematicCollision3D = body.move_and_collide(motion)
	if is_instance_valid(collision):
		var slide: Vector3 = collision.get_remainder().slide(collision.get_normal())
		if slide.length() > 0.001:
			body.move_and_collide(slide)
	if not is_instance_valid(body):
		return GameplayEffectResult.new(GameplayEffectResult.Status.UNVERIFIED, GameplayEffectResult.Reason.INVALID_TARGET)
	var delta: Vector3 = body.position - previous
	var result: GameplayEffectResult = GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED if delta != Vector3.ZERO else GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.NONE if delta != Vector3.ZERO else GameplayEffectResult.Reason.NO_CHANGE)
	result.outputs = {"delta": delta}
	return result

func _resolve_direction(body: Node3D, context: Dictionary) -> Vector3:
	var direction: Vector3 = Vector3.ZERO
	match direction_type:
		DirectionType.FORWARD:
			direction = _get_facing_direction(body, context)
		DirectionType.INPUT:
			var input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if input.length() > 0.1:
				var camera: Camera3D = body.get_viewport().get_camera_3d()
				if is_instance_valid(camera):
					var basis: Basis = camera.global_transform.basis
					direction = basis.x * input.x + basis.z * input.y
				else:
					direction = Vector3(input.x, 0.0, -input.y)
			else:
				direction = _get_facing_direction(body, context)
		DirectionType.MOUSE:
			var mouse: Variant = context.get("mouse_direction")
			direction = mouse as Vector3 if mouse is Vector3 else _get_facing_direction(body, context)
		DirectionType.CUSTOM:
			var custom: Variant = context.get("direction")
			direction = custom as Vector3 if custom is Vector3 else Vector3.ZERO
	direction.y = 0.0
	return direction.normalized()

func _get_facing_direction(body: Node3D, context: Dictionary) -> Vector3:
	var angle: Variant = context.get("facing_angle")
	if angle is float or angle is int:
		return Basis.from_euler(Vector3(0.0, float(angle), 0.0)) * Vector3.FORWARD
	return body.global_transform.basis.z.normalized()
