extends RegressionCase

class PersistentFeature extends GameplayAbilityFeature:
	func initialize(instance: GameplayAbilityInstance) -> void:
		_set_data(instance, "count", 7)
	func get_count(instance: GameplayAbilityInstance) -> int:
		return int(_get_data(instance, "count", 0))

func run() -> void:
	var actor: Node = Node.new()
	var feature: PersistentFeature = PersistentFeature.new()
	var cooldown: CooldownFeature = CooldownFeature.new()
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.execution_tree = RegressionBTProbe.new()
	definition.blackboard_defaults = {"range": 12.0, "nested": {"values": [1, 2]}}
	definition.features = [feature, cooldown]
	var ability: GameplayAbilityInstance = definition.create_instance(actor)
	var other: GameplayAbilityInstance = definition.create_instance(actor)
	var nested: Dictionary = ability.get_blackboard_var("nested", {})
	nested["values"][0] = 99
	expect(other.get_blackboard_var("nested", {}).get("values", [])[0] == 1, "Mutable defaults must be isolated between instances")
	expect(definition.blackboard_defaults["nested"]["values"][0] == 1, "Mutable defaults must not change the template")
	ability.try_activate()
	expect(ability.get_blackboard_var("range") == 12.0 and ability.get_blackboard_var("nested", {}).get("values", [])[0] == 1, "Activation must restore defaults")
	expect(feature.get_count(ability) == 7, "Activation must preserve initialized feature data")
	ability.end_ability()
	cooldown.start_cooldown(ability, 5.0)
	ability.clear_blackboard()
	expect(cooldown.get_cooldown_remaining(ability) == 5.0, "Clearing execution storage must not reset cooldown")
	ability.try_activate({"skip_cooldown": true})
	expect(cooldown.get_cooldown_remaining(ability) == 5.0, "Activation with skip must not wipe an existing cooldown")
	ability.end_ability()
	ability.remove_feature(feature.feature_name)
	expect(ability.get_feature_data(feature.feature_name, "count", 0) == 0, "Feature removal must release its own persistent storage")
	# Release blackboard's self entry explicitly in this regression fixture.
	ability.get_blackboard().clear()
	other.get_blackboard().clear()
	actor.free()
