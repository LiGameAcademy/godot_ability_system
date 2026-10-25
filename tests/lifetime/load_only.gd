extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var script: GDScript = load("res://addons/godot_ability_system/scripts/effects/gameplay_effect.gd")
	assert(script != null)
	print("GAS_EFFECT_LOAD_PASS")
	quit()
