extends RegressionCase

class Hooks extends GameplayAbilityFeature:
	var cancellations: int = 0
	var completions: int = 0
	var forgotten: int = 0
	var cancel_note: String = ""
	var finish_on_activation: bool = false
	var free_actor_on_cancel: bool = false
	func on_activate(ability: GameplayAbilityInstance, _context: Dictionary) -> void:
		if finish_on_activation:
			ability.end_ability()
	func on_cancel(ability: GameplayAbilityInstance, context: Dictionary) -> void:
		cancellations += 1
		cancel_note = str(context.get("note", ""))
		ability.end_ability() # A terminal hook must not start another finalization.
		if free_actor_on_cancel:
			var actor: Node = context.get("instigator")
			actor.free()
	func on_completed(_ability: GameplayAbilityInstance) -> void:
		completions += 1
	func on_forgotten(_ability: GameplayAbilityInstance, _component: Node) -> void:
		forgotten += 1

class Preview extends AbilityPreviewStrategy:
	var active: bool = false
	func begin(_caster: Node, _ability: GameplayAbilityInstance, _context: Dictionary = {}) -> void:
		active = true
	func is_targeting() -> bool:
		return active
	func cancel() -> void:
		active = false

class CancelDuringTick extends RegressionBTProbe:
	func _tick(instance: GAS_BTInstance, delta: float) -> int:
		var status: int = super._tick(instance, delta)
		if ticks == 1:
			var ability: GameplayAbilityInstance = instance.blackboard.get_var("ability_instance")
			if ability.has_method("cancel"):
				ability.call("cancel", {"note": "during_tick"})
			else:
				ability.end_ability(GAS_BTNode.Status.FAILURE)
		return status

class ExitDuringTick extends RegressionBTProbe:
	func _tick(instance: GAS_BTInstance, delta: float) -> int:
		var status: int = super._tick(instance, delta)
		instance.agent.free()
		return status

class ForgetDuringTick extends RegressionBTProbe:
	func _tick(instance: GAS_BTInstance, delta: float) -> int:
		var status: int = super._tick(instance, delta)
		var context: Dictionary = instance.blackboard.get_var("context", {})
		var component: GameplayAbilityComponent = context.get("ability_component")
		component.forget_ability(&"forget_tick")
		return status

func run() -> void:
	_test_cancel_and_forget()
	_test_completion_reentry()
	_test_parallel_completion()
	_test_synchronous_completion()
	_test_tick_cancellation()
	_test_owner_exit()
	_test_forget_during_tick()
	_test_owner_exit_during_tick()
	_test_natural_failure()
	_test_component_reentry()
	_test_cancel_hook_frees_actor()
	_test_passive_status_survives_execution()

func _make_actor() -> Node:
	var actor: Node = Node.new()
	var component: GameplayAbilityComponent = GameplayAbilityComponent.new()
	actor.add_child(component)
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(actor)
	return actor

func _make_definition(id: StringName, tree: GAS_BTNode, hooks: Hooks = null) -> GameplayAbilityDefinition:
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.ability_id = id
	definition.execution_tree = tree
	if is_instance_valid(hooks):
		definition.features = [hooks]
	return definition

func _test_cancel_and_forget() -> void:
	var actor: Node = _make_actor()
	var component: GameplayAbilityComponent = actor.get_child(0) as GameplayAbilityComponent
	var wait: GAS_BTWaitSignal = GAS_BTWaitSignal.new()
	wait.timeout = -1.0
	var hooks: Hooks = Hooks.new()
	var definition: GameplayAbilityDefinition = _make_definition(&"wait", wait, hooks)
	definition.preview_strategy = Preview.new()
	var cooldown: CooldownFeature = CooldownFeature.new()
	definition.features.append(cooldown)
	component.learn_ability(definition)
	var ability: GameplayAbilityInstance = component.request_ability_preview(&"wait")
	expect(is_instance_valid(ability), "The preview fixture must start")
	component.try_activate_ability(&"wait")
	ability.update(0.0)
	var tree: GAS_BTInstance = ability.get_bt_instance()
	var blackboard: GAS_BTBlackboard = ability.get_blackboard()
	cooldown.start_cooldown(ability, 5.0)
	component.cancel_ability(&"wait", {"note": "player"})
	expect(ability.get_last_end_reason() == GameplayAbilityInstance.EndReason.CANCELLED, "Cancellation must have a distinct terminal reason")
	expect(hooks.cancellations == 1 and hooks.completions == 1 and hooks.cancel_note == "player", "Cancel must call both terminal hooks exactly once and forward context")
	expect(tree.get("_observers").is_empty() and blackboard.get_all_node_data().is_empty(), "Cancel must clear running nodes and listeners")
	expect(blackboard.get_all_vars().is_empty(), "Finish must release execution context, including its self reference")
	expect(cooldown.get_cooldown_remaining(ability) == 5.0, "Cancel must preserve already committed cooldown")
	expect(component.get_current_casting_ability() == null and not component.has_targeting_ability(), "Cancel must clear casting and preview references")
	component.cancel_ability(&"wait")
	expect(hooks.cancellations == 1 and hooks.completions == 1, "Cancelling an idle ability must not finish it twice")
	component.try_activate_ability(&"wait", {"skip_cooldown": true})
	ability.update(0.0)
	component.forget_ability(&"wait")
	expect(ability.is_disposed() and ability.get_last_end_reason() == GameplayAbilityInstance.EndReason.FORGOTTEN, "Forget must dispose the instance with its own reason")
	expect(hooks.cancellations == 2 and hooks.completions == 2 and hooks.forgotten == 1, "Forgetting an active ability must finish and remove learned effects once")
	expect(not ability.try_activate() and component.get_current_casting_ability() == null, "A forgotten instance must reject reactivation")
	expect(not is_instance_valid(tree.agent), "Disposal must release the behavior tree's actor reference")
	var weak_ability: WeakRef = weakref(ability)
	ability = null
	expect(weak_ability.get_ref() == null, "Forgotten ability must be releasable even when its former blackboard and tree are retained")
	actor.free()

func _test_completion_reentry() -> void:
	var actor: Node = _make_actor()
	var component: GameplayAbilityComponent = actor.get_child(0) as GameplayAbilityComponent
	var probe: RegressionBTProbe = RegressionBTProbe.new()
	component.learn_ability(_make_definition(&"repeat", probe))
	var ability: GameplayAbilityInstance = component.get_ability_instance(&"repeat")
	var notifications: Array[int] = []
	var callback: Callable = func(finished: GameplayAbilityInstance, _success: bool) -> void:
		notifications.append(1)
		if notifications.size() == 1:
			component.try_activate_ability(&"repeat")
			finished.update(0.0)
	component.ability_completed.connect(callback)
	component.try_activate_ability(&"repeat")
	ability.update(0.0)
	ability.end_ability()
	expect(ability.is_active and probe.enters == 2 and probe.exits == 1, "A completion callback must restart without the old execution resetting the new tree")
	expect(component.get_current_casting_ability() == ability, "The old component callback must not clear the restarted cast")
	component.ability_completed.disconnect(callback)
	actor.free()

func _test_parallel_completion() -> void:
	var actor: Node = _make_actor()
	var component: GameplayAbilityComponent = actor.get_child(0) as GameplayAbilityComponent
	component.learn_ability(_make_definition(&"a", RegressionBTProbe.new()))
	component.learn_ability(_make_definition(&"b", RegressionBTProbe.new()))
	var preview_definition: GameplayAbilityDefinition = _make_definition(&"preview", RegressionBTProbe.new())
	preview_definition.preview_strategy = Preview.new()
	component.learn_ability(preview_definition)
	var notifications: Array[GameplayAbilityInstance] = []
	var callback: Callable = func(ability: GameplayAbilityInstance, _success: bool) -> void:
		notifications.append(ability)
	component.ability_completed.connect(callback)
	component.try_activate_ability(&"a")
	component.try_activate_ability(&"b")
	var preview: GameplayAbilityInstance = component.request_ability_preview(&"preview")
	var ability_a: GameplayAbilityInstance = component.get_ability_instance(&"a")
	var ability_b: GameplayAbilityInstance = component.get_ability_instance(&"b")
	ability_a.end_ability()
	expect(notifications.size() == 1 and notifications[0] == ability_a, "A parallel ability must notify completion even when it is not the current cast")
	expect(component.get_current_casting_ability() == ability_b and component.get_current_targeting_ability() == preview, "Completion must not clear another cast or preview")
	component.forget_ability(&"preview")
	expect(not preview.is_targeting() and not component.has_targeting_ability(), "Forgetting a preview-only session must release it")
	component.ability_completed.disconnect(callback)
	actor.free()

func _test_synchronous_completion() -> void:
	var actor: Node = _make_actor()
	var component: GameplayAbilityComponent = actor.get_child(0) as GameplayAbilityComponent
	var hooks: Hooks = Hooks.new()
	hooks.finish_on_activation = true
	component.learn_ability(_make_definition(&"instant", RegressionBTProbe.new(), hooks))
	var accepted: bool = component.try_activate_ability(&"instant")
	var ability: GameplayAbilityInstance = component.get_ability_instance(&"instant")
	expect(accepted and not ability.is_active and hooks.completions == 1, "Completion from on_activate must not leave a permanently active execution")
	expect(component.get_current_casting_ability() == null, "Synchronous completion must not leave a stale current cast")
	actor.free()

func _test_tick_cancellation() -> void:
	var actor: Node = _make_actor()
	var component: GameplayAbilityComponent = actor.get_child(0) as GameplayAbilityComponent
	var probe: CancelDuringTick = CancelDuringTick.new()
	component.learn_ability(_make_definition(&"tick", probe))
	var ability: GameplayAbilityInstance = component.get_ability_instance(&"tick")
	var notifications: Array[int] = []
	var callback: Callable = func(finished: GameplayAbilityInstance, _success: bool) -> void:
		notifications.append(1)
		if notifications.size() == 1:
			component.try_activate_ability(&"tick")
			finished.update(0.0)
	component.ability_completed.connect(callback)
	component.try_activate_ability(&"tick")
	ability.update(0.0)
	expect(ability.is_active and probe.enters == 2 and probe.exits == 1, "Cancellation during tick must finish the old stack before a completion callback restarts")
	expect(ability.get_bt_instance().get_node_status(probe) == GAS_BTNode.Status.RUNNING, "The restarted tree must retain its own running state")
	component.ability_completed.disconnect(callback)
	actor.free()

func _test_owner_exit() -> void:
	var actor: Node = _make_actor()
	var component: GameplayAbilityComponent = actor.get_child(0) as GameplayAbilityComponent
	var hooks: Hooks = Hooks.new()
	var wait: GAS_BTWaitSignal = GAS_BTWaitSignal.new()
	wait.timeout = -1.0
	var definition: GameplayAbilityDefinition = _make_definition(&"exit", wait, hooks)
	definition.preview_strategy = Preview.new()
	component.learn_ability(definition)
	var ability: GameplayAbilityInstance = component.request_ability_preview(&"exit")
	component.try_activate_ability(&"exit")
	ability.update(0.0)
	var blackboard: GAS_BTBlackboard = ability.get_blackboard()
	var tree: GAS_BTInstance = ability.get_bt_instance()
	actor.free()
	expect(not ability.is_active and not ability.is_targeting(), "Owner exit must stop execution and preview")
	expect(hooks.cancellations == 1 and hooks.completions == 1 and hooks.forgotten == 1, "Owner exit must invoke terminal and forgotten hooks once")
	expect(tree.get("_observers").is_empty() and blackboard.get_all_vars().is_empty(), "Owner exit must release listeners and context")
	expect(not ability.try_activate(), "An instance retained by a caller must reject activation after owner exit")
	blackboard.clear() # Also release the legacy implementation after its expected failures.

func _test_forget_during_tick() -> void:
	var actor: Node = _make_actor()
	var component: GameplayAbilityComponent = actor.get_child(0) as GameplayAbilityComponent
	var hooks: Hooks = Hooks.new()
	var probe: ForgetDuringTick = ForgetDuringTick.new()
	component.learn_ability(_make_definition(&"forget_tick", probe, hooks))
	var ability: GameplayAbilityInstance = component.get_ability_instance(&"forget_tick")
	var notifications: Array[int] = []
	var callback: Callable = func(_ability: GameplayAbilityInstance, _success: bool) -> void:
		notifications.append(1)
	component.ability_completed.connect(callback)
	component.try_activate_ability(&"forget_tick")
	ability.update(0.0)
	expect(ability.is_disposed() and not ability.is_active and probe.exits == 1, "Forget during tick must clean up only after the old node returns")
	expect(notifications.size() == 1 and hooks.forgotten == 1, "Deferred forget must still notify component completion and remove learned effects once")
	component.ability_completed.disconnect(callback)
	actor.free()

func _test_owner_exit_during_tick() -> void:
	var actor: Node = _make_actor()
	var component: GameplayAbilityComponent = actor.get_child(0) as GameplayAbilityComponent
	var hooks: Hooks = Hooks.new()
	var probe: ExitDuringTick = ExitDuringTick.new()
	component.learn_ability(_make_definition(&"exit_tick", probe, hooks))
	var ability: GameplayAbilityInstance = component.get_ability_instance(&"exit_tick")
	component.try_activate_ability(&"exit_tick")
	ability.update(0.0)
	expect(ability.is_disposed() and not ability.is_active and probe.exits == 1, "Owner exit during tick must not destroy the executing tree until its stack returns")
	expect(hooks.cancellations == 1 and hooks.completions == 1 and hooks.forgotten == 1, "Owner exit during tick must not lose the forgotten hook when the component has already been freed")
	expect(ability.get_last_end_reason() == GameplayAbilityInstance.EndReason.OWNER_EXIT, "Owner exit must retain its terminal reason")

func _test_natural_failure() -> void:
	var actor: Node = _make_actor()
	var component: GameplayAbilityComponent = actor.get_child(0) as GameplayAbilityComponent
	var hooks: Hooks = Hooks.new()
	var probe: RegressionBTProbe = RegressionBTProbe.new()
	probe.result = GAS_BTNode.Status.FAILURE
	component.learn_ability(_make_definition(&"failure", probe, hooks))
	component.try_activate_ability(&"failure")
	var ability: GameplayAbilityInstance = component.get_ability_instance(&"failure")
	ability.update(0.0)
	expect(hooks.cancellations == 0 and hooks.completions == 1, "Natural failure must finish once without being reported as cancellation")
	expect(ability.get_last_end_reason() == GameplayAbilityInstance.EndReason.FAILED, "Natural failure must have its own terminal reason")
	actor.free()

func _test_component_reentry() -> void:
	var actor: Node = _make_actor()
	var component: GameplayAbilityComponent = actor.get_child(0) as GameplayAbilityComponent
	var definition: GameplayAbilityDefinition = _make_definition(&"reenter", RegressionBTProbe.new())
	component.learn_ability(definition)
	var previous: GameplayAbilityInstance = component.get_ability_instance(&"reenter")
	actor.remove_child(component)
	expect(previous.is_disposed() and not component.has_ability(&"reenter"), "Leaving the tree must dispose learned sessions")
	actor.add_child(component)
	component.learn_ability(definition)
	expect(component.try_activate_ability(&"reenter"), "A reentered component can explicitly learn and activate a fresh instance")
	expect(component.get_ability_instance(&"reenter") != previous, "Reentry must not revive a disposed session")
	actor.free()

func _test_cancel_hook_frees_actor() -> void:
	var actor: Node = _make_actor()
	var component: GameplayAbilityComponent = actor.get_child(0) as GameplayAbilityComponent
	var hooks: Hooks = Hooks.new()
	hooks.free_actor_on_cancel = true
	component.learn_ability(_make_definition(&"free_callback", RegressionBTProbe.new(), hooks))
	var ability: GameplayAbilityInstance = component.get_ability_instance(&"free_callback")
	component.try_activate_ability(&"free_callback")
	component.cancel_ability(&"free_callback")
	expect(ability.is_disposed() and hooks.completions == 1 and hooks.forgotten == 1, "A cancellation hook can free the actor without a second finish or access to a freed component")

func _test_passive_status_survives_execution() -> void:
	var actor: Node = _make_actor()
	var component: GameplayAbilityComponent = actor.get_child(0) as GameplayAbilityComponent
	var status_component: GameplayStatusComponent = GameplayStatusComponent.new()
	status_component.name = "GameplayStatusComponent"
	actor.add_child(status_component)
	var status: GameplayStatusData = GameplayStatusData.new()
	status.status_id = &"learned_status"
	status.duration_policy = null # This case checks learned ownership, not duration-policy retention.
	var passive: PassiveStatusFeature = PassiveStatusFeature.new()
	passive.statuses[status] = 1
	var definition: GameplayAbilityDefinition = _make_definition(&"passive_active", RegressionBTProbe.new())
	definition.features = [passive]
	component.learn_ability(definition)
	expect(status_component.has_status(status.status_id), "Learning must apply the passive fixture")
	component.try_activate_ability(definition.ability_id)
	component.cancel_ability(definition.ability_id)
	expect(status_component.has_status(status.status_id), "Cancelling execution must preserve learned passive effects")
	component.forget_ability(definition.ability_id)
	expect(not status_component.has_status(status.status_id), "Forgetting after an execution must still remove its learned passive effect")
	status_component.remove_status(status.status_id) # Release the fixture after expected failures too.
	actor.free()
