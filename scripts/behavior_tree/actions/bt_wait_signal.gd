extends GAS_BTAction
class_name GAS_BTWaitSignal

## 基于观察者模式的等待节点
## 职责：挂起行为树，直到收到黑板变量变更通知，或超时

@export var signal_key: String = "event_input_received"
@export var timeout: float = 0.8   # < 0 表示无限等待
@export var consume_signal: bool = true # 是否消费信号

## [回调] 当黑板数据改变时，由 Instance 调用
## 这是一个"被动"的检查，比每帧主动查询更高效、响应更快
func on_blackboard_change(instance: GAS_BTInstance, key: String) -> void:
	if key == signal_key:
		# 检查值是否为 true
		if _get_var(instance, key, false):
			# 注意：我们不能在这里直接 return Status，
			# 必须修改状态变量，等待下一次 _tick 返回
			_set_signal_triggered(instance, true)

func _enter(instance: GAS_BTInstance) -> void:
	_set_signal_triggered(instance, false)
	_set_elapsed(instance, 0.0)
	
	# 1. 【核心】注册观察者
	instance.register_observer(self)
	# 进入时先检查一次（防止信号在上一帧已经触发了）
	if _get_var(instance, signal_key, false):
		_set_signal_triggered(instance, true)

func _exit(instance: GAS_BTInstance) -> void:
	instance.unregister_observer(self)

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	# A. 检查是否触发了信号 (由回调函数修改)
	if _get_signal_triggered(instance):
		# 注意：在返回 SUCCESS 之前消费信号，确保下一段能够正确接收新的信号
		if consume_signal:
			# 先重置信号触发状态，再设置变量为 false
			# 这样可以避免在退出时再次触发信号
			_set_signal_triggered(instance, false)
			_set_var(instance, signal_key, false)
		return Status.SUCCESS

	# B. 检查超时
	if timeout >= 0.0:
		_set_elapsed(instance, _get_elapsed(instance) + delta)
		if _get_elapsed(instance) >= timeout:
			return Status.FAILURE
	return Status.RUNNING

func _set_signal_triggered(instance: GAS_BTInstance, value: bool) -> void:
	var storage : Dictionary = _get_storage(instance, {})
	storage["signal_triggered"] = value
	_set_storage(instance, storage)

func _get_signal_triggered(instance: GAS_BTInstance) -> bool:
	var storage = _get_storage(instance, {})
	return storage.get("signal_triggered", false)

func _set_elapsed(instance: GAS_BTInstance, value: float) -> void:
	var storage : Dictionary = _get_storage(instance, {})
	storage["elapsed"] = value
	_set_storage(instance, storage)

func _get_elapsed(instance: GAS_BTInstance) -> float:
	var storage : Dictionary = _get_storage(instance, {})
	return storage.get("elapsed", 0.0)
