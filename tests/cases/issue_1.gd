extends RegressionCase

const PLUGIN_ROOT: String = "res://addons/gas_regression_plugin/"

class Modifier extends AbilityEffectModifier:
	@export var multiplier: float = 2.0
	func affects_ability(ability_id: StringName) -> bool:
		return ability_id == &"modifier_case"
	func apply_to_context(context: Dictionary) -> void:
		context["damage_multiplier"] = multiplier

func run() -> void:
	for folder: String in ["scripts", "ui", "examples"]:
		_test_scripts(PLUGIN_ROOT + folder)
	_test_modifier()
	_test_resources()
	await _test_melee()
	await _test_examples()

func _test_scripts(directory: String) -> void:
	for child: String in DirAccess.get_directories_at(directory):
		_test_scripts(directory.path_join(child))
	for entry: String in DirAccess.get_files_at(directory):
		if not entry.ends_with(".gd"):
			continue
		var script: GDScript = load(directory.path_join(entry)) as GDScript
		expect(is_instance_valid(script), "Bundled script must load: " + directory.path_join(entry))
		if is_instance_valid(script) and not script.source_code.strip_edges().begins_with("@abstract"):
			expect(script.can_instantiate(), "Concrete script must compile: " + directory.path_join(entry))

func _test_modifier() -> void:
	var modifier: Modifier = Modifier.new()
	var feature: EffectModifierFeature = EffectModifierFeature.new()
	feature.effect_modifiers = [modifier]
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.ability_id = &"modifier_case"
	definition.execution_tree = RegressionBTProbe.new()
	definition.features = [feature]
	var actor_a: Node = Node.new()
	var actor_b: Node = Node.new()
	var ability_a: GameplayAbilityInstance = definition.create_instance(actor_a)
	var ability_b: GameplayAbilityInstance = definition.create_instance(actor_b)
	var input: Dictionary = {"damage_multiplier": 1.0}
	ability_a.try_activate(input)
	ability_b.try_activate()
	var context_a: Dictionary = ability_a.get_blackboard_var("context")
	var context_b: Dictionary = ability_b.get_blackboard_var("context")
	expect(context_a.get("damage_multiplier") == 2.0 and context_b.get("damage_multiplier") == 2.0, "Plugin-owned modifier contract must work for two ability instances")
	context_a["damage_multiplier"] = 9.0
	expect(context_b.get("damage_multiplier") == 2.0 and input.get("damage_multiplier") == 1.0 and modifier.multiplier == 2.0, "A modifier must not mutate another execution, caller input, or its template")
	ability_a.dispose()
	ability_b.dispose()
	actor_a.free()
	actor_b.free()

func _test_resources() -> void:
	for folder: String in ["ui", "assets/materials", "assets/theme", "examples"]:
		for entry: String in DirAccess.get_files_at(PLUGIN_ROOT + folder):
			if not entry.ends_with(".tres") and not entry.ends_with(".tscn"):
				continue
			var resource: Resource = load(PLUGIN_ROOT + folder + "/" + entry)
			expect(is_instance_valid(resource), "Bundled resource must load: " + folder + "/" + entry)

func _test_melee() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	var world: Node3D = Node3D.new()
	scene_tree.root.add_child(world)
	var caster: CharacterBody3D = CharacterBody3D.new()
	world.add_child(caster)
	var caster_shape: CollisionShape3D = CollisionShape3D.new()
	caster_shape.shape = BoxShape3D.new()
	caster.add_child(caster_shape)
	var enemy: Node3D = Node3D.new()
	world.add_child(enemy)
	enemy.position = Vector3(0, 1, -1)
	for index: int in 2:
		var area: Area3D = Area3D.new()
		enemy.add_child(area)
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = BoxShape3D.new()
		area.add_child(collision)
	var detector: MeleeBoxHitDetector = MeleeBoxHitDetector.new()
	detector.offset = Vector3(1, 1, 1)
	detector.debug_draw_enabled = true
	var boxes: Array[AABB] = []
	var on_debug: Callable = func(bounds: AABB, _color: Color, _frames: int) -> void:
		boxes.append(bounds)
	detector.debug_box_requested.connect(on_debug)
	await scene_tree.physics_frame
	await scene_tree.process_frame
	var targets: Array[Node] = detector.get_targets(caster, {"facing_direction": Vector3.FORWARD})
	expect(targets.size() == 1 and targets[0] == enemy, "Physics query must exclude its caster by RID and deduplicate the entity's colliders")
	expect(boxes.size() == 1 and boxes[0].size.is_equal_approx(Vector3(2, 2, 2)), "Debug drawing must emit a request without a DebugDraw dependency")
	expect(boxes.size() == 1 and boxes[0].get_center().is_equal_approx(Vector3(1, 1, -1)), "Positive x offset must preserve rightward placement")
	detector.debug_box_requested.disconnect(on_debug)
	var old_caster: WeakRef = weakref(caster)
	world.free()
	expect(detector.get_targets(old_caster.get_ref() as Node3D).is_empty(), "A released caster must safely return no targets")

func _test_examples() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	for name: String in ["test_attribute", "test_vital_system", "test_effect_basic", "test_status_component"]:
		var packed: PackedScene = load(PLUGIN_ROOT + "examples/" + name + ".tscn") as PackedScene
		if not is_instance_valid(packed):
			expect(false, "Example scene must load: " + name)
			continue
		var example: Node = packed.instantiate()
		var done: Array[bool] = [false]
		var callback: Callable = func() -> void:
			done[0] = true
		example.connect("example_completed", callback)
		scene_tree.root.add_child(example)
		for frame: int in 8:
			if done[0]:
				break
			await scene_tree.process_frame
		expect(done[0], "Bundled example must finish its assertions: " + name)
		example.disconnect("example_completed", callback)
		example.free()
