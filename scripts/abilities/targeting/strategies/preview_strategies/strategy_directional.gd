extends GroundIndicatorPreviewStrategy
class_name StrategyDirectional

## 方向性预览策略

func _update_indicator(indicator: Node3D, origin_position: Vector3, mouse_position: Vector3) -> void:
	# 指示器始终在施法者脚下
	indicator.global_position = origin_position

	# 让指示器朝向鼠标位置
	var look_at_pos: Vector3 = Vector3(mouse_position.x, origin_position.y, mouse_position.z)
	if indicator.global_position.distance_squared_to(look_at_pos) > 0.1:
		indicator.look_at(look_at_pos, Vector3.UP)

func get_result_context() -> Dictionary:
	if not _is_session_valid():
		cancel()
		return {}
	if _finished:
		return super.get_result_context()
	var origin_position: Vector3 = _get_origin_position()
	var direction: Vector3 = (_mouse_position - origin_position).normalized()
	direction.y = 0 # 扁平化处理

	var final_pos: Vector3 = _get_clamped_position(origin_position, _mouse_position)
	return {
		"target_position": final_pos,  # 供 TargetingStrategy 使用的位置
		"target_direction": direction,   # 供行为树使用的方向
		"target_type": "direction"
	}
