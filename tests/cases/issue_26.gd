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
	actor.position = Vector3(8, 0, 0)
	strategy.update(0.0, {"mouse_position": Vector3(30, 0, 0)})
	expect(strategy.get_result_context().get("target_position") == Vector3(18, 0, 0), "Legacy Node3D calls must follow the current caster position")
	strategy.begin(actor, null, {"origin_position": Vector3(20, 0, 0)})
	strategy.update(0.0, {"mouse_position": Vector3(50, 0, 0)})
	expect(strategy.get_result_context().get("target_position") == Vector3(30, 0, 0), "Explicit origin must override the Node3D caster position")
	strategy.cancel()
	actor.free()
	_test_plain_node_origin()
	_test_indicator_parent()
	_test_invalid_context()
	_test_confirmation()
	_test_component_entry()

func _test_plain_node_origin() -> void:
	var actor: Node = Node.new()
	var strategy: StrategyCircleArea = StrategyCircleArea.new()
	var begin_context: Dictionary = {"origin_position": Vector3(5, 0, 0)}
	var input_context: Dictionary = {"mouse_position": Vector3(30, 0, 0)}
	strategy.begin(actor, null, begin_context)
	strategy.update(0.0, input_context)
	expect(strategy.caster == actor and strategy.is_targeting(), "A plain Node caster must be accepted with an explicit origin")
	expect(strategy.get_result_context().get("target_position") == Vector3(15, 0, 0), "Explicit origin must determine the range clamp")
	expect(begin_context == {"origin_position": Vector3(5, 0, 0)} and input_context == {"mouse_position": Vector3(30, 0, 0)}, "Preview must not write to caller context")
	strategy.update(0.0, {"origin_position": Vector3(8, 0, 0), "mouse_position": Vector3(30, 0, 0)})
	expect(strategy.get_result_context().get("target_position") == Vector3(18, 0, 0), "Updating the explicit origin must follow a moving spatial object")
	strategy.cancel()
	strategy.begin(actor, null, {"origin_position": Vector3(20, 0, 0)})
	expect(strategy.get_result_context().get("target_position") == Vector3(20, 0, 0), "Restart must discard the old mouse position")
	actor.free()
	strategy.update(0.0)
	expect(not strategy.is_targeting() and strategy.get_result_context().is_empty(), "A freed plain Node caster must safely end the preview")
	strategy.cancel()

func _test_indicator_parent() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	var actor: Node = Node.new()
	var visual_parent: Node3D = Node3D.new()
	scene_tree.root.add_child(visual_parent)
	visual_parent.position = Vector3(100, 0, 0)
	visual_parent.rotation.y = PI / 2.0
	var indicator_template: Node3D = Node3D.new()
	var indicator_scene: PackedScene = PackedScene.new()
	expect(indicator_scene.pack(indicator_template) == OK, "The indicator fixture must pack successfully")
	indicator_template.free()
	var strategy: StrategyDirectional = StrategyDirectional.new()
	strategy.indicator_scene = indicator_scene
	strategy.begin(actor, null, {"origin_position": Vector3(5, 0, 0), "indicator_parent": visual_parent})
	strategy.update(0.0, {"mouse_position": Vector3(30, 0, 0)})
	expect(visual_parent.get_child_count() == 1, "The indicator must use the explicit parent without requiring a current scene")
	if visual_parent.get_child_count() == 1:
		var indicator: Node3D = visual_parent.get_child(0) as Node3D
		expect(indicator.global_position.is_equal_approx(Vector3(5, 0, 0)), "The directional indicator must use the supplied world origin")
		expect(indicator.top_level, "Parent transforms must not move the world-space indicator")
		var old_indicator: WeakRef = weakref(indicator)
		strategy.cancel()
		expect(indicator.is_queued_for_deletion(), "Cancel must release the indicator")
		strategy.begin(actor, null, {"origin_position": Vector3(8, 0, 0), "indicator_parent": visual_parent})
		expect(visual_parent.get_child_count() == 2, "Restart must create a fresh indicator while the cancelled one awaits deletion")
		indicator.free()
		expect(old_indicator.get_ref() == null, "Cancelled indicator must be releasable")
	expect(strategy.get_result_context().get("target_direction") == Vector3.ZERO, "A fresh directional preview must not retain the old direction")
	visual_parent.free()
	strategy.update(0.0)
	expect(not strategy.is_targeting() and strategy.get_result_context().is_empty(), "A freed indicator parent must safely cancel the preview")
	strategy.cancel()
	var spatial_actor: Node3D = Node3D.new()
	scene_tree.root.add_child(spatial_actor)
	spatial_actor.position = Vector3(50, 0, 0)
	var circle: StrategyCircleArea = StrategyCircleArea.new()
	circle.indicator_scene = indicator_scene
	circle.begin(spatial_actor, null)
	circle.update(0.0, {"mouse_position": Vector3(30, 0, 0)})
	expect(spatial_actor.get_child_count() == 1, "Legacy calls must mount the indicator under the caster without a scene lookup")
	if spatial_actor.get_child_count() == 1:
		var indicator: Node3D = spatial_actor.get_child(0) as Node3D
		expect(indicator.global_position.is_equal_approx(Vector3(40, 0, 0)), "Circle indicator must use the clamped world position")
	circle.cancel()
	spatial_actor.free()
	actor.free()

func _test_invalid_context() -> void:
	var actor: Node = Node.new()
	var strategy: StrategyCircleArea = StrategyCircleArea.new()
	strategy.begin(actor, null)
	expect(not strategy.is_targeting(), "A plain Node without an origin must be rejected without reading a spatial property")
	strategy.begin(actor, null, {"origin_position": Vector2.ZERO})
	expect(not strategy.is_targeting() and strategy.get_result_context().is_empty(), "A 2D origin must not silently enter this 3D strategy")
	strategy.begin(actor, null, {"origin_position": Vector3.ZERO})
	strategy.update(0.0, {"mouse_position": Vector2.ZERO})
	expect(not strategy.is_targeting(), "Malformed 3D input must safely cancel")
	var invalid_template: Node = Node.new()
	var invalid_scene: PackedScene = PackedScene.new()
	expect(invalid_scene.pack(invalid_template) == OK, "The invalid-root fixture must pack successfully")
	invalid_template.free()
	strategy.indicator_scene = invalid_scene
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	strategy.begin(actor, null, {"origin_position": Vector3.ZERO, "indicator_parent": scene_tree.root})
	expect(not strategy.is_targeting(), "A non-Node3D indicator scene must safely reject the preview")
	strategy.begin(actor, null, {"origin_position": Vector3.ZERO, "indicator_parent": 123})
	expect(not strategy.is_targeting(), "An invalid indicator parent must safely reject the preview")
	strategy.indicator_scene = PackedScene.new()
	strategy.begin(actor, null, {"origin_position": Vector3.ZERO, "indicator_parent": scene_tree.root})
	expect(not strategy.is_targeting(), "An empty PackedScene must safely reject the preview")
	strategy.cancel()
	actor.free()

func _test_confirmation() -> void:
	var actor: Node = Node.new()
	var strategy: StrategyDirectional = StrategyDirectional.new()
	var had_action: bool = InputMap.has_action("confirm_cast")
	if not had_action:
		InputMap.add_action("confirm_cast")
	strategy.begin(actor, null, {"origin_position": Vector3(5, 0, 0)})
	var confirm_event: InputEventAction = InputEventAction.new()
	confirm_event.action = &"confirm_cast"
	confirm_event.pressed = true
	Input.parse_input_event(confirm_event)
	Input.flush_buffered_events()
	strategy.update(0.0, {"mouse_position": Vector3(30, 0, 0)})
	expect(strategy.is_finished() and not strategy.is_targeting(), "Confirmation must finish even when no indicator scene is configured")
	var confirmed: Dictionary = strategy.get_result_context()
	expect(confirmed.get("target_position") == Vector3(15, 0, 0) and confirmed.get("target_direction") == Vector3.RIGHT, "Confirmed directional result must use the explicit origin")
	strategy.update(0.0, {"origin_position": Vector3(20, 0, 0), "mouse_position": Vector3(-50, 0, 0)})
	expect(strategy.get_result_context() == confirmed, "Further updates must not overwrite a confirmed result")
	confirmed["target_position"] = Vector3.ZERO
	expect(strategy.get_result_context().get("target_position") == Vector3(15, 0, 0), "Returned result must not expose the stored confirmation dictionary")
	Input.action_release("confirm_cast")
	strategy.begin(actor, null, {"origin_position": Vector3(20, 0, 0)})
	expect(not strategy.is_finished() and strategy.is_targeting(), "A new begin must reset the previous completed state")
	expect(strategy.get_result_context().get("target_direction") == Vector3.ZERO, "A new begin must discard the previous completed result")
	strategy.cancel()
	actor.free()
	if not had_action:
		InputMap.erase_action("confirm_cast")

func _test_component_entry() -> void:
	var actor: Node = Node.new()
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(actor)
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	actor.add_child(component)
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.ability_id = &"plain_node_preview"
	definition.execution_tree = RegressionBTProbe.new()
	definition.preview_strategy = StrategyCircleArea.new()
	component.learn_ability(definition)
	var context: Dictionary = {"origin_position": Vector3(5, 0, 0)}
	var ability: GameplayAbilityInstance = component.request_ability_preview(definition.ability_id, context)
	expect(is_instance_valid(ability) and component.has_targeting_ability(), "The component must forward an explicit origin for a plain Node owner")
	if is_instance_valid(ability):
		component.update_targeting(0.0, {"origin_position": Vector3(8, 0, 0), "mouse_position": Vector3(30, 0, 0)})
		expect(component.confirm_targeting().get("target_position") == Vector3(18, 0, 0), "The component path must preserve updated world coordinates")
		expect(component.try_activate_targeting_ability(), "A plain Node preview must activate through the component")
		expect(not component.has_targeting_ability() and ability.is_active, "Activation must transfer the preview into an execution")
		component.cancel_ability(definition.ability_id)
		expect(not ability.is_active, "Cancellation must also work through the public component path")
	expect(context == {"origin_position": Vector3(5, 0, 0)}, "Starting a component preview must not modify caller context")
	actor.free()
