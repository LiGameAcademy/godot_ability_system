extends RegressionCase

class CountingSequence extends GAS_BTSequence:
	var exits: int = 0
	func _exit(_instance: GAS_BTInstance) -> void:
		exits += 1

class CountingInverter extends GAS_BTInverter:
	var exits: int = 0
	func _exit(_instance: GAS_BTInstance) -> void:
		exits += 1

func run() -> void:
	var actor: Node = Node.new()
	var action: RegressionBTProbe = RegressionBTProbe.new()
	var decorator: CountingInverter = CountingInverter.new()
	decorator.child = action
	var tree: CountingSequence = CountingSequence.new()
	tree.children = [decorator]
	var instance: GAS_BTInstance = GAS_BTInstance.new(actor, tree)
	instance.tick(0.1)
	instance.reset_tree()
	instance.reset_tree()
	expect(tree.exits == 1 and decorator.exits == 1 and action.exits == 1, "Reset must exit each active node exactly once")
	expect(not instance.has_node_status(tree) and not instance.has_node_status(decorator), "Reset must erase composite/decorator status")
	expect(instance.blackboard.get_all_node_data().is_empty(), "Reset must clear execution storage")
	action.result = GAS_BTNode.Status.SUCCESS
	instance.tick(0.1)
	expect(tree.exits == 2 and decorator.exits == 2, "Normal completion must not double-exit after internal reset")
	action.result = GAS_BTNode.Status.RUNNING
	instance.tick(0.1)
	expect(action.enters == 3, "Restart must enter all nodes again")
	instance.reset_tree()
	actor.free()
