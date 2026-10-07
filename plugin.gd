@tool
extends EditorPlugin

func _enter_tree() -> void:
	var directory: String = get_script().resource_path.get_base_dir()
	add_autoload_singleton("GameplayAbilitySystem", directory.path_join("scripts/singletons/gameplay_ability_system.gd"))
	add_autoload_singleton("DamageCalculator", directory.path_join("scripts/singletons/damage_calculator.gd"))
	add_autoload_singleton("TagManager", directory.path_join("scripts/singletons/gameplay_tag_manager.gd"))
	add_autoload_singleton("AbilityEventBus", directory.path_join("scripts/singletons/ability_event_bus.gd"))
	add_autoload_singleton("GameplayCueManager", directory.path_join("scripts/singletons/gameplay_cue_manager.gd"))

func _exit_tree() -> void:
	remove_autoload_singleton("GameplayAbilitySystem")
	remove_autoload_singleton("DamageCalculator")
	remove_autoload_singleton("TagManager")
	remove_autoload_singleton("AbilityEventBus")
	remove_autoload_singleton("GameplayCueManager")
