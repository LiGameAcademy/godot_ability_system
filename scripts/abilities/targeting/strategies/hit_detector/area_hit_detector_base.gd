@abstract
extends HitDetectorBase
class_name AreaHitDetectorBase

## 区域命中检测器基类（2D/3D 通用）
## 提取了 AreaHitDetector 和 AreaHitDetector2D 的公共逻辑

## 检测位置来源
enum DetectionPositionSource {
	CASTER_POSITION,      ## 使用施法者位置（默认，适用于献祭等范围技能）
	TARGET_POSITION,      ## 使用目标位置（鼠标位置，适用于地面目标技能）
	HIT_POSITION,         ## 使用命中位置（投射物爆炸位置）
	DETECTION_POSITION    ## 使用显式指定的检测位置（通过 context["detection_position"] 传递）
}

@export_group("Area Settings")
var detection_radius: float = 3.0  ## 检测半径（3D单位：米，2D单位：像素）
@export var detection_position_source: DetectionPositionSource = DetectionPositionSource.CASTER_POSITION  ## 检测位置来源

@export_group("Query Settings")
@export var max_results: int = 32  ## 最大检测结果数量
@export var exclude_caster: bool = true  ## 是否排除施法者自己（false 时，施法者也会被检测到，适用于治疗光环、群体Buff等）

## [子类重写] 检测目标的具体实现
@abstract func _get_targets(caster: Node, context: Dictionary) -> Array[Node]

## [辅助] 获取位置来源的描述名称
func _get_source_name() -> String:
	var source_names = {
		DetectionPositionSource.CASTER_POSITION: "Caster",
		DetectionPositionSource.TARGET_POSITION: "Target",
		DetectionPositionSource.HIT_POSITION: "Hit",
		DetectionPositionSource.DETECTION_POSITION: "Explicit"
	}
	return source_names.get(detection_position_source, "Unknown")

func _get_description() -> String:
	return "Area Detector (Radius: %.1f, Source: %s)" % [detection_radius, _get_source_name()]
