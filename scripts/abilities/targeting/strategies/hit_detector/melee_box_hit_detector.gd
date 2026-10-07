extends HitDetectorBase
class_name MeleeBoxHitDetector

## 攻击盒的半宽、半高、半深。
@export var box_extents: Vector3 = Vector3.ONE
@export var offset: Vector3 = Vector3(0, 1, 1)
@export_flags_3d_physics var collision_mask: int = 1
@export var debug_draw_enabled: bool = false
@export var debug_linger_frames: int = 30
@export var debug_box_color: Color = Color.YELLOW

## 表现层按需订阅，可连接到项目使用的调试绘制插件。
signal debug_box_requested(bounds: AABB, color: Color, linger_frames: int)

func _get_targets(caster: Node3D, context: Dictionary = {}) -> Array[Node]:
	var targets: Array[Node] = []
	if not is_instance_valid(caster) or not caster.is_inside_tree() or not _is_valid():
		return targets
	var direction: Variant = context.get("facing_direction", -caster.global_basis.z)
	if not direction is Vector3 or not direction.is_finite() or direction.is_zero_approx():
		push_warning("MeleeBoxHitDetector: facing_direction must be a nonzero finite Vector3")
		return targets
	var facing: Vector3 = direction.normalized()
	var up: Vector3 = Vector3.RIGHT if absf(facing.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var right: Vector3 = facing.cross(up).normalized()
	up = right.cross(facing).normalized()
	var basis: Basis = Basis(right, up, -facing)
	# 保留原有偏移含义：x 向右、y 向上、z 朝面向方向；查询使用正交旋转。
	var position: Vector3 = caster.global_position + right * offset.x + up * offset.y + facing * offset.z
	var transform: Transform3D = Transform3D(basis, position)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_extents * 2.0
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = transform
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	# Godot 4 使用 RID；普通 Node3D 没有物理 RID，另在结果中排除其子碰撞对象。
	if caster is CollisionObject3D:
		query.exclude = [caster.get_rid()]
	var space: PhysicsDirectSpaceState3D = caster.get_world_3d().direct_space_state
	var hits: Array[Dictionary] = space.intersect_shape(query)
	for hit: Dictionary in hits:
		var collider: Node = hit.get("collider") as Node
		if not is_instance_valid(collider) or collider == caster or caster.is_ancestor_of(collider):
			continue
		# 沿用检测器的实体约定：碰撞节点的父级是技能目标。
		var entity: Node = collider.get_parent()
		if is_instance_valid(entity) and entity != caster and not targets.has(entity):
			targets.append(entity)
	if debug_draw_enabled:
		var bounds: AABB = AABB(-box_extents, box_extents * 2.0)
		debug_box_requested.emit(transform * bounds, debug_box_color, debug_linger_frames)
	return targets

func _is_valid() -> bool:
	return box_extents.is_finite() and offset.is_finite() and box_extents.x > 0.0 and box_extents.y > 0.0 and box_extents.z > 0.0
