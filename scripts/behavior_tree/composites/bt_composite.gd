@abstract
extends GAS_BTNode
class_name GAS_BTComposite

@export var children: Array[GAS_BTNode] = []

func reset(instance: GAS_BTInstance) -> void:
	for child: GAS_BTNode in children:
		if is_instance_valid(child):
			child.reset(instance)
	super.reset(instance)
	_clear_storage(instance)
