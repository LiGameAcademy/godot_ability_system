extends RegressionCase

class Inventory extends Node:
	signal items_changed(previous: int, remaining: int)
	var items: int = 5

class InventoryPayment extends AbilityCostPayment:
	var inventory: Inventory
	var amount: int = 0
	var previous: int = 0
	var remaining: int = 0
	func can_apply() -> bool:
		return is_instance_valid(inventory) and amount >= 0 and inventory.items >= amount
	func apply() -> void:
		previous = inventory.items
		remaining = previous - amount
		inventory.items = remaining
	func notify_changes() -> void:
		if is_instance_valid(inventory) and previous != remaining:
			inventory.items_changed.emit(previous, remaining)

class InventoryCost extends AbilityCostBase:
	var amount: int = 2
	var legacy_calls: int = 0
	func _can_pay(_component: Node, instigator: Node) -> bool:
		return instigator is Inventory and amount >= 0 and (instigator as Inventory).items >= amount
	func _try_pay(_component: Node, instigator: Node) -> bool:
		legacy_calls += 1
		(instigator as Inventory).items -= amount
		return true
	func supports_prepared_payment() -> bool:
		return true
	func prepare_payment(_component: Node, instigator: Node, pending: Array[AbilityCostPayment]) -> AbilityCostPayment:
		if not instigator is Inventory or amount < 0:
			return null
		for entry: AbilityCostPayment in pending:
			var payment: InventoryPayment = entry as InventoryPayment
			if is_instance_valid(payment) and payment.inventory == instigator:
				payment.amount += amount
				return payment
		var payment: InventoryPayment = InventoryPayment.new()
		payment.inventory = instigator as Inventory
		payment.amount = amount
		return payment

class RejectedCost extends InventoryCost:
	func prepare_payment(_component: Node, _instigator: Node, _pending: Array[AbilityCostPayment]) -> AbilityCostPayment:
		return null

func run() -> void:
	_test_inventory_commit()
	_test_shared_pool_and_readonly_queries()
	_test_mixed_payment_and_late_failure()
	_test_rejected_plan_and_direct_payment()
	_test_actor_isolation_and_owner_exit()

func _test_inventory_commit() -> void:
	var actor: Inventory = Inventory.new()
	var cost: InventoryCost = InventoryCost.new()
	var feature: CostFeature = CostFeature.new()
	feature.costs = [cost, cost]
	var context: Dictionary = {"instigator": actor, "ability_component": actor}
	expect(feature.can_activate(null, context), "Two affordable inventory fees must qualify together")
	expect(actor.items == 5, "Qualification must not consume inventory")
	feature.costs = [cost]
	var definition: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	definition.features = [feature]
	definition.cooldown_duration = 5.0
	definition.execution_tree = RegressionBTProbe.new()
	var ability: GameplayAbilityInstance = definition.create_instance(actor)
	var cooldown: CooldownFeature = ability.get_feature("CooldownFeature") as CooldownFeature
	var notifications: Array[int] = []
	actor.items_changed.connect(func(previous: int, remaining: int) -> void:
		notifications.append(remaining)
		expect(previous == 5 and remaining == 3, "Inventory notification must describe this payment")
		expect(cooldown.get_cooldown_remaining(ability) == 5.0, "Inventory notification must see committed cooldown")
		expect(ability.get_commit_state()["costs"].has("CostFeature"), "Inventory notification must see the commit record")
		expect(ability.try_commit(), "Repeated commit from inventory notification must acknowledge success")
		ability.cancel()
	)
	expect(ability.try_activate(context), "Inventory ability must qualify")
	expect(ability.try_commit(context), "Prepared inventory cost must commit with cooldown")
	expect(actor.items == 3, "Commit must consume inventory exactly once")
	expect(notifications == [3] and not ability.is_active, "Cancellation in notification must finish once without refund")
	expect(cost.legacy_calls == 0, "Prepared cost must not execute its legacy write hook")
	ability.dispose()
	actor.free()

func _test_shared_pool_and_readonly_queries() -> void:
	var actor: Inventory = Inventory.new()
	var cost: InventoryCost = InventoryCost.new()
	var feature: CostFeature = CostFeature.new()
	feature.costs = [cost, cost]
	var context: Dictionary = {"instigator": actor, "ability_component": actor, "extra": [1]}
	var original: Dictionary = context.duplicate(true)
	var notifications: Array[int] = []
	actor.items_changed.connect(func(_previous: int, remaining: int) -> void: notifications.append(remaining))
	expect(feature.can_activate(null, context) and feature.can_activate(null, context), "Each readonly query must have fresh plans")
	expect(actor.items == 5 and notifications.is_empty() and context == original, "Queries must preserve inventory, context and notifications")
	actor.items = 3
	expect(not feature.can_activate(null, context), "Shared inventory must qualify against the aggregate amount")
	expect(not feature.try_pay(null, context) and actor.items == 3, "Aggregate failure must not consume the first fee")
	actor.items = 5
	expect(feature.try_pay(null, context), "Two references to one cost must be paid together")
	expect(actor.items == 1 and notifications == [1], "Shared inventory must be written and notified once")
	expect(cost.amount == 2 and cost.legacy_calls == 0, "Payment must preserve the shared configuration")
	actor.free()

func _test_mixed_payment_and_late_failure() -> void:
	var actor: Inventory = Inventory.new()
	var vitals: GameplayVitalAttributeComponent = _attach_vital(actor)
	var mana: VitalCost = VitalCost.new()
	mana.amount = 10.0
	var inventory: InventoryCost = InventoryCost.new()
	var feature: CostFeature = CostFeature.new()
	feature.costs = [mana, inventory, inventory]
	var context: Dictionary = {"instigator": actor, "ability_component": actor}
	var batch: CostPaymentBatch = feature.prepare_payment(context)
	expect(is_instance_valid(batch), "Mixed payment must prepare when all resources suffice")
	actor.items = 3
	expect(not batch.apply(), "A prepared payment must recheck the current external balance")
	expect(vitals.get_vital_value(&"mana") == 100.0 and actor.items == 3, "Late external failure must not spend any Vital")
	actor.items = 5
	batch = feature.prepare_payment(context)
	vitals.modify_vital(&"mana", -95.0)
	expect(not batch.apply() and actor.items == 5, "Late Vital failure must not spend external inventory")
	vitals.modify_vital(&"mana", 95.0)
	var observations: Array[bool] = []
	actor.items_changed.connect(func(_previous: int, _remaining: int) -> void:
		observations.append(vitals.get_vital_value(&"mana") == 90.0)
	)
	vitals.vital_value_changed.connect(func(_id: StringName, _value: float, _max: float, _percent: float, _regen: bool) -> void:
		observations.append(actor.items == 1)
	)
	batch = feature.prepare_payment(context)
	expect(batch.apply() and observations.is_empty(), "Mixed writes must precede all notifications")
	expect(batch.apply() and actor.items == 1 and vitals.get_vital_value(&"mana") == 90.0, "A payment plan must apply only once")
	batch.notify_changes()
	batch.notify_changes()
	expect(observations == [true, true], "Both pools must observe the complete payment exactly once")
	actor.free()

func _test_rejected_plan_and_direct_payment() -> void:
	var actor: Inventory = Inventory.new()
	var rejected: RejectedCost = RejectedCost.new()
	var feature: CostFeature = CostFeature.new()
	feature.costs = [InventoryCost.new(), rejected]
	var context: Dictionary = {"instigator": actor, "ability_component": actor}
	expect(not feature.can_activate(null, context) and not feature.try_pay(null, context), "Null custom plan must fail the whole batch")
	expect(actor.items == 5 and rejected.legacy_calls == 0, "Rejected prepared payment must never fall back to legacy writes")
	var direct: InventoryCost = InventoryCost.new()
	expect(direct.try_pay(actor, actor) and actor.items == 3 and direct.legacy_calls == 0, "Direct cost API must also honor the prepared contract")
	feature.costs = [direct, null]
	expect(not feature.try_pay(null, context) and actor.items == 3, "Invalid entry must fail before preparing external fees")
	actor.free()

func _test_actor_isolation_and_owner_exit() -> void:
	var first: Inventory = Inventory.new()
	var second: Inventory = Inventory.new()
	var shared: InventoryCost = InventoryCost.new()
	var definition: ActiveAbilityDefinition = ActiveAbilityDefinition.new()
	definition.costs = [shared]
	definition.cooldown_duration = 5.0
	definition.execution_tree = RegressionBTProbe.new()
	var first_ability: GameplayAbilityInstance = definition.create_instance(first)
	var second_ability: GameplayAbilityInstance = definition.create_instance(second)
	first_ability.try_activate({"instigator": first, "ability_component": first})
	second_ability.try_activate({"instigator": second, "ability_component": second})
	expect(first_ability.try_commit() and first.items == 3 and second.items == 5, "Shared cost must resolve the current actor's inventory")
	expect(second_ability.try_commit() and second.items == 3 and shared.amount == 2, "Each actor must have a fresh independent plan")
	first_ability.dispose()
	second_ability.dispose()
	first.free()
	second.free()
	var actor: Inventory = Inventory.new()
	var vitals: GameplayVitalAttributeComponent = _attach_vital(actor)
	var mana: VitalCost = VitalCost.new()
	mana.amount = 10.0
	var feature: CostFeature = CostFeature.new()
	feature.costs = [mana, shared]
	definition = ActiveAbilityDefinition.new()
	definition.features = [feature]
	definition.execution_tree = RegressionBTProbe.new()
	var ability: GameplayAbilityInstance = definition.create_instance(actor)
	ability.try_activate({"instigator": actor, "ability_component": actor})
	vitals.vital_value_changed.connect(func(_id: StringName, _value: float, _max: float, _percent: float, _regen: bool) -> void: actor.free())
	expect(ability.try_commit(), "Target exit during notifications must not undo completed payment")
	expect(not is_instance_valid(actor), "Custom notification must tolerate its target being freed by an earlier notification")
	ability.dispose()

func _attach_vital(actor: Node) -> GameplayVitalAttributeComponent:
	var component: GameplayVitalAttributeComponent = GameplayVitalAttributeComponent.new()
	component.name = "GameplayVitalAttributeComponent"
	actor.add_child(component)
	var maximum: GameplayAttribute = GameplayAttribute.new()
	maximum.attribute_id = &"max_mana"
	var attributes: GameplayAttributeSet = GameplayAttributeSet.new()
	attributes.attributes[maximum] = 100.0
	component.initialize([attributes], [ManaVital.new()])
	return component
