extends RegressionCase

func run() -> void:
	var attribute: GameplayAttributeInstance = GameplayAttributeInstance.new(GameplayAttribute.new(), 10.0)
	var modifier: GameplayAttributeModifier = GameplayAttributeModifier.new()
	modifier.source_id = &"test_source"
	modifier.value = 5.0
	attribute.add_modifier(modifier)
	attribute.remove_modifier(modifier)
	expect(attribute.get_value() == 10.0, "Removal must restore base value")
	expect(not attribute._modifiers_by_source_id.has(&"test_source"), "Last removal must release source references")
	attribute.add_modifier(modifier)
	expect(attribute._modifiers_by_source_id[&"test_source"].size() == 1, "Re-add must not duplicate the source index")
	attribute.remove_modifiers_by_source(&"test_source")
	expect(attribute.get_modifers().is_empty(), "Batch removal must remove the re-added modifier")
