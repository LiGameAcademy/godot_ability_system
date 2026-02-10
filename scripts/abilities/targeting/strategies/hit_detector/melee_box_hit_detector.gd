extends HitDetectorBase
class_name MeleeBoxHitDetector

## 攻击盒的大小 (半宽/半高/半深)
@export var box_extents: Vector3 = Vector3(1, 1, 1)
## 攻击盒相对于角色的偏移 (比如前方 1米)
@export var offset: Vector3 = Vector3(0, 1, 1)
## 碰撞层级掩码
@export_flags_3d_physics var collision_mask: int = 1

## 是否启用调试绘制
@export var debug_draw_enabled: bool = false
## 调试框体显示时间（帧数，0 表示只显示 1 帧）
@export var debug_linger_frames: int = 30
## 攻击盒绘制颜色
@export var debug_box_color: Color = Color.YELLOW

func _get_targets(caster: Node, context: Dictionary = {}) -> Array[Node]:
	if not is_instance_valid(caster) or not (caster is Node3D):
		return [] as Array[Node]
	
	var caster_3d = caster as Node3D
	
	# 1. 构建查询参数
	var space_state = caster_3d.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()

	# 2. 创建形状
	var shape = BoxShape3D.new()
	shape.size = box_extents * 2 # BoxShape使用全长
	query.shape = shape

	# 3. 获取角色面朝方向
	var facing_dir: Vector3 = Vector3.ZERO
	if context.has("facing_direction"):
		facing_dir = (context["facing_direction"] as Vector3).normalized()
	else:
		push_warning("MeleeBoxHitDetector: facing_dir is zero!")

	# 4. 构建旋转矩阵
	var up = Vector3.UP
	var right = facing_dir.cross(up).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	up = right.cross(facing_dir).normalized()
	var rotation_basis = Basis(right, up, facing_dir)

	# 5. 计算攻击盒的位置和旋转
	var rotated_offset = rotation_basis * offset
	var box_position = caster.global_position + rotated_offset
	var box_transform = Transform3D(rotation_basis, box_position)
	query.transform = box_transform

	# 6. 配置查询参数
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [caster] # 排除施法者自己

	# 7. 执行查询
	var results = space_state.intersect_shape(query)
	var targets: Array[Node] = []
	for data in results:
		var collider = data.get("collider")
		if not is_instance_valid(collider):
			continue

		# 转换为实体根节点
		var entity = collider.get_parent()
		if is_instance_valid(entity):
			targets.append(entity)

	# 8. 调试绘制（如果启用）
	if debug_draw_enabled:
		_draw_debug_info(caster, box_transform, facing_dir, targets)

	return targets

## 绘制调试信息
func _draw_debug_info(caster: Node3D, box_transform: Transform3D, facing_dir: Vector3, targets: Array[Node]) -> void:
	if not is_instance_valid(caster):
		return

	# 1. 绘制攻击盒（使用完整的 transform）
	# 计算局部空间的 8 个顶点
	var local_corners = [
		Vector3(-box_extents.x, -box_extents.y, -box_extents.z),
		Vector3( box_extents.x, -box_extents.y, -box_extents.z),
		Vector3(-box_extents.x,  box_extents.y, -box_extents.z),
		Vector3( box_extents.x,  box_extents.y, -box_extents.z),
		Vector3(-box_extents.x, -box_extents.y,  box_extents.z),
		Vector3( box_extents.x, -box_extents.y,  box_extents.z),
		Vector3(-box_extents.x,  box_extents.y,  box_extents.z),
		Vector3( box_extents.x,  box_extents.y,  box_extents.z)
	]
	# 转换到世界空间
	var world_corners: Array[Vector3] = []
	for corner in local_corners:
		world_corners.append(box_transform * corner)
	# 计算世界空间的 AABB
	var min_pos = world_corners[0]
	var max_pos = world_corners[0]
	for corner in world_corners:
		min_pos = min_pos.min(corner)
		max_pos = max_pos.max(corner)

	var world_aabb = AABB(min_pos, max_pos - min_pos)
	#DebugDraw.draw_box_aabb(world_aabb, debug_box_color, debug_linger_frames)
