extends GAS_BTAction
class_name GAS_BTWait

## 等待时间（秒）
@export var duration: float = 1.0
## 从黑板读取等待时间的 Key（可选，如果设置则优先使用）
@export var duration_key: String = ""

func _enter(instance: GAS_BTInstance):
	# 获取实际的等待时间（优先从黑板读取）
	var actual_duration = _get_actual_duration(instance)
	var end_time = Time.get_ticks_msec() / 1000.0 + actual_duration
	_set_storage(instance, end_time)

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time >= _get_storage(instance):
		return Status.SUCCESS
	return Status.RUNNING

func _get_actual_duration(instance: GAS_BTInstance) -> float:
	# 如果设置了 duration_key，优先从黑板读取
	if not duration_key.is_empty():
		var blackboard_duration = _get_var(instance, duration_key)
		if blackboard_duration != null and blackboard_duration is float:
			return blackboard_duration as float
	return duration
