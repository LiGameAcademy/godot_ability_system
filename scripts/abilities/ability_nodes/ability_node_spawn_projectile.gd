extends AbilityNodeBase
class_name AbilityNodeSpawnProjectile

## 生成投射物节点
## 职责：在行为树中生成投射物，支持多重施法、散射角度等

@export_group("Projectile Config")
## 投射物数据（包含场景、速度、生命周期、穿透等配置）
@export var projectile_data: ProjectileData = null
## 发射数量（多重施法）
@export var projectile_count: int = 1
## 散射角度（度）
@export var spread_angle: float = 0.0
## 枪口挂点名（用于定位发射点）
@export var muzzle_attachment_point: StringName = &"body"

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	var context : Dictionary = _get_context(instance)
	if not context is Dictionary:
		context = {}
	var instigator = context.get("instigator")
	if not is_instance_valid(instigator):
		push_warning("AbilityNodeSpawnProjectile: Instigator is not valid!")
		return Status.FAILURE

	# 检查投射物数据
	if not is_instance_valid(projectile_data):
		push_warning("AbilityNodeSpawnProjectile: projectile_data is not set!")
		return Status.FAILURE
	# 检查投射物场景
	if not is_instance_valid(projectile_data.projectile_scene):
		push_warning("AbilityNodeSpawnProjectile: projectile_scene is not set in projectile_data!")
		return Status.FAILURE

	# 获取目标（用于追踪）
	var raw_targets = context.get("targets")
	var target_for_homing: Node3D = null
	if raw_targets is Node3D:
		target_for_homing = raw_targets as Node3D
	elif raw_targets is Array and not raw_targets.is_empty():
		var first_target = raw_targets[0]
		if first_target is Node3D:
			target_for_homing = first_target as Node3D
			
	# 确定发射基准信息
	var spawn_transform : Transform3D
	if instigator.has_method("get_attachment_point"):
		spawn_transform = instigator.get_attachment_point(muzzle_attachment_point).global_transform
	else:
		spawn_transform = instigator.global_transform

	# 计算实际发射数量（支持 Modifier 修改）
	var actual_projectile_count = projectile_count
	actual_projectile_count += context.get("extra_projectiles", 0)
	actual_projectile_count = max(1, actual_projectile_count)

	# 计算散射角度分布
	var effective_spread_angle = spread_angle
	if actual_projectile_count > 1 and spread_angle <= 0.0:
		effective_spread_angle = (actual_projectile_count - 1) * 15.0

	# 循环生成投射物
	for i in range(actual_projectile_count):
		var angle_offset: float = 0.0
		if actual_projectile_count > 1 and effective_spread_angle > 0.0:
			var half_spread = effective_spread_angle / 2.0
			if actual_projectile_count > 1:
				var t = float(i) / float(actual_projectile_count - 1)
				angle_offset = lerp(-half_spread, half_spread, t)

		var projectile = _spawn_projectile(
			instigator,
			spawn_transform,
			projectile_data.duplicate(),
			target_for_homing,
			context,
			angle_offset
		)
		
	return Status.SUCCESS

## 生成投射物
func _spawn_projectile(
		instigator: Node,
		spawn_transform: Transform3D,
		data: ProjectileData,
		target_node: Node3D,
		context: Dictionary = {},
		angle_offset: float = 0.0) -> ProjectileBase:
	if not is_instance_valid(data) or not is_instance_valid(data.projectile_scene):
		push_error("AbilityNodeSpawnProjectile: projectile_scene is not set in projectile_data")
		return null

	var projectile = data.projectile_scene.instantiate()
	if not projectile is ProjectileBase:
		push_error("AbilityNodeSpawnProjectile: projectile_scene must be a ProjectileBase")
		projectile.queue_free()
		return null

	var projectile_base = projectile as ProjectileBase
	var level_root = instigator.get_tree().current_scene
	if not is_instance_valid(level_root):
		push_error("AbilityNodeSpawnProjectile: Cannot find current scene root")
		projectile_base.queue_free()
		return null

	level_root.add_child(projectile_base)

	#projectile_base.global_transform = spawn_transform
	var spawn_position = spawn_transform.origin
	var forward_offset = -spawn_transform.basis.z * 0.5
	var up_offset = Vector3.UP * 0.5
	projectile_base.global_position = spawn_position + forward_offset + up_offset

	# 确定投射物的朝向
	var target_position : Vector3 = context.get("target_position")
	# 确保目标位置在水平面上
	var look_at_pos = Vector3(target_position.x, projectile_base.global_position.y, target_position.z)

	# 检查距离
	var direction = look_at_pos - projectile_base.global_position
	if direction.length_squared() > 0.01:
		# 使用 look_at 让投射物朝向目标
		projectile_base.look_at(look_at_pos, Vector3.UP)
		# 投射物用 -Z 作为前进方向，所以需要旋转180度
		projectile_base.rotate_object_local(Vector3.UP, PI)
	else:
		# 目标太近，使用生成方向
		projectile_base.global_transform = spawn_transform
		projectile_base.global_position = spawn_position + forward_offset + up_offset

	# 应用散射角度偏移
	if abs(angle_offset) > 0.001:
		var angle_rad = deg_to_rad(angle_offset)
		projectile_base.rotate_y(angle_rad)
	elif spread_angle > 0.0:
		var random_angle = deg_to_rad(randf_range(-spread_angle / 2.0, spread_angle / 2.0))
		projectile_base.rotate_y(random_angle)

	# 在应用数据前，替换弹头状态
	if context.has("projectile_payload_replacements"):
		var replacements = context["projectile_payload_replacements"] as Dictionary
		if not replacements.is_empty():
			_apply_payload_replacements(data, replacements)

	projectile_base.instigator = instigator
	projectile_base.target_reference = target_node
	data.apply_to_projectile(projectile_base)
	
	projectile_base.set_source_context(context)

	return projectile_base

## 应用弹头状态替换
## [param] data: ProjectileData 投射物数据（会被修改）
## [param] replacements: Dictionary 替换映射 {原状态ID: 新状态数据}
func _apply_payload_replacements(data: ProjectileData, replacements: Dictionary) -> void:
	if not is_instance_valid(data):
		return

	# 遍历当前弹头状态
	var new_payload_statuses: Dictionary[GameplayStatusData, int] = {}
	for old_status_data in data.payload_statuses:
		if not is_instance_valid(old_status_data):
			continue

		var old_status_id = old_status_data.status_id
		var stacks = data.payload_statuses[old_status_data]

		# 检查是否需要替换
		if replacements.has(old_status_id):
			var new_status_data = replacements[old_status_id] as GameplayStatusData
			if is_instance_valid(new_status_data):
				# 使用新状态替换
				new_payload_statuses[new_status_data] = stacks
				print("AbilityNodeSpawnProjectile: Replaced payload status '%s' with '%s'" % [
					old_status_id,
					new_status_data.status_id
				])
			else:
				# 新状态无效，保留原状态
				new_payload_statuses[old_status_data] = stacks
		else:
			# 不需要替换，保留原状态
			new_payload_statuses[old_status_data] = stacks

	# 更新弹头状态
	data.payload_statuses = new_payload_statuses
