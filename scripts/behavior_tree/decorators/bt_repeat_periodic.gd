extends GAS_BTDecorator
class_name GAS_BTRepeatPeriodic

@export_group("Periodic Settings")
## 周期时间（秒）
@export var period: float = 1.0
## 从黑板读取周期时间的 Key（可选）
@export var period_key: String = ""
## 是否在首次进入时立即执行一次
@export var execute_immediately: bool = true
## 当子节点返回 FAILURE 时，此节点返回什么状态
@export var return_success_on_failure: bool = true

func _tick_decorator(instance: GAS_BTInstance, delta: float) -> int:
	if not is_instance_valid(child):
		return Status.FAILURE
	
	# 获取实际的周期时间（优先从黑板读取）
	var actual_period = _get_actual_period(instance)
	
	# 获取运行时状态
	var state = _get_state(instance)

	# 如果正在等待周期时间，更新计时器
	if state.is_waiting_for_period:
		state.elapsed += delta
		if state.elapsed >= actual_period:
			# 周期时间到达，重置计时器，准备执行子节点
			state.elapsed -= actual_period
			state.is_waiting_for_period = false
			_set_state(instance, state)  # 保存状态
			child.reset(instance)  # 重置子节点，准备下一轮执行
		else:
			# 还在等待周期时间，保存状态并返回
			_set_state(instance, state)
			return Status.RUNNING

	# 检查是否应该立即执行（首次执行）
	if not state.has_executed_first and execute_immediately:
		state.has_executed_first = true
		_set_state(instance, state)  # 保存状态

	# 执行子节点
	var result = child.tick(instance, delta)

	# 处理子节点的执行结果
	match result:
		Status.RUNNING:
			# 子节点还在运行，继续等待
			return Status.RUNNING
	
		Status.SUCCESS:
			# 子节点执行成功，重置子节点，开始计时
			child.reset(instance)
			state.is_waiting_for_period = true
			state.elapsed = 0.0
			_set_state(instance, state)  # 保存状态
			# 继续运行，等待周期时间
			return Status.RUNNING
		Status.FAILURE:
			# 子节点执行失败（如消耗不足），停止重复
			child.reset(instance)
			# 根据配置返回成功或失败
			if return_success_on_failure:
				return Status.SUCCESS
			else:
				return Status.FAILURE
	return Status.RUNNING

func _enter(instance: GAS_BTInstance) -> void:
	# 初始化运行时状态
	var state = {
		"elapsed": 0.0,
		"is_waiting_for_period": false,
		"has_executed_first": execute_immediately  # 如果立即执行，标记为已执行
	}
	_set_state(instance, state)

func _exit(instance: GAS_BTInstance) -> void:
	# 清理运行时状态（由父类自动清理，这里可以显式清理）
	_clear_storage(instance)

## 获取运行时状态（状态存储在 GAS_BTInstance 中）
func _get_state(instance: GAS_BTInstance) -> Dictionary:
	return _get_storage(instance, {
		"elapsed": 0.0,
		"is_waiting_for_period": false,
		"has_executed_first": false
	})

## 设置运行时状态
func _set_state(instance: GAS_BTInstance, state: Dictionary) -> void:
	_set_storage(instance, state)

## 获取实际的周期时间（优先从黑板读取）
## [param] instance: GAS_BTInstance 行为树实例
## [return] float 周期时间（秒）
func _get_actual_period(instance: GAS_BTInstance) -> float:
	# 如果设置了 period_key，优先从黑板读取
	if not period_key.is_empty():
		var blackboard_period = instance.blackboard.get_var(period_key)
		if blackboard_period != null and blackboard_period is float:
			return blackboard_period as float
	# 否则使用配置的 period
	return period
