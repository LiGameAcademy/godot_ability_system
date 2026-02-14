extends AreaHitDetectorBase
class_name AreaHitDetector3D

## 区域命中检测器（物理检测）
## 适用于：AOE技能、非指向性技能、地雷、暴风雪
## 特点：精确、支持复杂形状、依赖物理引擎

@export_group("Area Settings")
# detection_radius 在基类定义
@export var detection_shape: Shape3D = null:
	set(value):
		detection_shape = value
		notify_property_list_changed()
@export_flags_3d_physics 
var collision_mask: int = 0 | 4  ## 碰撞遮罩
# detection_position_source 在基类定义

@export_group("Query Settings")
@export var use_world_position: bool = true  ## 是否使用世界坐标
# max_results, exclude_caster 在基类定义

func _get_targets(caster: Node, context: Dictionary = {}) -> Array[Node]:
	if not is_instance_valid(caster) or not (caster is Node3D):
		return []
	
	var caster_3d = caster as Node3D

	# 确定检测位置（根据配置项决定，允许 context 覆盖）
	var position_source = context.get("detection_position_source", detection_position_source)
	var detection_position: Vector3 = Vector3.ZERO

	match position_source:
		DetectionPositionSource.CASTER_POSITION:
			# 使用施法者位置（适用于献祭等范围技能）
			detection_position = caster_3d.global_position
		DetectionPositionSource.TARGET_POSITION:
			if context.has("target_position") and context["target_position"] is Vector3:
				detection_position = context["target_position"] as Vector3
			else:
				push_warning("AreaHitDetector3D: TARGET_POSITION source selected but target_position not found in context")
				detection_position = Vector3.ZERO
		DetectionPositionSource.HIT_POSITION:
			# 使用命中位置（投射物爆炸位置）
			if context.has("hit_position") and context["hit_position"] is Vector3:
				detection_position = context["hit_position"] as Vector3
			else:
				push_warning("AreaHitDetector3D: HIT_POSITION source selected but hit_position not found in context")
				detection_position = Vector3.ZERO
		DetectionPositionSource.DETECTION_POSITION:
			# 使用显式指定的检测位置（通过 context["detection_position"] 传递）
			if context.has("detection_position") and context["detection_position"] is Vector3:
				detection_position = context["detection_position"] as Vector3
			else:
				push_warning("AreaHitDetector3D: DETECTION_POSITION source selected but detection_position not found in context")
				detection_position = Vector3.ZERO
		_:
			push_warning("AreaHitDetector3D: Unknown detection_position_source: %d" % position_source)
			detection_position = Vector3.ZERO

	# 调试信息
	if detection_position == Vector3.ZERO:
		print("AreaHitDetector3D: WARNING - Using Vector3.ZERO as detection position! Source: %d" % position_source)
	else:
		print("AreaHitDetector3D: Using detection position: %s (Source: %d)" % [detection_position, position_source])

	# 确定检测半径（允许上下文覆盖）
	var radius = context.get("detection_radius", detection_radius)
	# 确定碰撞遮罩（允许上下文覆盖）
	var mask = context.get("collision_mask", collision_mask)

	# 使用PhysicsServer3D进行同步查询（避免异步问题）
	var space_state = caster.get_world_3d().direct_space_state
	# 创建查询参数
	var query = PhysicsShapeQueryParameters3D.new()
	# 设置形状
	var shape: Shape3D
	if detection_shape:
		shape = detection_shape
		shape.radius = radius
	else:
		shape = SphereShape3D.new()
		shape.radius = radius

	query.shape = shape
	query.transform = Transform3D(Basis(), detection_position)
	query.collision_mask = mask
	query.collide_with_bodies = true  # 检测刚体（CharacterBody3D, RigidBody3D等）
	query.collide_with_areas = true   # 检测区域（Area3D，如Hurtbox）

	# 是否排除施法者（允许上下文覆盖）
	var should_exclude_caster = context.get("exclude_caster", exclude_caster)
	if should_exclude_caster:
		query.exclude = [caster]  # 排除施法者自己
	else:
		query.exclude = []  # 不排除，允许检测到施法者
		
	# 执行查询
	var results = space_state.intersect_shape(query, max_results)

	# 调试信息
	if results.is_empty():
		print("AreaHitDetector3D: No results found. Position: %s, Radius: %.2f, Mask: %d, CollideWithBodies: %s, CollideWithAreas: %s" % [
			detection_position, radius, mask, query.collide_with_bodies, query.collide_with_areas
		])
	else:
		print("AreaHitDetector3D: Found %d results" % results.size())
	
	# 转换结果为实体列表
	var valid_targets: Array[Node] = []
	var processed_entities = {}  # 避免重复
	for result in results:
		var collider = result.get("collider")
		if not is_instance_valid(collider):
			continue
			
		# 调试信息：打印检测到的碰撞体
		print("AreaHitDetector3D: Found collider: %s (type: %s)" % [collider.name, collider.get_class()])

		var entity = collider.get_parent()
		if not is_instance_valid(entity):
			print("AreaHitDetector3D: Failed to get entity from collider: %s" % collider.name)
			continue

		# 避免重复添加同一实体
		var entity_id = entity.get_instance_id()
		if processed_entities.has(entity_id):
			continue

		processed_entities[entity_id] = true
		valid_targets.append(entity)
		print("AreaHitDetector3D: Added target: %s" % entity.name)
		
	return valid_targets

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	if not is_instance_valid(detection_shape):
		properties.append({
			"name": "detection_radius",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.1, 1000.0, 0.1"
		})
	return properties

func _get_description() -> String:
	var shape_name = "Sphere" if not detection_shape else detection_shape.get_class()
	return "Area Detector: %s (Radius %.1f, Mask %d, Position: %s)" % [shape_name, detection_radius, collision_mask, _get_source_name()]
