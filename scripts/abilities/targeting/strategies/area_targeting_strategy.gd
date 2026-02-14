extends TargetingStrategy
class_name AreaTargetingStrategy

## 范围目标策略
## 适用于：AOE技能、范围伤害、区域效果
## 使用 AreaHitDetectorBase 检测范围内的所有目标

@export var hit_detector: AreaHitDetectorBase = null  ## 区域命中检测器

func _resolve_targets(instigator: Node, input_target: Node, context: Dictionary) -> Array[Node]:
	# 如果配置了 hit_detector，使用它
	if is_instance_valid(hit_detector):
		# 将 hit_detector 传递到 context 中
		context["hit_detector"] = hit_detector
		return hit_detector.get_targets(instigator, context)

	# 如果没有配置 hit_detector，尝试从 context 中获取
	var detector = context.get("hit_detector")
	if detector is AreaHitDetectorBase:
		return detector.get_targets(instigator, context)

	return []

func _get_description() -> String:
	if is_instance_valid(hit_detector):
		return "Area Target (Detector: %s)" % hit_detector.get_description()
	return "Area Target (未配置检测器)"
