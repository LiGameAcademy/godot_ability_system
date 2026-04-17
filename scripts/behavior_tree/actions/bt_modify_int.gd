extends GAS_BTAction
class_name GAS_BTModifyInt

enum Operation { 
	SET,                ## 设置为指定值
	ADD,                ## 增加指定值
	SUBTRACT            ## 减少指定值
}

@export var variable_key: String = ""
@export var value: int = 1
@export var operation: Operation = Operation.ADD

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	var current_val: int = _get_var(instance, variable_key, 0)
	match operation:
		Operation.SET: current_val = value
		Operation.ADD: current_val += value
		Operation.SUBTRACT: current_val -= value
	_set_var(instance, variable_key, current_val)
	return Status.SUCCESS
