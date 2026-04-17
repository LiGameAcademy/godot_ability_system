extends GAS_BTDecorator
class_name GAS_BTInverter

## 反转节点
## 将子节点的成功或失败状态反转

func _tick_decorator(instance: GAS_BTInstance, delta: float) -> int:
	var result = child.tick(instance, delta)
	if result == Status.SUCCESS:
		return Status.FAILURE
	if result == Status.FAILURE:
		return Status.SUCCESS
	return Status.RUNNING
