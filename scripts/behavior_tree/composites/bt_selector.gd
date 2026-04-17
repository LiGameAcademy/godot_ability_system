extends GAS_BTComposite
class_name GAS_BTSelector

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	var current_index = _get_storage(instance, 0)
	for i in range(current_index, children.size()):
		var child = children[i]
		var result = child.tick(instance, delta)

		if result == Status.RUNNING:
			_set_storage(instance, i)
			return Status.RUNNING

		if result == Status.SUCCESS:
			reset(instance)
			return Status.SUCCESS

	reset(instance)
	return Status.FAILURE
