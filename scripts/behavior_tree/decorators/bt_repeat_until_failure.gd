extends GAS_BTDecorator
class_name GAS_BTRepeatUntilFailure

## 完成时返回 SUCCESS 还是 FAILURE
@export var return_success: bool = true

func _tick_decorator(instance: GAS_BTInstance, delta: float) -> int:
	if not is_instance_valid(child):
		return Status.FAILURE
		
	var result = child.tick(instance, delta)
	match result:
		Status.RUNNING:
			# 子节点还在运行，继续等待
			return Status.RUNNING
		Status.SUCCESS:
			# 子节点成功，重置并继续循环
			child.reset(instance)
			# 继续下一帧执行（循环）
			return Status.RUNNING
		Status.FAILURE:
			# 子节点失败，停止循环
			child.reset(instance)
			reset(instance)
			if return_success:
				return Status.SUCCESS
			else:
				return Status.FAILURE

	return Status.FAILURE
