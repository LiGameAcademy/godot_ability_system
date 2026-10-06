extends RegressionCase

func run() -> void:
	var actor: Node = Node.new()
	var action: RegressionBTProbe = RegressionBTProbe.new()
	var runner: GAS_BTRunner = GAS_BTRunner.new()
	runner.run_mode = GAS_BTRunner.RunnerMode.MANUAL
	runner.tree_root = action
	actor.add_child(runner)
	runner._ready()
	runner.tick(0.1)
	runner.reset()
	expect(action.exits == 1, "Runner reset must exit the active action")
	runner.tick(0.1)
	expect(action.enters == 2, "Reset runner must restart from the root")
	runner.reset()
	actor.free()
