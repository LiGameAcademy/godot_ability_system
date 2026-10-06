extends RegressionCase

class FailingCost extends AbilityCostBase:
	var succeeds: bool = false
	func _can_pay(_component: Node, _instigator: Node) -> bool:
		return true
	func _try_pay(_component: Node, _instigator: Node) -> bool:
		return succeeds

func run() -> void:
	var actor: Node = Node.new()
	var cost: FailingCost = FailingCost.new()
	var feature: CostFeature = CostFeature.new()
	feature.costs = [cost]
	var commit: AbilityNodeCommitCost = AbilityNodeCommitCost.new()
	var effect: RegressionBTProbe = RegressionBTProbe.new()
	effect.result = GAS_BTNode.Status.SUCCESS
	var tree: GAS_BTSequence = GAS_BTSequence.new()
	tree.children = [commit, effect]
	var definition: GameplayAbilityDefinition = GameplayAbilityDefinition.new()
	definition.features = [feature]
	definition.execution_tree = tree
	var ability: GameplayAbilityInstance = definition.create_instance(actor)
	var context: Dictionary = {"ability_component": actor, "instigator": actor}
	expect(ability.try_activate(context), "Qualification should pass before simulated payment failure")
	ability.update(0.0)
	expect(effect.ticks == 0, "Payment failure must stop the sequence before effects")
	cost.succeeds = true
	ability.try_activate(context)
	ability.update(0.0)
	expect(effect.ticks == 1, "Successful payment must allow effects")
	ability.get_blackboard().clear()
	actor.free()
