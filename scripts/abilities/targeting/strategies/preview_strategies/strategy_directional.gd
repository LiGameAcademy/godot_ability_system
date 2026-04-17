extends GroundIndicatorPreviewStrategy
class_name StrategyDirectional

## 方向性预览策略

func _update_indicator(indicator: Node3D, caster: Node3D, mouse_position: Vector3) -> void:
	# 指示器始终在施法者脚下
	indicator.global_position = caster.global_position

	# 让指示器朝向鼠标位置
	var look_at_pos = Vector3(mouse_position.x, caster.global_position.y, mouse_position.z)
	if indicator.global_position.distance_squared_to(look_at_pos) > 0.1:
		indicator.look_at(look_at_pos, Vector3.UP)

func get_result_context() -> Dictionary:
	var direction = (_mouse_position - caster.global_position).normalized()
	direction.y = 0 # 扁平化处理

	var final_pos = _get_clamped_position(caster.global_position, _mouse_position)
	return {
		"target_position": final_pos,  # 供 TargetingStrategy 使用的位置
		"target_direction": direction,   # 供行为树使用的方向
		"target_type": "direction"
	}
