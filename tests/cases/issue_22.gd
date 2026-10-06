extends RegressionCase

class SignalDuringTick extends RegressionBTProbe:
	func _tick(instance: GAS_BTInstance, delta: float) -> int:
		var status: int = super._tick(instance, delta)
		instance.blackboard.set_var("allowed", false)
		return status

func run() -> void:
	_check_self_abort()
	_check_priority_abort()
	_check_tick_reentry()

func _observer(child: GAS_BTNode, mode: GAS_BTObserver.AbortType) -> GAS_BTCheckVarDecorator:
	var observer: GAS_BTCheckVarDecorator = GAS_BTCheckVarDecorator.new()
	observer.key = "allowed"
	observer.value = true
	observer.child = child
	observer.abort_type = mode
	return observer

func _check_self_abort() -> void:
	var actor: Node = Node.new()
	var action: RegressionBTProbe = RegressionBTProbe.new()
	var observer: GAS_BTCheckVarDecorator = _observer(action, GAS_BTObserver.AbortType.SELF)
	var instance: GAS_BTInstance = GAS_BTInstance.new(actor, observer)
	instance.blackboard.set_var("allowed", true)
	instance.tick(0.1)
	expect(observer in instance.active_nodes and action in instance.active_nodes, "Active path must track running observer and child")
	instance.blackboard.set_var("allowed", false)
	expect(action.exits == 1 and not instance.has_node_status(action), "SELF must immediately exit its running child outside a tick")
	instance.reset_tree()
	expect(instance._observers.is_empty(), "Reset must unregister observers")
	actor.free()

func _check_priority_abort() -> void:
	var actor: Node = Node.new()
	var committed: RegressionBTProbe = RegressionBTProbe.new()
	committed.result = GAS_BTNode.Status.SUCCESS
	var higher: RegressionBTProbe = RegressionBTProbe.new()
	var lower: RegressionBTProbe = RegressionBTProbe.new()
	var observer: GAS_BTCheckVarDecorator = _observer(higher, GAS_BTObserver.AbortType.LOWER_PRIORITY)
	var selector: GAS_BTSelector = GAS_BTSelector.new()
	selector.children = [observer, lower]
	var root: GAS_BTSequence = GAS_BTSequence.new()
	root.children = [committed, selector]
	var instance: GAS_BTInstance = GAS_BTInstance.new(actor, root)
	instance.blackboard.set_var("allowed", false)
	instance.tick(0.1)
	instance.blackboard.set_var("allowed", true)
	expect(lower.exits == 1, "A failed higher-priority observer must remain eligible to interrupt lower work")
	instance.tick(0.1)
	expect(higher.enters == 1 and committed.ticks == 1, "Priority abort must restart only its selector, preserving preceding committed work")
	var early_action: RegressionBTProbe = RegressionBTProbe.new()
	var late_observer: GAS_BTCheckVarDecorator = _observer(RegressionBTProbe.new(), GAS_BTObserver.AbortType.LOWER_PRIORITY)
	var other_selector: GAS_BTSelector = GAS_BTSelector.new()
	other_selector.children = [early_action, late_observer]
	var other: GAS_BTInstance = GAS_BTInstance.new(actor, other_selector)
	other.tick(0.1)
	other.evaluate_interruption(late_observer, GAS_BTNode.Status.SUCCESS)
	expect(other.has_node_status(early_action), "A later branch must not interrupt an earlier active branch")
	other.reset_tree()
	instance.reset_tree()
	actor.free()

func _check_tick_reentry() -> void:
	var actor: Node = Node.new()
	var action: SignalDuringTick = SignalDuringTick.new()
	var observer: GAS_BTCheckVarDecorator = _observer(action, GAS_BTObserver.AbortType.SELF)
	var instance: GAS_BTInstance = GAS_BTInstance.new(actor, observer)
	instance.blackboard.set_var("allowed", true)
	instance.tick(0.1)
	expect(action.exits == 1 and not instance.has_node_status(action), "A change during tick must abort after unwinding without resurrecting RUNNING state")
	instance.reset_tree()
	expect(action.exits == 1, "Deferred interruption must remain idempotent")
	actor.free()
