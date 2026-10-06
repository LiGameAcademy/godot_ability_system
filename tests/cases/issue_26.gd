extends RegressionCase

func run() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	var actor: Node3D = Node3D.new()
	scene_tree.root.add_child(actor)
	actor.position = Vector3(5, 0, 0)
	var strategy: StrategyCircleArea = StrategyCircleArea.new()
	strategy.max_range = 10.0
	strategy.begin(actor, null)
	strategy.update(0.0, {"mouse_position": Vector3(30, 0, 0)})
	expect(strategy.get_result_context().get("target_position") == Vector3(15, 0, 0), "Ground result must clamp from the stored caster")
	expect(strategy.is_targeting() and not strategy.is_finished(), "Begin must enter a live preview")
	strategy.cancel()
	expect(not strategy.is_targeting(), "Cancel must end preview state")
	expect(strategy.get_result_context().is_empty(), "Cancelled preview must not read a stale caster")
	strategy.begin(actor, null)
	expect(strategy.caster == actor, "Repeated begin must bind the current caster")
	strategy.cancel()
	actor.free()
