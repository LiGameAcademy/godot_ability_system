extends Node3D

@export var attribute_sets: Array[GameplayAttributeSet] = []
@export var vitals: Array[GameplayVital] = []
@onready var vital_component: GameplayVitalAttributeComponent = $GameplayVitalAttributeComponent
signal example_completed()

func _ready() -> void:
	vital_component.initialize(attribute_sets, vitals)
	var health: GameplayVital = vital_component.get_vital(&"health")
	var mana: GameplayVital = vital_component.get_vital(&"mana")
	assert(is_instance_valid(health) and is_instance_valid(mana))
	var old_health: float = health.current_value
	assert(vital_component.modify_vital(&"health", -20.0))
	assert(is_equal_approx(health.current_value, old_health - 20.0))
	assert(not vital_component.modify_vital(&"health", -(health.current_value + 1.0)))
	# 示例直接改变最大生命属性；项目的体质换算属于自己的属性集规则。
	var old_max: float = health.get_max_value()
	vital_component.set_base_value(&"max_health", old_max + 50.0)
	await get_tree().process_frame
	assert(is_equal_approx(health.get_max_value(), old_max + 50.0))
	assert(is_equal_approx(health.current_value, old_health - 20.0))
	var old_mana: float = mana.current_value
	assert(vital_component.modify_vital(&"mana", -10.0))
	assert(is_equal_approx(mana.current_value, old_mana - 10.0))
	print("Vital 示例通过：消耗、余额不足、最大值变化")
	example_completed.emit()
