extends RefCounted
class_name RegressionCase

var failures: Array[String] = []

func run() -> void:
	pass

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
