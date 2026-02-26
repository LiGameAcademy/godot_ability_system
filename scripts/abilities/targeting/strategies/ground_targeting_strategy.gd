extends TargetingStrategy
class_name GroundTargetingStrategy

## 地面目标策略
## 适用于：AOE技能、放置类技能、范围伤害等
##
## 策略优先级：
## 1. 如果 context 中有 target_position，使用它（通常由 hit_detector 处理）
## 2. 如果配置了 hit_detector，使用检测器获取范围内的所有目标
## 3. 否则返回空列表

func _resolve_targets(instigator: Node, _input_target: Node, context: Dictionary) -> Array[Node]:
	var targets: Array[Node] = []

	# 优先级1: 命中检测器（通常用于AOE范围检测）
	var hit_detector = context.get("hit_detector")
	if hit_detector is HitDetectorBase:
		targets = hit_detector.get_targets(instigator, context)
		if not targets.is_empty():
			return targets

	# 优先级2: 如果有目标位置但没有检测器，可能需要其他逻辑
	# 例如：放置类技能可能只需要位置，不需要目标单位
	var target_position = context.get("target_position")
	if target_position is Vector3 or target_position is Vector2:
		# 这里可以扩展：根据位置查找范围内的目标
		# 但通常应该由 hit_detector 处理
		pass

	return targets

func _get_description() -> String:
	return "Ground Target (地面位置)"
