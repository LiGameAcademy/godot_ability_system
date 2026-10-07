extends RefCounted
class_name AbilityCommit

## 一轮执行的提交记录，独立于 BT 进度和共享 Feature。
var _costs: Array[String] = []
var _cooldowns: Array[String] = []
var _busy: bool = false
var failure_reason: AbilityResult.FailureReason = AbilityResult.FailureReason.NONE
var failure_feature: String = ""

func reset() -> void:
	_costs.clear()
	_cooldowns.clear()
	failure_reason = AbilityResult.FailureReason.NONE
	failure_feature = ""

func is_in_progress() -> bool:
	return _busy

func get_state() -> Dictionary:
	return {"costs": _costs.duplicate(), "cooldowns": _cooldowns.duplicate()}

func try_commit(ability: GameplayAbilityInstance, context: Dictionary, pay_cost: bool, start_cooldown: bool, cost_name: String, cooldown_name: String) -> bool:
	failure_reason = AbilityResult.FailureReason.NONE
	failure_feature = ""
	if not ability.is_active or ability.is_disposed():
		return _reject(AbilityResult.FailureReason.DISPOSED if ability.is_disposed() else AbilityResult.FailureReason.NOT_ACTIVE)
	var pending_cost: bool = pay_cost and not _costs.has(cost_name)
	var pending_cooldown: bool = start_cooldown and not _cooldowns.has(cooldown_name)
	if not pending_cost and not pending_cooldown:
		return true
	if _busy:
		return _reject(AbilityResult.FailureReason.BUSY)
	_busy = true
	var success: bool = _submit(ability, context, pending_cost, pending_cooldown, cost_name, cooldown_name)
	if success:
		failure_reason = AbilityResult.FailureReason.NONE
		failure_feature = ""
	_busy = false
	return success

func _reject(reason: AbilityResult.FailureReason, feature: String = "") -> bool:
	failure_reason = reason
	failure_feature = feature
	return false

func _submit(ability: GameplayAbilityInstance, context: Dictionary, pay_cost: bool, start_cooldown: bool, cost_name: String, cooldown_name: String) -> bool:
	var cost: CostFeature = ability.get_feature(cost_name) as CostFeature if pay_cost else null
	var cooldown: CooldownFeature = ability.get_feature(cooldown_name) as CooldownFeature if start_cooldown else null
	if pay_cost and not ability.has_feature(cost_name) and cost_name != "CostFeature":
		return _reject(AbilityResult.FailureReason.INVALID_CONFIGURATION, cost_name)
	if start_cooldown and not ability.has_feature(cooldown_name) and cooldown_name != "CooldownFeature":
		return _reject(AbilityResult.FailureReason.INVALID_CONFIGURATION, cooldown_name)
	if pay_cost and ability.has_feature(cost_name) and not is_instance_valid(cost):
		return _reject(AbilityResult.FailureReason.INVALID_CONFIGURATION, cost_name)
	if start_cooldown and ability.has_feature(cooldown_name) and not is_instance_valid(cooldown):
		return _reject(AbilityResult.FailureReason.INVALID_CONFIGURATION, cooldown_name)
	if is_instance_valid(cost) and not cost.can_activate(ability, context.duplicate(true)):
		return _reject(AbilityResult.FailureReason.COST, cost_name)
	if is_instance_valid(cooldown):
		if not is_finite(cooldown.cooldown_duration) or cooldown.cooldown_duration < 0.0:
			return _reject(AbilityResult.FailureReason.INVALID_CONFIGURATION, cooldown_name)
		if not cooldown.can_activate(ability, context.duplicate(true)):
			return _reject(AbilityResult.FailureReason.COOLDOWN, cooldown_name)
	if not ability.is_active or ability.is_disposed():
		return _reject(AbilityResult.FailureReason.NOT_ACTIVE)
	var batch: CostPaymentBatch = cost.prepare_payment(context) if is_instance_valid(cost) else null
	if not ability.is_active or ability.is_disposed():
		return _reject(AbilityResult.FailureReason.NOT_ACTIVE)
	if is_instance_valid(cost) and not is_instance_valid(batch):
		# 旧自定义费用不能无通知提交，与冷却组合前必须提供新的准备契约。
		if is_instance_valid(cooldown) and cooldown.cooldown_duration > 0.0:
			push_warning("AbilityCommit: custom cost with cooldown requires a prepared payment contract")
			return _reject(AbilityResult.FailureReason.INVALID_CONFIGURATION, cost_name)
		if not cost._pay(context, false):
			return _reject(AbilityResult.FailureReason.COST, cost_name)
	elif is_instance_valid(batch) and not batch.apply():
		return _reject(AbilityResult.FailureReason.COST, cost_name)
	if pay_cost:
		_costs.append(cost_name)
	if start_cooldown:
		_cooldowns.append(cooldown_name)
		if is_instance_valid(cooldown):
			cooldown._commit_silently(ability)
	# 准备契约的付款此前不发通知；现在费用、冷却和提交记录均可被观察。
	if is_instance_valid(cooldown) and cooldown.cooldown_duration > 0.0:
		ability.ability_data_changed.emit(ability)
	if is_instance_valid(batch):
		batch.notify_changes()
	return true
