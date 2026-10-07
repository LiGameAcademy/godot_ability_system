extends RefCounted
class_name VitalCostBatch

## 一次调用的付款计划，不放在共享 Cost Resource 或 Feature 上。
var valid: bool = false
var payments: Dictionary[GameplayVital, float] = {}
var _previous: Dictionary[GameplayVital, float] = {}
var _remaining: Dictionary[GameplayVital, float] = {}
var _maxima: Dictionary[GameplayVital, float] = {}
var _applied: bool = false
var _notified: bool = false

func _init(costs: Array[AbilityCostBase], instigator: Node) -> void:
	var required: Dictionary[GameplayVital, float] = {}
	var overdrafts: Dictionary[GameplayVital, float] = {}
	for entry: AbilityCostBase in costs:
		var cost: VitalCost = entry as VitalCost
		if not is_instance_valid(cost) or not is_finite(cost.amount) or cost.amount < 0.0:
			return
		var component: GameplayVitalAttributeComponent = cost._resolve_component(instigator)
		if not is_instance_valid(component):
			return
		var vital: GameplayVital = component.get_vital(cost.vital_id)
		if not is_instance_valid(vital):
			return
		if not required.has(vital):
			required[vital] = 0.0
			overdrafts[vital] = 0.0
		if cost.allow_overdraft:
			overdrafts[vital] += cost.amount
		else:
			required[vital] += cost.amount
	for vital: GameplayVital in required:
		if not is_instance_valid(vital._owner_comp):
			return
		var strict_amount: float = required[vital]
		var overdraft_amount: float = overdrafts[vital]
		var balance: float = vital.current_value
		var maximum: float = vital.get_max_value()
		if not is_finite(strict_amount) or not is_finite(overdraft_amount) or not is_finite(strict_amount + overdraft_amount):
			return
		if not is_finite(balance) or balance < strict_amount or not is_finite(maximum) or maximum < 0.0 or balance > maximum:
			return
		# 先为不允许透支的费用保留足额余额；透支费用仍要求剩余余额为正。
		if overdraft_amount > 0.0 and balance <= strict_amount:
			return
		payments[vital] = minf(balance, strict_amount + overdraft_amount)
	valid = true

func try_pay() -> bool:
	if not apply():
		return false
	notify_changes()
	return true

## 提交期间不发通知；由技能提交入口在冷却和记录写好后统一通知。
func apply() -> bool:
	if _applied:
		return true
	if not valid:
		return false
	_previous.clear()
	_remaining.clear()
	_maxima.clear()
	for vital: GameplayVital in payments:
		if not is_instance_valid(vital) or not is_instance_valid(vital._owner_comp):
			return false
		var amount: float = payments[vital]
		var balance: float = vital.current_value
		var maximum: float = vital.get_max_value()
		if not is_finite(amount) or amount < 0.0 or not is_finite(balance) or balance < amount:
			return false
		if not is_finite(maximum) or maximum < 0.0 or balance > maximum:
			return false
		_previous[vital] = balance
		_remaining[vital] = balance - amount
		_maxima[vital] = maximum
	for vital: GameplayVital in _remaining:
		vital.current_value = _remaining[vital]
	_applied = true
	return true

func notify_changes() -> void:
	if not _applied or _notified:
		return
	_notified = true
	for vital: GameplayVital in _remaining:
		var old_value: float = _previous[vital]
		var new_value: float = _remaining[vital]
		var maximum: float = _maxima[vital]
		if old_value == new_value:
			continue
		vital.value_changed.emit(new_value, maximum, new_value / maximum if maximum > 0.0 else 0.0, false)
		if new_value <= 0.0 and old_value > 0.0:
			vital.depleted.emit()
