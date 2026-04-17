@abstract
extends GAS_BTNode
class_name GAS_BTDecorator

@export var child: GAS_BTNode

func reset(instance: GAS_BTInstance) -> void:
	_clear_storage(instance)
	if is_instance_valid(child):
		child.reset(instance)

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	if not is_instance_valid(child):
		return Status.FAILURE
	
	return _tick_decorator(instance, delta)

# 子类实现具体逻辑
func _tick_decorator(instance: GAS_BTInstance, delta: float) -> int:
	return child.tick(instance, delta)
