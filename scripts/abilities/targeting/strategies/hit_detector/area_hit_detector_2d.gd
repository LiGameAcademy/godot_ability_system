extends AreaHitDetectorBase
class_name AreaHitDetector2D

## 2D 区域命中检测器（物理检测）
## 适用于：AOE技能、非指向性技能、地雷、暴风雪（2D版）
## 特点：精确、支持复杂形状、依赖物理引擎

@export_group("Area Settings")
# detection_radius 在基类定义
@export var detection_shape: Shape2D = null:
	set(value):
		detection_shape = value
		notify_property_list_changed()
@export_flags_2d_physics 
var collision_mask: int = 0 ## 碰撞遮罩
# detection_position_source 在基类定义

@export_group("Query Settings")
# max_results 在基类定义
@export var use_global_position: bool = true  ## 是否使用全局坐标
# exclude_caster 在基类定义

func _get_targets(caster: Node, context: Dictionary = {}) -> Array[Node]:
	if not is_instance_valid(caster) or not (caster is Node2D):
		return []
	
	var caster_2d = caster as Node2D

	# 确定检测位置（根据配置项决定，允许 context 覆盖）
	var position_source = context.get("detection_position_source", detection_position_source)
	var detection_position: Vector2 = Vector2.ZERO

	match position_source:
		DetectionPositionSource.CASTER_POSITION:
			# 使用施法者位置
			detection_position = caster_2d.global_position
		DetectionPositionSource.TARGET_POSITION:
			if context.has("target_position") and context["target_position"] is Vector2:
				detection_position = context["target_position"] as Vector2
			else:
				push_warning("AreaHitDetector2D: TARGET_POSITION source selected but target_position not found in context or invalid")
				detection_position = Vector2.ZERO
		DetectionPositionSource.HIT_POSITION:
			# 使用命中位置
			if context.has("hit_position") and context["hit_position"] is Vector2:
				detection_position = context["hit_position"] as Vector2
			else:
				push_warning("AreaHitDetector2D: HIT_POSITION source selected but hit_position not found in context")
				detection_position = Vector2.ZERO
		DetectionPositionSource.DETECTION_POSITION:
			# 使用显式指定的检测位置
			if context.has("detection_position") and context["detection_position"] is Vector2:
				detection_position = context["detection_position"] as Vector2
			else:
				detection_position = Vector2.ZERO
	
	var offset: Vector2 = context.get(offset_key, Vector2.ZERO)
	detection_position += offset

	# 执行物理查询
	var space_state = caster_2d.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	
	query.collide_with_areas = include_areas
	query.collide_with_bodies = include_bodies
	query.collision_mask = collision_mask
	
	if is_instance_valid(detection_shape):
		query.shape = detection_shape
	else:
		# 默认使用圆形
		var circle = CircleShape2D.new()
		circle.radius = detection_radius
		query.shape = circle
	
	# 设置查询位置
	var transform = Transform2D(0, detection_position)
	query.transform = transform
	
	# 如果排除施法者，排除其 RID
	if exclude_caster:
		var rid = caster_2d.get_rid()
		if rid.is_valid():
			query.exclude = [rid]

	var results = space_state.intersect_shape(query, max_results)
	var targets: Array[Node] = []
	
	for result in results:
		var collider = result.get("collider")
		if is_instance_valid(collider):
			# 尝试获取实体根节点（假设 collider 是 Area2D 或 Body，可能挂载在 Entity 上）
			# 这里假设 collider 本身或者其父节点是我们需要的目标
			# 根据具体项目结构，可能需要向上查找 owner
			targets.append(collider)
			
	return targets

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
	return "Area Hit Detector 2D (Radius: %.1f, Mask: %d, Source: %s)" % [detection_radius, collision_mask, _get_source_name()]
