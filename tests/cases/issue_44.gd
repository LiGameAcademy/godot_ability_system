extends RegressionCase

class DefinitionWatcher extends GameplayAbilityFeature:
	var template_was_changed: bool = false

	func initialize(ability: GameplayAbilityInstance) -> void:
		template_was_changed = is_instance_valid(ability.get_definition().execution_tree)

func run() -> void:
	var actor: Node = Node.new()
	var definition: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	definition.pre_cast_delay = 1.0
	var watcher: DefinitionWatcher = DefinitionWatcher.new()
	definition.features.append(watcher)
	var first: GameplayAbilityInstance = definition.create_instance(actor)
	definition.pre_cast_delay = 2.0
	var second: GameplayAbilityInstance = definition.create_instance(actor)
	var first_tree: GAS_BTSequence = first.get_bt_instance().tree_root as GAS_BTSequence
	var second_tree: GAS_BTSequence = second.get_bt_instance().tree_root as GAS_BTSequence
	expect(not watcher.template_was_changed, "Instance initialization must never temporarily rewrite definition")
	expect(first_tree != second_tree, "New instance recompiles current quick configuration")
	expect((first_tree.children[0] as GAS_BTWait).duration == 1.0, "Existing instance keeps compiled timing")
	expect((second_tree.children[0] as GAS_BTWait).duration == 2.0, "Next instance sees new timing")
	_release(first)
	_release(second)
	definition.pre_cast_delay = -2.0
	var invalid: GameplayAbilityInstance = definition.create_instance(actor)
	expect(not is_instance_valid(invalid), "Invalid quick configuration fails instance creation")
	expect(definition.pre_cast_delay == -2.0, "Validation must not silently repair shared configuration")
	_release(invalid)
	var missing: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	var no_flow: GameplayAbilityInstance = missing.create_instance(actor)
	expect(not no_flow.can_activate(), "Missing flow is also unavailable to UI queries")
	expect(not no_flow.try_activate() and not no_flow.is_active, "Missing flow cannot become permanently active")
	_release(no_flow)
	var conflicting: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	conflicting.cooldown_duration = 3.0
	conflicting.features.append(CooldownFeature.new())
	var conflict_instance: GameplayAbilityInstance = conflicting.create_instance(actor)
	expect(not is_instance_valid(conflict_instance), "Quick and explicit cooldown cannot silently shadow each other")
	_release(conflict_instance)
	var projectile: ProjectileAbilityDefinition = ProjectileAbilityDefinition.new()
	projectile.projectile_count = 0
	var projectile_instance: GameplayAbilityInstance = projectile.create_instance(actor)
	expect(not is_instance_valid(projectile_instance), "Invalid projectile settings fail creation")
	expect(projectile.projectile_count == 0, "Projectile validation leaves original values intact")
	_release(projectile_instance)
	_check_toggle_and_combo(actor)
	definition.pre_cast_delay = NAN
	expect(not definition.get_configuration_errors().is_empty(), "Non-finite settings are rejected")
	expect(is_nan(definition.pre_cast_delay), "Checking NaN does not repair the template")
	actor.free()

func _check_toggle_and_combo(actor: Node) -> void:
	var toggle: ToggleAbilityDefinition = ToggleAbilityDefinition.new()
	toggle.pre_cast_delay = 1.0
	var first: GameplayAbilityInstance = toggle.create_instance(actor)
	toggle.pre_cast_delay = 3.0
	var second: GameplayAbilityInstance = toggle.create_instance(actor)
	expect(first.get_bt_instance().tree_root != second.get_bt_instance().tree_root, "Toggle recompiles configuration")
	_release(first)
	_release(second)
	var step: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	step.pre_cast_delay = 0.5
	var combo: ComboAbilityDefinition = ComboAbilityDefinition.new()
	combo.combo_steps.append(step)
	first = combo.create_instance(actor)
	step.pre_cast_delay = 1.0
	second = combo.create_instance(actor)
	expect(first.get_bt_instance().tree_root != second.get_bt_instance().tree_root, "Combo recompiles its steps")
	_release(first)
	_release(second)
	var sacrifice: SacrificeAbilityDefinition = SacrificeAbilityDefinition.new()
	sacrifice.periodic_interval = -1.0
	var invalid: GameplayAbilityInstance = sacrifice.create_instance(actor)
	expect(not is_instance_valid(invalid) and sacrifice.periodic_interval == -1.0, "Sacrifice also validates without repair")
	_release(invalid)

func _release(ability: GameplayAbilityInstance) -> void:
	if is_instance_valid(ability):
		ability.is_active = false
		ability.get_blackboard().clear()
