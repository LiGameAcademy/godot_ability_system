extends RegressionCase

class LegacyCost extends AbilityCostBase:
	var payments: int = 0
	func _can_pay(_component: Node, _instigator: Node) -> bool:
		return true
	func _try_pay(_component: Node, _instigator: Node) -> bool:
		payments += 1
		return true

func run() -> void:
	_test_late_payment_failure()
	_test_repeated_legacy_nodes()
	_test_atomic_observation_and_cancellation()
	_test_new_execution_and_state_copy()
	_test_commit_before_and_after_cancel()
	_test_staged_templates()
	_test_owner_exit_in_notification()
	_test_custom_cost_contract()
	_test_explicit_features_and_free_ability()
	_test_feature_alias()

func _test_late_payment_failure() -> void:
	var actor: Node = Node.new()
	var vitals: GameplayVitalAttributeComponent = _attach_vital(actor)
	var definition: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	definition.pre_cast_delay = 10.0
	definition.cooldown_duration = 5.0
	definition.costs = [_cost()]
	var ability: GameplayAbilityInstance = definition.create_instance(actor)
	var context: Dictionary = {"instigator": actor, "ability_component": actor}
	expect(ability.try_activate(context), "Initial qualification must succeed")
	ability.update(0.0)
	vitals.modify_vital(&"mana", -95.0)
	var root: GAS_BTSequence = ability.get_bt_instance().tree_root as GAS_BTSequence
	for node: GAS_BTNode in root.children:
		if node is GAS_BTWait:
			ability.get_blackboard().set_node_data(node, 0.0)
	ability.update(0.0)
	var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
	expect(vitals.get_vital_value(&"mana") == 5.0, "Late failure must not charge mana")
	expect(cooldown.get_cooldown_remaining(ability) == 0.0, "Late payment failure must not start cooldown")
	expect(not ability.is_active and ability.get_last_end_reason() == GameplayAbilityInstance.EndReason.FAILED, "Failed commitment must stop execution")
	ability.dispose()
	actor.free()

func _holding_definition() -> ActiveAbilityDefinition:
	var definition: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	definition.execution_tree = RegressionBTProbe.new()
	definition.costs = [_cost()]
	definition.cooldown_duration = 5.0
	return definition

func _test_atomic_observation_and_cancellation() -> void:
	var actor: Node = Node.new()
	var vitals: GameplayVitalAttributeComponent = _attach_vital(actor)
	var ability: GameplayAbilityInstance = _holding_definition().create_instance(actor)
	var context: Dictionary = {"instigator": actor, "ability_component": actor}
	ability.try_activate(context)
	var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
	var observations: Array[bool] = []
	ability.ability_data_changed.connect(func(current: GameplayAbilityInstance) -> void:
		observations.append(vitals.get_vital_value(&"mana") == 90.0 and cooldown.get_cooldown_remaining(current) == 5.0)
		expect(current.get_commit_state()["costs"].has("CostFeature"), "Commit record must exist before data notification")
		expect(current.try_commit(context), "Reentrant repeated commit must acknowledge the existing result")
		expect(not current.try_activate(context), "Notifications must not start a new execution inside commit")
		current.update(1.0)
	)
	var completions: Array[bool] = []
	ability.ability_completed.connect(func(_success: bool) -> void: completions.append(true))
	vitals.vital_value_changed.connect(func(_id: StringName, _value: float, _max: float, _percent: float, _regen: bool) -> void:
		expect(cooldown.get_cooldown_remaining(ability) == 5.0, "Vital notification must see committed cooldown")
		ability.cancel()
		expect(completions.is_empty(), "Cancellation must finish after all commit notifications")
	)
	expect(ability.try_commit(context), "Atomic commit must report successful payment even if a notification cancels execution")
	expect(observations == [true] and completions.size() == 1, "Commit must notify once and then finish cancellation once")
	expect(vitals.get_vital_value(&"mana") == 90.0 and cooldown.get_cooldown_remaining(ability) == 5.0, "Post-commit cancellation must not refund or reset cooldown")
	expect(not ability.is_active, "Cancellation from a commit notification must stop execution")
	ability.dispose()
	actor.free()

func _test_new_execution_and_state_copy() -> void:
	var actor: Node = Node.new()
	var vitals: GameplayVitalAttributeComponent = _attach_vital(actor)
	var ability: GameplayAbilityInstance = _holding_definition().create_instance(actor)
	var context: Dictionary = {"instigator": actor, "ability_component": actor}
	ability.try_activate(context)
	expect(ability.try_commit(), "Default commit context must use this execution's stored context")
	var snapshot: Dictionary = ability.get_commit_state()
	snapshot["costs"].clear()
	expect(ability.try_commit(context) and vitals.get_vital_value(&"mana") == 90.0, "State snapshot mutation must not clear authoritative commit record")
	ability.cancel()
	ability.update(5.0)
	expect(ability.try_activate(context), "A fresh execution can start after cooldown")
	expect(ability.get_commit_state()["costs"].is_empty(), "Fresh execution must start with fresh commit records")
	expect(ability.try_commit(context) and vitals.get_vital_value(&"mana") == 80.0, "Fresh execution must pay its own cost once")
	ability.dispose()
	actor.free()

func _test_explicit_features_and_free_ability() -> void:
	var actor: Node = Node.new()
	var vitals: GameplayVitalAttributeComponent = _attach_vital(actor)
	var definition: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	var cost: CostFeature = CostFeature.new()
	cost.costs = [_cost()]
	var cooldown: CooldownFeature = CooldownFeature.new()
	cooldown.cooldown_duration = 5.0
	definition.features = [cost, cooldown]
	var ability: GameplayAbilityInstance = definition.create_instance(actor)
	ability.try_activate({"instigator": actor, "ability_component": actor})
	ability.update(0.0)
	expect(vitals.get_vital_value(&"mana") == 90.0 and cooldown.get_cooldown_remaining(ability) == 5.0, "Explicit canonical Features must commit even when quick config fields are empty")
	ability.dispose()
	definition = ActiveAbilityDefinition.new()
	definition.execution_tree = RegressionBTProbe.new()
	ability = definition.create_instance(actor)
	ability.try_activate()
	expect(ability.try_commit(), "Missing default cost and cooldown Features represent a free ability")
	ability.dispose()
	actor.free()

func _test_commit_before_and_after_cancel() -> void:
	var actor: Node = Node.new()
	var vitals: GameplayVitalAttributeComponent = _attach_vital(actor)
	var ability: GameplayAbilityInstance = _holding_definition().create_instance(actor)
	var context: Dictionary = {"instigator": actor, "ability_component": actor}
	var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
	expect(not ability.try_commit(context), "Idle ability must not commit")
	ability.try_activate(context)
	ability.cancel()
	expect(not ability.try_commit(context), "Cancelled uncommitted execution must not pay")
	expect(vitals.get_vital_value(&"mana") == 100.0 and cooldown.get_cooldown_remaining(ability) == 0.0, "Pre-commit cancellation must leave resources and cooldown unchanged")
	ability.try_activate(context)
	expect(not ability.try_commit(context, true, true, "MissingCost"), "Misspelled custom feature name must fail")
	expect(vitals.get_vital_value(&"mana") == 100.0, "Missing custom feature must not charge another feature")
	ability.dispose()
	actor.free()

func _test_staged_templates() -> void:
	var actor: Node = Node.new()
	var vitals: GameplayVitalAttributeComponent = _attach_vital(actor)
	var context: Dictionary = {"instigator": actor, "ability_component": actor}
	var step: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	var step_root: GAS_BTSequence = GAS_BTSequence.new()
	var custom_commit: AbilityNodeCommit = AbilityNodeCommit.new()
	var hold: RegressionBTProbe = RegressionBTProbe.new()
	step_root.children = [custom_commit, hold]
	step.execution_tree = step_root
	var combo: ComboAbilityDefinition = ComboAbilityDefinition.new()
	combo.combo_steps = [step]
	combo.costs = [_cost()]
	combo.cooldown_duration = 5.0
	var ability: GameplayAbilityInstance = combo.create_instance(actor)
	var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
	ability.try_activate(context)
	ability.update(0.0)
	expect(vitals.get_vital_value(&"mana") == 90.0 and cooldown.get_cooldown_remaining(ability) == 0.0, "Combo must pay at start and defer cooldown, including custom unified step node")
	expect(custom_commit.start_cooldown, "Combo must not rewrite the original step template")
	# 修改复制后的运行节点，使这一段完成，不依赖真实时间或输入。
	_finish_probes(ability.get_bt_instance().tree_root)
	ability.update(0.0)
	expect(not ability.is_active and cooldown.get_cooldown_remaining(ability) == 5.0, "Combo completion must start cooldown at its original end stage")
	ability.dispose()
	var toggle: ToggleAbilityDefinition = ToggleAbilityDefinition.new()
	toggle.costs = [_cost()]
	toggle.cooldown_duration = 5.0
	ability = toggle.create_instance(actor)
	cooldown = ability.get_feature("CooldownFeature") as CooldownFeature
	ability.try_activate(context)
	ability.update(0.0)
	expect(vitals.get_vital_value(&"mana") == 80.0 and cooldown.get_cooldown_remaining(ability) == 0.0, "Toggle opening must pay without starting cooldown")
	ability.try_activate(context)
	ability.update(0.0)
	expect(vitals.get_vital_value(&"mana") == 80.0 and cooldown.get_cooldown_remaining(ability) == 5.0, "Toggle closing must start cooldown without charging again")
	ability.dispose()
	actor.free()

func _finish_probes(node: GAS_BTNode) -> void:
	if node is RegressionBTProbe:
		(node as RegressionBTProbe).result = GAS_BTNode.Status.SUCCESS
	elif node is GAS_BTComposite:
		for child: GAS_BTNode in (node as GAS_BTComposite).children:
			_finish_probes(child)
	elif node is GAS_BTDecorator:
		_finish_probes((node as GAS_BTDecorator).child)

func _test_owner_exit_in_notification() -> void:
	var actor: Node = Node.new()
	var vitals: GameplayVitalAttributeComponent = _attach_vital(actor)
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	actor.add_child(component)
	var definition: ActiveAbilityDefinition = _holding_definition()
	definition.ability_id = &"commit_owner_exit"
	component.learn_ability(definition)
	var ability: GameplayAbilityInstance = component.get_ability_instance(definition.ability_id)
	var context: Dictionary = {"instigator": actor, "ability_component": component}
	ability.try_activate(context)
	vitals.vital_value_changed.connect(func(_id: StringName, _value: float, _max: float, _percent: float, _regen: bool) -> void: actor.free())
	expect(ability.try_commit(context), "Owner exit during notification must not undo an already committed payment")
	expect(ability.is_disposed() and not is_instance_valid(actor), "Owner exit must complete disposal after commit notifications")
	expect(not ability.try_commit(context), "Disposed instance must not accept another commitment")

func _test_custom_cost_contract() -> void:
	var actor: Node = Node.new()
	var legacy: LegacyCost = LegacyCost.new()
	var cost: CostFeature = CostFeature.new()
	cost.costs = [legacy]
	var cooldown: CooldownFeature = CooldownFeature.new()
	cooldown.cooldown_duration = 5.0
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.features = [cost, cooldown]
	definition.execution_tree = RegressionBTProbe.new()
	var ability: GameplayAbilityInstance = definition.create_instance(actor)
	var context: Dictionary = {"instigator": actor, "ability_component": actor}
	ability.try_activate(context)
	expect(not ability.try_commit(context) and legacy.payments == 0, "Legacy external payment cannot join an atomic cooldown commit")
	expect(cost.try_pay(ability, context), "Single legacy cost can still use its explicit cost-only stage")
	expect(cost.try_pay(ability, context) and legacy.payments == 1, "Legacy cost-only API must use the same execution record")
	expect(ability.try_commit(context, false, true), "Explicit later cooldown stage must remain supported")
	ability.dispose()
	actor.free()

func _test_repeated_legacy_nodes() -> void:
	var actor: Node = Node.new()
	var vitals: GameplayVitalAttributeComponent = _attach_vital(actor)
	var cost: CostFeature = CostFeature.new()
	cost.costs = [_cost()]
	var cooldown: CooldownFeature = CooldownFeature.new()
	cooldown.cooldown_duration = 5.0
	var root: GAS_BTSequence = GAS_BTSequence.new()
	root.children = [AbilityNodeCommitCost.new(), AbilityNodeCommitCooldown.new(), RegressionBTProbe.new()]
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.execution_tree = root
	definition.features = [cost, cooldown]
	var ability: GameplayAbilityInstance = definition.create_instance(actor)
	var context: Dictionary = {"instigator": actor, "ability_component": actor}
	expect(ability.try_activate(context), "Legacy tree must activate")
	ability.update(0.0)
	expect(vitals.get_vital_value(&"mana") == 90.0, "First entry must pay once")
	ability.get_bt_instance().reset_tree()
	ability.update(1.0)
	expect(vitals.get_vital_value(&"mana") == 90.0, "Resetting BT progress must not repeat payment within one execution")
	expect(cooldown.get_cooldown_remaining(ability) == 4.0, "Repeated cooldown node must not restart the timer")
	ability.dispose()
	actor.free()

func _cost() -> VitalCost:
	var cost: VitalCost = VitalCost.new()
	cost.amount = 10.0
	return cost

func _test_feature_alias() -> void:
	var actor: Node = Node.new()
	var vitals: GameplayVitalAttributeComponent = _attach_vital(actor)
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.execution_tree = RegressionBTProbe.new()
	var ability: GameplayAbilityInstance = definition.create_instance(actor)
	var cost: CostFeature = CostFeature.new()
	cost.costs = [_cost()]
	ability.add_feature("ManaPayment", cost)
	var context: Dictionary = {"instigator": actor, "ability_component": actor}
	ability.try_activate(context)
	expect(cost.try_pay(ability, context), "Cost API must find the actual registered Feature alias")
	expect(ability.try_commit(context, true, false, "ManaPayment"), "Custom-named node and cost API must share one commit record")
	expect(vitals.get_vital_value(&"mana") == 90.0, "Alias must charge exactly once")
	var unattached: CostFeature = CostFeature.new()
	unattached.costs = [_cost()]
	expect(not unattached.try_pay(ability, context), "Unregistered Feature must not silently commit a free default stage")
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
