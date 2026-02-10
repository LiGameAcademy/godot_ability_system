extends TargetingStrategy
class_name HitDetectorTargetingStrategy

## 命中检测器目标策略
## 适用于：简单的目标检测场景（普通攻击、范围技能等）
## 直接使用 HitDetectorBase 进行目标检测，提供最简单的目标获取方式

@export var hit_detector: HitDetectorBase = null  ## 命中检测器

func _resolve_targets(instigator: Node, input_target: Node, context: Dictionary) -> Array[Node]:
	var final_targets : Array[Node] = []
	# 使用配置的 hit_detector
	if is_instance_valid(hit_detector):
		var targets := hit_detector.get_targets(instigator, context)
		for target in targets:
			final_targets.append(target)
	return final_targets
