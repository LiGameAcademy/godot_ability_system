extends RegressionCase

func run() -> void:
	var definition: GameplayAttribute = GameplayAttribute.new()
	var attribute: GameplayAttributeInstance = GameplayAttributeInstance.new(definition, 10.0)
	var changes: Array[Vector2] = []
	attribute.base_value_changed.connect(func(old_value: float, new_value: float) -> void:
		changes.append(Vector2(old_value, new_value)))
	attribute.base_value = 15.0
	attribute.base_value = 15.0
	attribute.base_value = 7.0
	expect(changes == [Vector2(10, 15), Vector2(15, 7)], "Signal must carry previous value and skip unchanged assignments")
	expect(attribute.get_value() == 7.0, "Calculated value must stay synchronized")
