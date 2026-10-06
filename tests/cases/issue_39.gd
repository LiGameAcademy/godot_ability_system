extends RegressionCase

func run() -> void:
	_check_switch()
	_check_dynamic_selector()

func _check_switch() -> void:
	var actor: Node = Node.new()
	var first: GAS_BTWaitSignal = GAS_BTWaitSignal.new()
	first.timeout = -1.0
	first.signal_key = "first_signal"
	var second: RegressionBTProbe = RegressionBTProbe.new()
	var tree: GAS_BTSwitch = GAS_BTSwitch.new()
	tree.variable_key = "branch"
	tree.children = [first, second]
	var instance: GAS_BTInstance = GAS_BTInstance.new(actor, tree)
	instance.tick(0.1)
	instance.blackboard.set_var("branch", 1)
	instance.tick(0.1)
	expect(not instance.has_node_status(first) and first not in instance._observers, "Switch must exit old wait and unregister its listener")
	expect(instance.blackboard.get_node_data(first) == null, "Old branch storage must be cleared")
	instance.blackboard.set_var("first_signal", true)
	expect(instance.blackboard.get_node_data(first) == null, "Old branch must no longer react to events")
	instance.tick(0.1)
	expect(second.enters == 1, "Unchanged branch must not re-enter")
	instance.blackboard.erase_var("first_signal")
	instance.blackboard.set_var("branch", 0)
	instance.tick(0.1)
	expect(second.exits == 1 and instance.has_node_status(first), "Switching back must exit B and enter A afresh")
	instance.blackboard.set_var("branch", 99)
	instance.tick(0.1)
	expect(instance._observers.is_empty() and not instance.has_node_status(first), "Invalid selection must also clean the active subtree")
	instance.reset_tree()
	actor.free()

func _check_dynamic_selector() -> void:
	var actor: Node = Node.new()
	var higher: RegressionBTProbe = RegressionBTProbe.new()
	higher.result = GAS_BTNode.Status.FAILURE
	var lower: RegressionBTProbe = RegressionBTProbe.new()
	var tree: GAS_BTDynamicSelector = GAS_BTDynamicSelector.new()
	tree.children = [higher, lower]
	var instance: GAS_BTInstance = GAS_BTInstance.new(actor, tree)
	instance.tick(0.1)
	higher.result = GAS_BTNode.Status.RUNNING
	instance.tick(0.1)
	expect(lower.exits == 1 and not instance.has_node_status(lower), "Dynamic selection must exit the previously running subtree")
	instance.tick(0.1)
	expect(higher.enters == 2 and lower.ticks == 1, "New branch must enter once and old branch must not keep ticking")
	higher.result = GAS_BTNode.Status.SUCCESS
	instance.tick(0.1)
	expect(not instance.has_node_status(tree) and not instance.has_node_status(higher), "Completion must release all active state")
	instance.reset_tree()
	actor.free()
