extends RegressionCase

func run() -> void:
	var actor: Node = Node.new()
	var action: RegressionBTProbe = RegressionBTProbe.new()
	action.result = GAS_BTNode.Status.SUCCESS
	var periodic: GAS_BTRepeatPeriodic = GAS_BTRepeatPeriodic.new()
	periodic.child = action
	periodic.period = 1.0
	periodic.execute_immediately = false
	var instance: GAS_BTInstance = GAS_BTInstance.new(actor, periodic)
	instance.tick(0.4)
	expect(action.ticks == 0, "Delayed mode must not run on the first tick")
	instance.tick(0.6)
	expect(action.ticks == 1, "Delayed mode must run when the first period elapses")
	instance.tick(0.3)
	expect(action.ticks == 1, "Later executions must also wait for the period")
	instance.reset_tree()
	periodic.execute_immediately = true
	instance.tick(0.0)
	expect(action.ticks == 2, "Immediate mode must run on entry")
	instance.reset_tree()
	actor.free()
