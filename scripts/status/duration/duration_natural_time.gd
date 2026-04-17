extends StatusDurationPolicy
class_name DurationNaturalTime

## 自然时间策略
## 状态持续时间按自然时间流逝（秒）

func _update(instance: GameplayStatusInstance, delta: float) -> bool:
	var remaining = _get_remaining_duration(instance)
	if remaining > 0:
		remaining -= delta
		_set_remaining_duration(instance, remaining)
		if remaining <= 0:
			return true
	return false

func _refresh(instance: GameplayStatusInstance, duration: float) -> void:
	var remaining = duration if duration > 0 else -1.0
	_set_remaining_duration(instance, remaining)

func _accumulate(instance: GameplayStatusInstance, duration: float) -> void:
	var remaining = _get_remaining_duration(instance)
	if remaining < 0:
		remaining = duration if duration > 0 else -1.0
	else:
		remaining += duration
	_set_remaining_duration(instance, remaining)
