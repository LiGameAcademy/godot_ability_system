extends RegressionCase

class SideEffectProbe extends GAS_BTAction:
	var calls: int = 0

	func _tick(_instance: GAS_BTInstance, _delta: float) -> int:
		calls += 1
		return Status.SUCCESS

	func get_reevaluation_safety() -> int:
		return 2 # SIDE_EFFECTS; literal keeps the pre-change reproduction runnable.

func run() -> void:
	var actor: Node = Node.new()
	var effect: SideEffectProbe = SideEffectProbe.new()
	effect.node_id = &"damage"
	var wait: GAS_BTWait = GAS_BTWait.new()
	wait.duration = 1.0
	var dynamic: GAS_BTDynamicSequence = GAS_BTDynamicSequence.new()
	dynamic.node_id = &"reactive"
	dynamic.children = [effect, wait]
	var tree: GAS_BTInstance = GAS_BTInstance.new(actor, dynamic)
	for frame: int in range(4):
		tree.tick(0.1)
	expect(effect.calls == 4, "Dynamic semantics deliberately reevaluate completed actions")
	if tree.has_method("get_configuration_warnings"):
		var warnings: PackedStringArray = tree.call("get_configuration_warnings")
		expect(warnings.size() == 1 and warnings[0].contains("damage"), "Dangerous action has a locatable warning")
	else:
		expect(false, "Dynamic side effects need configuration diagnostics")
	tree.reset_tree()
	effect.calls = 0
	var sequence: GAS_BTSequence = GAS_BTSequence.new()
	sequence.children = [effect, wait]
	tree = GAS_BTInstance.new(actor, sequence)
	for frame: int in range(4):
		tree.tick(0.1)
	expect(effect.calls == 1, "Ordinary memory sequence does not replay damage while waiting")
	tree.reset_tree()
	if tree.has_method("get_configuration_warnings"):
		_check_reactivity(actor)
		_check_periodic(actor)
		_check_nested_diagnostics()
	actor.free()

func _check_nested_diagnostics() -> void:
	var effect: SideEffectProbe = SideEffectProbe.new()
	effect.node_id = &"nested_damage"
	var sequence: GAS_BTSequence = GAS_BTSequence.new()
	sequence.children = [effect]
	var dynamic: GAS_BTDynamicSelector = GAS_BTDynamicSelector.new()
	dynamic.children = [sequence]
	var warnings: PackedStringArray = GAS_BTTreeValidator.get_warnings(dynamic)
	expect(warnings.size() == 1 and warnings[0].contains("children[0]") and warnings[0].contains("nested_damage"), "Nested memory sequence does not hide reactive ancestor risk")
	var unknown: RegressionBTProbe = RegressionBTProbe.new()
	dynamic.children = [unknown]
	warnings = GAS_BTTreeValidator.get_warnings(dynamic)
	expect(warnings.size() == 1 and warnings[0].contains("unknown"), "Custom actions without metadata need explicit review")
	var cyclic: GAS_BTSequence = GAS_BTSequence.new()
	cyclic.children = [cyclic]
	warnings = GAS_BTTreeValidator.get_warnings(cyclic)
	expect(warnings.size() == 1 and warnings[0].contains("cyclic"), "Readonly inspection safely reports cycles")
	cyclic.children.clear()

func _check_reactivity(actor: Node) -> void:
	var check: GAS_BTCheckVar = GAS_BTCheckVar.new()
	check.key = "allowed"
	check.value = true
	var wait: GAS_BTWait = GAS_BTWait.new()
	wait.duration = 5.0
	var dynamic: GAS_BTDynamicSequence = GAS_BTDynamicSequence.new()
	dynamic.children = [check, wait]
	var tree: GAS_BTInstance = GAS_BTInstance.new(actor, dynamic)
	expect(tree.call("get_configuration_warnings").is_empty(), "Read-only conditions and waits are safe")
	tree.blackboard.set_var("allowed", true)
	expect(tree.tick(0.1) == GAS_BTNode.Status.RUNNING, "Dynamic condition allows initial branch")
	tree.blackboard.set_var("allowed", false)
	expect(tree.tick(0.1) == GAS_BTNode.Status.FAILURE, "Dynamic condition remains reactive")
	tree.reset_tree()

func _check_periodic(actor: Node) -> void:
	var effect: SideEffectProbe = SideEffectProbe.new()
	var periodic: GAS_BTRepeatPeriodic = GAS_BTRepeatPeriodic.new()
	periodic.child = effect
	periodic.period = 0.5
	periodic.execute_immediately = false
	var tree: GAS_BTInstance = GAS_BTInstance.new(actor, periodic)
	expect(tree.call("get_configuration_warnings").is_empty(), "Explicit periodic root permits repeated effects")
	for frame: int in range(10):
		tree.tick(0.1)
	expect(effect.calls == 2, "Periodic action obeys its declared interval")
	tree.reset_tree()
