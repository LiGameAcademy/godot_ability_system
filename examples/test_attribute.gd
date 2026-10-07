extends Node3D

## 示例配置来自插件自带的属性集，也可在检查器替换。
@export var attribute_sets: Array[GameplayAttributeSet] = []
@onready var attribute_component: GameplayAttributeComponent = $GameplayAttributeComponent
signal example_completed()

func _ready() -> void:
	attribute_component.initialize(attribute_sets)
	attribute_component.set_base_value(&"strength", 15.0)
	await get_tree().process_frame
	assert(is_equal_approx(attribute_component.get_value(&"strength"), 15.0))
	var addition: GameplayAttributeModifier = GameplayAttributeModifier.new(&"strength", 10.0, GameplayAttributeModifier.ModifierType.ADD)
	var multiplier: GameplayAttributeModifier = GameplayAttributeModifier.new(&"strength", 0.2, GameplayAttributeModifier.ModifierType.MULTIPLY)
	attribute_component.add_modifier(addition)
	attribute_component.add_modifier(multiplier)
	await get_tree().process_frame
	assert(is_equal_approx(attribute_component.get_value(&"strength"), 30.0))
	attribute_component.remove_modifier(addition)
	attribute_component.remove_modifier(multiplier)
	await get_tree().process_frame
	assert(is_equal_approx(attribute_component.get_value(&"strength"), 15.0))
	print("属性示例通过：基础值、加法、乘法、移除修改器")
	example_completed.emit()
