extends RegressionCase

class BlockedFeature extends GameplayAbilityFeature:
	func _init() -> void:
		super("BlockedFeature")
	func can_activate(_ability: GameplayAbilityInstance, _context: Dictionary) -> bool:
		return false

func run() -> void:
	_test_requests_and_readonly_queries()
	_test_rejection_reasons()
	_test_payment_failure_and_recovery()
	_test_terminal_reasons_and_retained_commit()
	_test_completion_restart()
	_test_reentrant_request_does_not_change_execution()

func _holding(actor: Node) -> GameplayAbilityInstance:
	var definition: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	definition.execution_tree = RegressionBTProbe.new()
	return definition.create_instance(actor)

func _test_requests_and_readonly_queries() -> void:
	var actor: Node = Node.new()
	var ability: GameplayAbilityInstance = _holding(actor)
	var context: Dictionary = {"nested": {"count": 1}}
	var original: Dictionary = context.duplicate(true)
	var query: AbilityResult = ability.check_activation(context)
	expect(query.status == AbilityResult.Status.READY and not query.is_accepted(), "Query readiness must not mean an execution was accepted")
	expect(ability.get_execution_result().status == AbilityResult.Status.IDLE and not ability.is_active, "Query must not start an execution")
	query.status = AbilityResult.Status.FAILED
	expect(ability.can_activate(context) and context == original, "Mutating query result must not change state or context")
	var start: AbilityResult = ability.try_activate_result(context)
	var input: AbilityResult = ability.try_activate_result(context)
	expect(start.status == AbilityResult.Status.STARTED and input.status == AbilityResult.Status.INPUT_RECEIVED, "New execution and subsequent input must be distinguishable")
	expect(start.is_accepted() and input.is_accepted() and start.execution_id == input.execution_id, "Both requests are accepted by the same execution")
	expect(ability.get_execution_result().status == AbilityResult.Status.RUNNING, "Accepted input must not mean completion")
	expect(ability.try_activate(context), "Legacy bool API must continue to acknowledge input")
	ability.cancel()
	expect(ability.get_last_execution_result().status == AbilityResult.Status.CANCELLED, "Cancellation must have its own terminal result")
	ability.dispose()
	actor.free()

func _test_rejection_reasons() -> void:
	var actor: Node = Node.new()
	var ability: GameplayAbilityInstance = _holding(actor)
	ability.disabled = true
	expect(ability.check_activation().failure_reason == AbilityResult.FailureReason.DISABLED, "Disabled query must explain rejection")
	expect(not ability.try_activate_result().is_accepted() and not ability.is_active, "Disabled request must not start an execution")
	ability.disabled = false
	ability.add_feature("BusinessRule", BlockedFeature.new())
	var result: AbilityResult = ability.try_activate_result()
	expect(result.failure_reason == AbilityResult.FailureReason.FEATURE_BLOCKED and result.feature_name == "BusinessRule", "Custom rejection must identify its actual registration key")
	ability.dispose()
	expect(ability.try_activate_result().failure_reason == AbilityResult.FailureReason.DISPOSED, "Disposed request must have a distinct cause")
	var empty: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	ability = GameplayAbilityInstance.new(actor, empty)
	expect(ability.check_activation().failure_reason == AbilityResult.FailureReason.INVALID_CONFIGURATION, "Missing execution tree must report configuration failure")
	ability.dispose()
	var cooldown: CooldownFeature = CooldownFeature.new()
	cooldown.cooldown_duration = 5.0
	ability = _holding(actor)
	ability.add_feature("Timer", cooldown)
	cooldown.start_cooldown(ability)
	result = ability.check_activation()
	expect(result.failure_reason == AbilityResult.FailureReason.COOLDOWN and result.feature_name == "Timer", "Cooldown rejection must be distinguishable from other features")
	ability.dispose()
	actor.free()

func _test_payment_failure_and_recovery() -> void:
	var actor: Node = Node.new()
	var vitals: GameplayVitalAttributeComponent = _attach_vital(actor)
	var cost: VitalCost = VitalCost.new()
	cost.amount = 10.0
	var definition: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	definition.costs = [cost]
	definition.cooldown_duration = 5.0
	definition.pre_cast_delay = 10.0
	var ability: GameplayAbilityInstance = definition.create_instance(actor)
	var context: Dictionary = {"instigator": actor, "ability_component": actor}
	ability.try_activate_result(context)
	ability.update(0.0)
	vitals.modify_vital(&"mana", -95.0)
	var root: GAS_BTSequence = ability.get_bt_instance().tree_root as GAS_BTSequence
	for node: GAS_BTNode in root.children:
		if node is GAS_BTWait:
			ability.get_blackboard().set_node_data(node, 0.0)
	ability.update(0.0)
	var result: AbilityResult = ability.get_last_execution_result()
	expect(result.status == AbilityResult.Status.FAILED and result.failure_reason == AbilityResult.FailureReason.COST, "Late payment failure must retain its cause after BT reset")
	expect(result.feature_name == "CostFeature" and result.costs.is_empty() and result.cooldowns.is_empty(), "Failed commit must not look committed")
	var rejected: AbilityResult = ability.try_activate_result(context)
	expect(rejected.failure_reason == AbilityResult.FailureReason.COST, "Qualification failure must be distinguishable from execution failure")
	expect(ability.get_last_execution_result().execution_id == result.execution_id, "Rejected request must preserve the previous terminal result")
	ability.dispose()
	ability = _holding(actor)
	ability.try_activate_result()
	expect(not ability.try_commit({}, true, false, "Typo"), "Wrong Feature name must fail")
	expect(ability.get_execution_result().failure_reason == AbilityResult.FailureReason.INVALID_CONFIGURATION, "Commit configuration failure must be available during execution")
	expect(ability.try_commit(), "A later valid stage can recover")
	ability.end_ability(GAS_BTNode.Status.SUCCESS)
	result = ability.get_last_execution_result()
	expect(result.status == AbilityResult.Status.COMPLETED and result.failure_reason == AbilityResult.FailureReason.NONE, "Recovered branch must not report the earlier attempt as terminal failure")
	ability.dispose()
	var failed_stage: AbilityNodeCommitCost = AbilityNodeCommitCost.new()
	failed_stage.cost_feature_name = "Typo"
	var recovered: RegressionBTProbe = RegressionBTProbe.new()
	recovered.result = GAS_BTNode.Status.SUCCESS
	var fallback: GAS_BTSelector = GAS_BTSelector.new()
	fallback.children = [failed_stage, recovered]
	definition = ActiveAbilityDefinition.new()
	definition.execution_tree = fallback
	ability = definition.create_instance(actor)
	ability.try_activate_result(context)
	ability.update(0.0)
	result = ability.get_last_execution_result()
	expect(result.status == AbilityResult.Status.COMPLETED and result.failure_reason == AbilityResult.FailureReason.NONE, "Actual BT fallback must retain its existing control flow")
	expect(result.costs.is_empty(), "Successful fallback must not invent a commit for the failed stage")
	ability.dispose()
	actor.free()

func _test_terminal_reasons_and_retained_commit() -> void:
	var actor: Node = Node.new()
	var ability: GameplayAbilityInstance = _holding(actor)
	ability.try_activate_result()
	expect(ability.try_commit(), "Free stages can be committed")
	ability.get_bt_instance().reset_tree()
	var result: AbilityResult = ability.get_execution_result()
	expect(result.costs == ["CostFeature"] and result.cooldowns == ["CooldownFeature"], "BT reset must preserve result commit stages")
	result.costs.clear()
	expect(ability.get_execution_result().costs == ["CostFeature"], "Result arrays must be snapshots")
	ability.cancel()
	result = ability.get_last_execution_result()
	expect(result.status == AbilityResult.Status.CANCELLED and result.costs == ["CostFeature"], "Cancellation must preserve completed stages")
	ability.try_activate_result()
	expect(ability.get_execution_result().costs.is_empty() and ability.get_last_execution_result().execution_id == result.execution_id, "Fresh execution must retain the old terminal snapshot separately")
	ability.end_ability(GAS_BTNode.Status.FAILURE)
	result = ability.get_last_execution_result()
	expect(result.status == AbilityResult.Status.FAILED and result.failure_reason == AbilityResult.FailureReason.EXECUTION_FAILED, "Unknown BT failure must stay generic rather than invent a business cause")
	ability.dispose()
	ability = _holding(actor)
	ability.try_activate_result()
	ability.dispose(actor, GameplayAbilityInstance.EndReason.FORGOTTEN)
	expect(ability.get_last_execution_result().status == AbilityResult.Status.FORGOTTEN, "Forget must retain a distinct terminal result")
	ability = _holding(actor)
	ability.try_activate_result()
	ability.dispose(actor, GameplayAbilityInstance.EndReason.OWNER_EXIT)
	expect(ability.get_last_execution_result().status == AbilityResult.Status.OWNER_EXIT, "Owner exit must retain a distinct terminal result")
	actor.free()

func _test_completion_restart() -> void:
	var actor: Node = Node.new()
	var ability: GameplayAbilityInstance = _holding(actor)
	var first: AbilityResult = ability.try_activate_result()
	var events: Array[AbilityResult] = []
	var restart: Callable = func(_success: bool) -> void: ability.try_activate_result()
	ability.ability_completed.connect(restart)
	ability.ability_finished.connect(func(result: AbilityResult) -> void: events.append(result))
	ability.end_ability()
	expect(ability.is_active and ability.get_execution_result().execution_id == first.execution_id + 1, "Legacy completion callback must still restart")
	expect(events.size() == 1 and events[0].execution_id == first.execution_id and events[0].status == AbilityResult.Status.COMPLETED, "Detailed event must describe the finished execution even after callback restart")
	events[0].status = AbilityResult.Status.FAILED
	expect(ability.get_last_execution_result().status == AbilityResult.Status.COMPLETED, "Event mutation must not rewrite history")
	ability.ability_completed.disconnect(restart)
	ability.dispose()
	actor.free()

func _test_reentrant_request_does_not_change_execution() -> void:
	var actor: Node = Node.new()
	var ability: GameplayAbilityInstance = _holding(actor)
	var cooldown: CooldownFeature = CooldownFeature.new()
	cooldown.cooldown_duration = 5.0
	ability.add_feature("CooldownFeature", cooldown)
	ability.try_activate_result()
	ability.ability_data_changed.connect(func(current: GameplayAbilityInstance) -> void:
		expect(current.try_activate_result().failure_reason == AbilityResult.FailureReason.BUSY, "Activation during commit must explain the busy state")
		expect(not current.try_commit({}, true, false, "AnotherStage"), "New stage during commit must be rejected")
		current.cancel()
		expect(current.get_execution_result().status == AbilityResult.Status.FINISHING, "Deferred cancellation must distinguish finishing from running")
	)
	expect(ability.try_commit(), "Rejected nested requests must not turn outer payment into failure")
	var result: AbilityResult = ability.get_last_execution_result()
	expect(result.status == AbilityResult.Status.CANCELLED and result.failure_reason == AbilityResult.FailureReason.NONE, "Rejected nested request must not replace terminal cancellation")
	expect(result.costs == ["CostFeature"] and result.cooldowns == ["CooldownFeature"], "Terminal result must include the completed outer commit")
	ability.dispose()
	actor.free()

func _attach_vital(actor: Node) -> GameplayVitalAttributeComponent:
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	component.name = "GameplayVitalAttributeComponent"
	actor.add_child(component)
	var maximum: GameplayAttribute = GameplayAttribute.new()
	maximum.attribute_id = &"max_mana"
	var attributes: GameplayAttributeSet = GameplayAttributeSet.new()
	attributes.attributes[maximum] = 100.0
	component.initialize([attributes], [ManaVital.new()])
	return component
