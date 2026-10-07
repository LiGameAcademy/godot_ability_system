extends RegressionCase

class CountEffect extends GameplayEffect:
	func _apply(target: Node, _instigator: Node, _context: Dictionary) -> void:
		target.set_meta("child_calls", int(target.get_meta("child_calls", 0)) + 1)
	func _apply_result(target: Node, instigator: Node, context: Dictionary) -> GameplayEffectResult:
		_apply(target, instigator, context)
		return GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED)

class CueDamage extends GE_ApplyDamage:
	func _execute_cue(target: Node, _context: Dictionary) -> void:
		target.set_meta("cue_calls", int(target.get_meta("cue_calls", 0)) + 1)

class LegacyEffect extends GameplayEffect:
	func _apply(target: Node, _instigator: Node, _context: Dictionary) -> void:
		target.set_meta("legacy_called", true)

class FailedEffect extends CountEffect:
	func _apply_result(_target: Node, _instigator: Node, _context: Dictionary) -> GameplayEffectResult:
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.MISSING_DEPENDENCY)

class RejectFilter extends GameplayFilterData:
	func _check(_target: Node, _instigator: Node, _context: Dictionary) -> bool:
		return false

class FixedDamage extends DamageLogicStrategy:
	func calculate(_target: Node, _instigator: Node, _context: Dictionary) -> float:
		return 10.0

class OrderedEffect extends GameplayEffect:
	@export var step: int = 0
	func _apply_result(target: Node, _instigator: Node, _context: Dictionary) -> GameplayEffectResult:
		var order: Array[int] = target.get_meta("order", [] as Array[int])
		order.append(step)
		target.set_meta("order", order)
		return GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED)

class DestroyEffect extends GameplayEffect:
	func _apply_result(target: Node, _instigator: Node, _context: Dictionary) -> GameplayEffectResult:
		target.free()
		return GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED)

class DestroyFilter extends GameplayFilterData:
	func _check(target: Node, _instigator: Node, _context: Dictionary) -> bool:
		target.free()
		return true

func run() -> void:
	var actor: Node = Node.new()
	var damage: CueDamage = CueDamage.new()
	damage.cue = GameplayCue.new()
	damage.sub_effects = [CountEffect.new()]
	damage.apply(actor, actor)
	expect(int(actor.get_meta("cue_calls", 0)) == 0, "Missing damage dependency must not play a successful Cue")
	expect(int(actor.get_meta("child_calls", 0)) == 0, "Failed parent must not execute its child effects")
	var node: AbilityNodeApplyEffect = AbilityNodeApplyEffect.new()
	node.effects = [damage]
	var blackboard: GAS_BTBlackboard = GAS_BTBlackboard.new()
	var targets: Array[Node] = [actor]
	blackboard.set_var("context", {"instigator": actor, "targets": targets})
	blackboard.set_var("targets", targets)
	var tree: GAS_BTInstance = GAS_BTInstance.new(actor, node, blackboard)
	expect(tree.tick(0.0) == GAS_BTNode.Status.FAILURE, "A failed effect must not become BT success")
	tree.dispose()
	blackboard.clear()
	actor.free()
	_test_filters_and_legacy()
	_test_children_and_cycles()
	_test_damage_and_vital_outputs()
	_test_node_policies_and_snapshots()
	_test_status_and_other_builtins()
	_test_order_and_target_exit()
	_test_immunity_and_partial_policy()
	_test_scene_and_motion()

func _test_filters_and_legacy() -> void:
	var actor: Node = Node.new()
	var effect: CountEffect = CountEffect.new()
	effect.filters = [RejectFilter.new()]
	var result: GameplayEffectResult = effect.apply(actor, actor)
	expect(result.status == GameplayEffectResult.Status.NOT_APPLIED and result.reason == GameplayEffectResult.Reason.FILTERED, "Filter rejection must be visible without running logic")
	effect.filters = [null]
	expect(effect.apply(actor, actor).reason == GameplayEffectResult.Reason.INVALID_CONFIGURATION, "Invalid filter must be a configuration failure")
	effect.filters = []
	var tag: GameplayTag = GameplayTag.new()
	tag.id = &"issue_43.immunity"
	if not is_instance_valid(TagManager.get_tag_resource(tag.id)):
		TagManager.register_tag(tag)
	TagManager.add_tag(actor, tag.id)
	effect.target_blocked_tags = [tag.id]
	result = effect.apply(actor, actor)
	expect(result.status == GameplayEffectResult.Status.NOT_APPLIED and result.reason == GameplayEffectResult.Reason.IMMUNE, "Immunity must be distinguishable from a filter or dependency error")
	effect.target_blocked_tags = []
	effect.target_required_tags = [&"issue_43.required"]
	expect(effect.apply(actor, actor).reason == GameplayEffectResult.Reason.REQUIRED_TAG_MISSING, "Missing required tag must have its own reason")
	expect(effect.apply(null, actor).reason == GameplayEffectResult.Reason.INVALID_TARGET, "Invalid target must fail before reading target state")
	var legacy: LegacyEffect = LegacyEffect.new()
	legacy.sub_effects = [CountEffect.new()]
	result = legacy.apply(actor, actor)
	expect(actor.get_meta("legacy_called", false) and result.status == GameplayEffectResult.Status.UNVERIFIED, "Void legacy hook must execute but must not claim known success")
	expect(int(actor.get_meta("child_calls", 0)) == 0, "Unverified parent must not continue child effects")
	TagManager.clear_all_tags(actor)
	actor.free()

func _test_children_and_cycles() -> void:
	var actor: Node = Node.new()
	var effect: CountEffect = CountEffect.new()
	effect.sub_effects = [CountEffect.new(), FailedEffect.new(), CountEffect.new()]
	var result: GameplayEffectResult = effect.apply(actor, actor)
	expect(result.status == GameplayEffectResult.Status.PARTIAL and result.has_failure(), "Applied parent and failed child must report partial results")
	expect(int(actor.get_meta("child_calls", 0)) == 2 and result.children.size() == 3, "Default policy must stop later children after a hard failure")
	actor.set_meta("child_calls", 0)
	effect.child_failure_policy = GameplayEffect.ChildFailurePolicy.CONTINUE
	result = effect.apply(actor, actor)
	expect(int(actor.get_meta("child_calls", 0)) == 3 and result.children.size() == 4, "Continue policy must retain failure and run later children in order")
	var cycle: CountEffect = CountEffect.new()
	cycle.sub_effects = [cycle]
	result = cycle.apply(actor, actor)
	expect(result.status == GameplayEffectResult.Status.PARTIAL and result.has_failure(), "Cyclic child configuration must terminate with visible failure")
	cycle.sub_effects.clear()
	actor.free()

func _test_damage_and_vital_outputs() -> void:
	var actor: Node = _target()
	var effect: CueDamage = CueDamage.new()
	effect.damage_strategy = FixedDamage.new()
	effect.cue = GameplayCue.new()
	var context: Dictionary = {"damage_multiplier": 2.0}
	var result: GameplayEffectResult = effect.apply(actor, actor, context)
	expect(result.status == GameplayEffectResult.Status.APPLIED and result.outputs["final_damage"] == 10.0, "Damage result must return actual numerical output")
	expect(context["damage_multiplier"] == 2.0 and context["final_damage"] == 10.0 and int(actor.get_meta("cue_calls", 0)) == 1, "Single-target compatibility output and successful Cue must remain")
	var vital: GE_ModifyVital = GE_ModifyVital.new()
	vital.vital_id = &"health"
	vital.amount = 100.0
	result = vital.apply(actor, actor)
	expect(result.status == GameplayEffectResult.Status.APPLIED and result.outputs["delta"] == 10.0, "Healing output must reflect clamping rather than configured amount")
	result = vital.apply(actor, actor)
	expect(result.status == GameplayEffectResult.Status.NOT_APPLIED and result.reason == GameplayEffectResult.Reason.NO_CHANGE, "Healing full Vital must not claim a change")
	vital.amount = -200.0
	expect(vital.apply(actor, actor).status == GameplayEffectResult.Status.NOT_APPLIED, "Rejected Vital write must not claim success")
	vital.amount = NAN
	expect(vital.apply(actor, actor).reason == GameplayEffectResult.Reason.INVALID_CONFIGURATION, "Nonfinite amount must fail before modifying a Vital")
	actor.free()

func _ability(actor: Node, node: AbilityNodeApplyEffect) -> GameplayAbilityInstance:
	var definition: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	definition.execution_tree = node
	return definition.create_instance(actor)

func _test_node_policies_and_snapshots() -> void:
	var actor: Node = Node.new()
	var first: Node = Node.new()
	var second: Node = Node.new()
	var node: AbilityNodeApplyEffect = AbilityNodeApplyEffect.new()
	node.effects = [CountEffect.new()]
	var ability: GameplayAbilityInstance = _ability(actor, node)
	var targets: Array[Node] = [first, second, first]
	var context: Dictionary = {"instigator": actor, "targets": targets}
	ability.try_activate(context)
	ability.update(0.0)
	var result: AbilityResult = ability.get_last_execution_result()
	expect(result.status == AbilityResult.Status.COMPLETED and result.effects.size() == 2, "Multi-target results must be retained individually")
	expect(int(first.get_meta("child_calls", 0)) == 1 and int(second.get_meta("child_calls", 0)) == 1, "Context plus blackboard and duplicate targets must not apply the same effect twice")
	result.effects[0].status = GameplayEffectResult.Status.FAILED
	expect(ability.get_last_execution_result().effects[0].status == GameplayEffectResult.Status.APPLIED, "Returned nested effect results must be snapshots")
	ability.dispose()
	ability = _ability(actor, node)
	ability.try_activate({"instigator": actor})
	ability.update(0.0)
	result = ability.get_last_execution_result()
	expect(result.status == AbilityResult.Status.FAILED and result.failure_reason == AbilityResult.FailureReason.NO_TARGET, "Empty target must be distinguishable from cancellation and generic BT failure")
	ability.dispose()
	node.success_policy = AbilityNodeApplyEffect.SuccessPolicy.ALLOW_NOT_APPLIED
	ability = _ability(actor, node)
	ability.try_activate({"instigator": actor})
	ability.update(0.0)
	result = ability.get_last_execution_result()
	expect(result.status == AbilityResult.Status.COMPLETED and result.effects[0].reason == GameplayEffectResult.Reason.NO_TARGET, "Explicit empty-hit policy can complete without pretending an effect applied")
	ability.dispose()
	node.success_policy = AbilityNodeApplyEffect.SuccessPolicy.ALL_APPLIED
	node.effects = [CountEffect.new(), FailedEffect.new()]
	ability = _ability(actor, node)
	ability.try_activate(context)
	ability.update(0.0)
	result = ability.get_last_execution_result()
	expect(result.status == AbilityResult.Status.FAILED and result.effects[0].did_apply() and result.effects[1].has_failure(), "Strict policy must retain the irreversible first effect when the next fails")
	ability.dispose()
	first.free()
	second.free()
	actor.free()

func _test_status_and_other_builtins() -> void:
	var actor: Node = _target()
	var component: GameplayStatusComponent = GameplayStatusComponent.new()
	component.name = "GameplayStatusComponent"
	actor.add_child(component)
	var data: GameplayStatusData = GameplayStatusData.new()
	data.status_id = &"issue_43.status"
	data.tags = [&"issue_43.dispel"]
	data.duration = 10.0
	var effect: GE_ApplyStatus = GE_ApplyStatus.new()
	var result: GameplayEffectResult = effect.apply(actor, actor, {"status_data": data, "status_stacks": 1})
	expect(result.did_apply() and component.has_status(data.status_id), "Status application must expose actual creation")
	expect(effect.status_data == null and effect.stacks == 1, "Context overrides must not write back to shared status configuration")
	var dispel: GE_DispelStatus = GE_DispelStatus.new()
	dispel.tags_to_remove = data.tags
	result = dispel.apply(actor, actor)
	expect(result.did_apply() and result.outputs["removed_count"] == 1, "Dispel must report actual removed count")
	expect(dispel.apply(actor, actor).reason == GameplayEffectResult.Reason.NO_CHANGE, "Empty dispel must not claim a removal")
	var modifier: GE_AttributeModifier = GE_AttributeModifier.new()
	var bad: GameplayAttributeModifier = GameplayAttributeModifier.new()
	bad.attribute_id = &"missing"
	modifier.modifiers = [bad]
	expect(modifier.apply(actor, actor).reason == GameplayEffectResult.Reason.MISSING_DEPENDENCY, "Unknown attribute must not silently count as modifier success")
	expect(GE_ModifyIncomingDamage.new().apply(actor, actor).reason == GameplayEffectResult.Reason.MISSING_DEPENDENCY, "Incoming damage modifier must reject missing payload")
	expect(GE_SpawnMagicField.new().apply(actor, actor).reason == GameplayEffectResult.Reason.INVALID_CONFIGURATION, "Missing scene must be a visible configuration error")
	expect(GE_SingleFrameMotion.new().apply(actor, actor).reason == GameplayEffectResult.Reason.MISSING_DEPENDENCY, "Motion on a plain Node must report wrong target type")
	var transform: GE_StatusTransform = GE_StatusTransform.new()
	transform.statuses_to_apply[data] = 1
	expect(transform.apply(actor, actor).did_apply(), "Configured status transform must return its child operation results")
	component.remove_status(data.status_id)
	data.apply_effects = [FailedEffect.new()]
	result = effect.apply(actor, actor, {"status_data": data})
	expect(result.status == GameplayEffectResult.Status.PARTIAL and result.has_failure(), "Created status must preserve failures of its initial effects")
	component.remove_status(data.status_id)
	bad.attribute_id = &"max_health"
	bad.value = 20.0
	result = modifier.apply(actor, actor)
	var attributes: GameplayVitalAttributeComponent = actor.get_node("GameplayVitalAttributeComponent") as GameplayVitalAttributeComponent
	expect(result.did_apply() and attributes.get_value(&"max_health") == 120.0, "Modifier success must correspond to an installed numerical change")
	modifier.remove(actor, actor)
	expect(attributes.get_value(&"max_health") == 100.0 and bad.source_id.is_empty(), "Modifier template and previous remove entry must remain usable")
	var info: GameplayDamageInfo = GameplayDamageInfo.new(actor, actor, 20.0)
	info.final_damage = 20.0
	result = GE_ModifyIncomingDamage.new().apply(actor, actor, {"damage_info": info})
	expect(result.did_apply() and info.final_damage == 10.0 and result.outputs["final_damage"] == 10.0, "Incoming damage result must describe the shared damage payload change")
	actor.free()

func _test_order_and_target_exit() -> void:
	var actor: Node = Node.new()
	var parent: OrderedEffect = OrderedEffect.new()
	parent.step = 1
	var first: OrderedEffect = OrderedEffect.new()
	first.step = 2
	var second: OrderedEffect = OrderedEffect.new()
	second.step = 3
	parent.sub_effects = [first, second]
	parent.apply(actor, actor)
	expect(actor.get_meta("order") == [1, 2, 3], "Primary and child effects must run in configured order")
	actor.free()
	actor = Node.new()
	var target_id: int = actor.get_instance_id()
	var destroy: DestroyEffect = DestroyEffect.new()
	destroy.sub_effects = [CountEffect.new()]
	var result: GameplayEffectResult = destroy.apply(actor, actor)
	expect(result.status == GameplayEffectResult.Status.PARTIAL and result.has_failure() and result.target_id == target_id, "Target exit must retain the applied operation and target identity without executing later children")
	actor = Node.new()
	var filtered: CountEffect = CountEffect.new()
	filtered.filters = [DestroyFilter.new()]
	expect(filtered.apply(actor, actor).reason == GameplayEffectResult.Reason.INVALID_TARGET, "Target freed by a filter must fail before entering effect logic")

func _test_immunity_and_partial_policy() -> void:
	var actor: Node = Node.new()
	TagManager.add_tag(actor, &"issue_43.immunity")
	var effect: CountEffect = CountEffect.new()
	effect.target_blocked_tags = [&"issue_43.immunity"]
	var node: AbilityNodeApplyEffect = AbilityNodeApplyEffect.new()
	node.effects = [effect]
	var targets: Array[Node] = [actor]
	var context: Dictionary = {"instigator": actor, "targets": targets}
	var ability: GameplayAbilityInstance = _ability(actor, node)
	ability.try_activate(context)
	ability.update(0.0)
	var result: AbilityResult = ability.get_last_execution_result()
	expect(result.failure_reason == AbilityResult.FailureReason.IMMUNE and result.effects[0].reason == GameplayEffectResult.Reason.IMMUNE, "Ability failure must distinguish immunity from cancellation and missing targets")
	ability.dispose()
	node.effects = [CountEffect.new(), FailedEffect.new()]
	ability = _ability(actor, node)
	ability.try_activate(context)
	ability.update(0.0)
	result = ability.get_last_execution_result()
	expect(result.status == AbilityResult.Status.COMPLETED and result.effects[1].has_failure(), "Default any-applied policy must preserve partial failure while allowing completion")
	ability.dispose()
	node.success_policy = AbilityNodeApplyEffect.SuccessPolicy.ALLOW_NOT_APPLIED
	node.effects = [FailedEffect.new()]
	ability = _ability(actor, node)
	ability.try_activate(context)
	ability.update(0.0)
	expect(ability.get_last_execution_result().status == AbilityResult.Status.FAILED, "Allowing empty hits must never turn missing dependencies into success")
	ability.dispose()
	node.success_policy = AbilityNodeApplyEffect.SuccessPolicy.ALL_APPLIED
	node.stop_on_failure = false
	node.effects = [FailedEffect.new(), CountEffect.new()]
	ability = _ability(actor, node)
	ability.try_activate(context)
	ability.update(0.0)
	expect(ability.get_last_execution_result().failure_reason == AbilityResult.FailureReason.EFFECT_FAILED, "Later applied effect must not erase an earlier failure under the all-applied policy")
	ability.dispose()
	TagManager.clear_all_tags(actor)
	actor.free()

func _test_scene_and_motion() -> void:
	var actor: Node = Node.new()
	var field: MagicFieldBase = MagicFieldBase.new()
	var scene: PackedScene = PackedScene.new()
	expect(scene.pack(field) == OK, "Magic field fixture must pack")
	field.free()
	var data: MagicFieldData = MagicFieldData.new()
	data.magic_field_scene = scene
	data.duration = -1.0
	var spawn: GE_SpawnMagicField = GE_SpawnMagicField.new()
	spawn.magic_field_data = data
	var result: GameplayEffectResult = spawn.apply(actor, actor, {"spawn_parent": actor, "projectile_impact": Vector3(1.0, 0.0, 2.0)})
	var spawned: MagicFieldBase = instance_from_id(result.outputs.get("spawned_node_id", 0)) as MagicFieldBase
	expect(result.did_apply() and is_instance_valid(spawned) and spawned.position == Vector3(1.0, 0.0, 2.0), "Spawn result must identify a real field with the requested position")
	actor.free()
	var body_a: CharacterBody3D = CharacterBody3D.new()
	var body_b: CharacterBody3D = CharacterBody3D.new()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(body_a)
	tree.root.add_child(body_b)
	var motion: GE_SingleFrameMotion = GE_SingleFrameMotion.new()
	motion.direction_type = GE_SingleFrameMotion.DirectionType.CUSTOM
	motion.ignore_gravity = true
	motion.distance = 2.0
	result = motion.apply(body_a, body_a, {"direction": Vector3.RIGHT})
	expect(result.did_apply() and (result.outputs["delta"] as Vector3).is_equal_approx(Vector3.RIGHT * 2.0), "Motion result must report real displacement")
	result = motion.apply(body_b, body_b, {"direction": Vector3.FORWARD})
	expect(result.did_apply() and body_a.position.is_equal_approx(Vector3.RIGHT * 2.0) and body_b.position.is_equal_approx(Vector3.FORWARD * 2.0), "Shared motion configuration must not reuse another target's direction")
	body_a.free()
	body_b.free()

func _target() -> Node:
	var actor: Node = Node.new()
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	component.name = "GameplayVitalAttributeComponent"
	actor.add_child(component)
	var maximum: GameplayAttribute = GameplayAttribute.new()
	maximum.attribute_id = &"max_health"
	var attributes: GameplayAttributeSet = GameplayAttributeSet.new()
	attributes.attributes[maximum] = 100.0
	component.initialize([attributes], [HealthVital.new()])
	return actor
