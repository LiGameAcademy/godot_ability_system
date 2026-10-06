extends GAS_BTAction
class_name RegressionBTProbe

var result: int = Status.RUNNING
var enters: int = 0
var exits: int = 0
var ticks: int = 0

func _enter(_instance: GAS_BTInstance) -> void:
	enters += 1

func _tick(_instance: GAS_BTInstance, _delta: float) -> int:
	ticks += 1
	return result

func _exit(_instance: GAS_BTInstance) -> void:
	exits += 1
