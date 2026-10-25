extends Node

var _checks: int = 0
var _failed: int = 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed += 1
		push_error("GAS_EFFECT_LIFETIME: " + message)

func _run() -> void:
	for iteration: int in range(6):
		var references: Array[WeakRef] = _exercise(iteration)
		for reference: WeakRef in references:
			_check(reference.get_ref() == null, "effect and filter instances released after scope")
	print("GAS_EFFECT_INSTANCES_%s checks=%d" % ["PASS" if _failed == 0 else "FAIL", _checks])
	get_tree().quit(0 if _failed == 0 else 1)

func _exercise(iteration: int) -> Array[WeakRef]:
	var effect_script: GDScript = load("res://addons/godot_ability_system/tests/lifetime/recording_effect.gd")
	var filter_script: GDScript = load("res://addons/godot_ability_system/tests/lifetime/accepting_filter.gd")
	var first: GameplayEffect = effect_script.new()
	var second: GameplayEffect = effect_script.new()
	_check(first.sub_effects.is_empty() and second.sub_effects.is_empty(), "new defaults are empty")
	_check(first.sub_effects.get_typed_script() == GameplayEffect, "default keeps GameplayEffect element type")
	_check(not is_same(first.sub_effects, second.sub_effects), "default arrays belong to each instance")
	var child: GameplayEffect = effect_script.new()
	var filter: GameplayFilterData = filter_script.new()
	first.sub_effects.append(child)
	first.filters.append(filter)
	_check(second.sub_effects.is_empty() and second.filters.is_empty(), "editing first does not affect second")
	var alias: Array[GameplayEffect] = first.sub_effects
	alias.append(effect_script.new())
	_check(first.sub_effects.size() == 2, "array access preserves in-place mutation")
	alias.pop_back()
	var target: Node = Node.new()
	filter.set("allowed", false)
	first.apply(target, null)
	_check(not target.has_meta("applied"), "rejected filter prevents parent and child")
	filter.set("allowed", true)
	first.apply(target, null)
	_check(int(target.get_meta("applied", 0)) == 2, "parent and child each apply once")
	first.remove(target, null)
	_check(int(target.get_meta("removed", 0)) == 2, "parent and child each remove once")
	target.free()
	var copied: GameplayEffect = first.duplicate(true) as GameplayEffect
	_check(copied.sub_effects.size() == 1 and copied.filters.size() == 1, "deep copy preserves configuration")
	_check(copied.sub_effects[0] != child and copied.filters[0] != filter, "deep copy isolates nested resources")
	copied.filters[0].set("allowed", false)
	_check(bool(filter.get("allowed")), "changing copied filter leaves template unchanged")
	var path: String = "user://gas-effect-lifetime-%d-%d.tres" % [OS.get_process_id(), iteration]
	_check(ResourceSaver.save(first, path) == OK, "effect graph saves")
	var restored: GameplayEffect = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GameplayEffect
	_check(restored != null, "effect graph reloads")
	_check(restored.sub_effects.get_typed_script() == GameplayEffect, "reload keeps typed child array")
	_check(restored.sub_effects.size() == 1 and restored.filters.size() == 1, "reload preserves child and filter")
	_check(restored != first and restored.sub_effects[0] != child, "reload does not reuse live template")
	var restored_target: Node = Node.new()
	restored.apply(restored_target, null)
	_check(int(restored_target.get_meta("applied", 0)) == 2, "reloaded effect graph executes once per node")
	restored_target.free()
	_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "temporary resource removed")
	return [weakref(first), weakref(second), weakref(child), weakref(filter), weakref(copied), weakref(restored)]
