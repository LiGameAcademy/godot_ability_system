extends GAS_BTComposite
class_name GAS_BTSwitch

@export var variable_key: String = ""

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	if variable_key.is_empty():
		push_warning("GAS_BTSwitch: variable key is empty!")
		return Status.FAILURE
	var index = instance.blackboard.get_var(variable_key, 0)
	if index < 0 or index >= children.size():
		push_warning("GAS_BTSwitch: index 不合法！")
		return Status.FAILURE
	var previous_index: int = int(_get_storage(instance, -1))
	if previous_index >= 0 and previous_index != index:
		children[previous_index].reset(instance)
	_set_storage(instance, index)
	return children[index].tick(instance, delta)
