extends RefCounted
class_name CostPaymentBatch

const BUILTIN_VITAL_COST: Script = preload("vital_cost.gd")

var valid: bool = false
var _vitals: VitalCostBatch
var _custom: Array[AbilityCostPayment] = []
var _applied: bool = false
var _notified: bool = false

func _init(costs: Array[AbilityCostBase], component: Node, instigator: Node) -> void:
	var builtin: Array[AbilityCostBase] = []
	for cost: AbilityCostBase in costs:
		if not is_instance_valid(cost):
			return
		if cost.get_script() == BUILTIN_VITAL_COST:
			builtin.append(cost)
		elif not cost.supports_prepared_payment():
			return
	_vitals = VitalCostBatch.new(builtin, instigator)
	if not _vitals.valid:
		return
	for cost: AbilityCostBase in costs:
		if cost.get_script() == BUILTIN_VITAL_COST:
			continue
		if not is_instance_valid(component) or not is_instance_valid(instigator):
			return
		if not cost.can_pay(component, instigator):
			return
		# 只共享本次计划；已有计划可用于合并同一库存的费用。
		var payment: AbilityCostPayment = cost.prepare_payment(component, instigator, _custom.duplicate())
		if not is_instance_valid(payment):
			return
		if not _custom.has(payment):
			_custom.append(payment)
	valid = _custom_can_apply()

func _custom_can_apply() -> bool:
	for payment: AbilityCostPayment in _custom:
		if not payment.can_apply():
			return false
	return true

func apply() -> bool:
	if _applied:
		return true
	if not valid or not _custom_can_apply():
		return false
	# Vital 最后复核并无通知写入；此后自定义 apply 遵守无失败、无回调契约。
	if not _vitals.apply():
		return false
	for payment: AbilityCostPayment in _custom:
		payment.apply()
	_applied = true
	return true

func notify_changes() -> void:
	if not _applied or _notified:
		return
	_notified = true
	_vitals.notify_changes()
	for payment: AbilityCostPayment in _custom:
		payment.notify_changes()

func try_pay() -> bool:
	if not apply():
		return false
	notify_changes()
	return true
