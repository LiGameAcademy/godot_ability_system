extends GroundIndicatorPreviewStrategy
class_name StrategyCircleArea

## 圆形区域预览策略
## 适用于：需要选择一个圆形区域作为目标的技能（如：火球术、治疗术等）

func _update_indicator(indicator: Node3D, origin_position: Vector3, mouse_position: Vector3) -> void:
	# 限制指示器在最大射程内
	var final_pos: Vector3 = _get_clamped_position(origin_position, mouse_position)
	indicator.global_position = final_pos

	# 如果是指向性贴花，可能需要调整 Y 轴适应地形（这里简化处理）
