extends GameplayAbilityFeature
class_name CostFeature

const BUILTIN_VITAL_COST: Script = preload("../costs/vital_cost.gd")

@export_group("Cost Settings")
## 内置 Vital 与采用准备契约的自定义费用一起结算；单个旧费用保留原入口。
@export var costs: Array[AbilityCostBase] = []

func _init() -> void:
	super("CostFeature")

func can_activate(_ability_instance: GameplayAbilityInstance, context: Dictionary) -> bool:
	return _pay(context, true)

func try_pay(ability_instance: GameplayAbilityInstance, context: Dictionary) -> bool:
	if is_instance_valid(ability_instance):
		var registered_name: String = ability_instance.find_feature_name(self)
		if registered_name.is_empty():
			return false
		return ability_instance.try_commit(context, true, false, registered_name)
	return _pay(context, false)

## 准备过程只读，不保留到 Feature 上；旧自定义钩子仍走独立入口。
func prepare_payment(context: Dictionary) -> CostPaymentBatch:
	if context.get("skip_cost", false) or costs.is_empty():
		return CostPaymentBatch.new([], null, null)
	var instigator_value: Variant = context.get("instigator")
	var component_value: Variant = context.get("ability_component")
	if not instigator_value is Node or not component_value is Node:
		return null
	var instigator: Node = instigator_value as Node
	var component: Node = component_value as Node
	if not is_instance_valid(instigator) or not is_instance_valid(component):
		return null
	var batch: CostPaymentBatch = CostPaymentBatch.new(costs, component, instigator)
	return batch if batch.valid else null

func _pay(context: Dictionary, check_only: bool) -> bool:
	if context.get("skip_cost", false) or costs.is_empty():
		return true
	var component_value: Variant = context.get("ability_component")
	var instigator_value: Variant = context.get("instigator")
	if not component_value is Node or not instigator_value is Node:
		return false
	var component: Node = component_value as Node
	var instigator: Node = instigator_value as Node
	if not is_instance_valid(component) or not is_instance_valid(instigator):
		return false
	for cost: AbilityCostBase in costs:
		if not is_instance_valid(cost):
			return false
		# 子类可能覆盖付款钩子，不能把它当作普通 VitalCost 绕过执行。
		if cost.get_script() != BUILTIN_VITAL_COST and not cost.supports_prepared_payment():
			if costs.size() != 1:
				push_warning("CostFeature: multiple or mixed custom costs require a prepared payment contract")
				return false
			return cost.can_pay(component, instigator) if check_only else cost.try_pay(component, instigator)
	var batch: CostPaymentBatch = CostPaymentBatch.new(costs, component, instigator)
	return batch.valid if check_only else batch.try_pay()
