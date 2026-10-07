extends RefCounted
class_name AbilityResultHistory

## 按实例记录执行结果，BT reset 和下一轮激活都不清除上次终结快照。
var _current: AbilityResult = AbilityResult.new()
var _last_finished: AbilityResult = AbilityResult.new()

func start(generation: int) -> void:
	_current = AbilityResult.new(AbilityResult.Status.RUNNING, AbilityResult.FailureReason.NONE, generation)

func begin_finish() -> void:
	_current.status = AbilityResult.Status.FINISHING

func record_commit(reason: AbilityResult.FailureReason, feature: String) -> void:
	if reason in [AbilityResult.FailureReason.BUSY, AbilityResult.FailureReason.NOT_ACTIVE, AbilityResult.FailureReason.DISPOSED]:
		return
	if _current.status in [AbilityResult.Status.RUNNING, AbilityResult.Status.FINISHING]:
		_current.failure_reason = reason
		_current.feature_name = feature

func get_current(commit: Dictionary) -> AbilityResult:
	var result: AbilityResult = _current.copy()
	_copy_commit(result, commit)
	return result

func record_effect(result: GameplayEffectResult) -> void:
	if _current.status not in [AbilityResult.Status.RUNNING, AbilityResult.Status.FINISHING]:
		return
	_current.effects.append(result.copy())
	record_effect_outcome(result)

func record_effect_outcome(result: GameplayEffectResult) -> void:
	if _current.status not in [AbilityResult.Status.RUNNING, AbilityResult.Status.FINISHING]:
		return
	_current.feature_name = ""
	_current.failure_reason = AbilityResult.FailureReason.NONE
	if result.status == GameplayEffectResult.Status.UNVERIFIED:
		_current.failure_reason = AbilityResult.FailureReason.UNVERIFIED_EFFECT
	elif result.has_failure():
		_current.failure_reason = AbilityResult.FailureReason.EFFECT_FAILED
	elif not result.did_apply():
		match result.reason:
			GameplayEffectResult.Reason.NO_TARGET, GameplayEffectResult.Reason.INVALID_TARGET:
				_current.failure_reason = AbilityResult.FailureReason.NO_TARGET
			GameplayEffectResult.Reason.IMMUNE:
				_current.failure_reason = AbilityResult.FailureReason.IMMUNE
			GameplayEffectResult.Reason.FILTERED, GameplayEffectResult.Reason.REQUIRED_TAG_MISSING:
				_current.failure_reason = AbilityResult.FailureReason.FILTERED
			_:
				_current.failure_reason = AbilityResult.FailureReason.EFFECT_FAILED

func get_last_finished() -> AbilityResult:
	return _last_finished.copy()

func finish(status: AbilityResult.Status, commit: Dictionary) -> AbilityResult:
	_current.status = status
	if status == AbilityResult.Status.FAILED:
		if _current.failure_reason == AbilityResult.FailureReason.NONE:
			_current.failure_reason = AbilityResult.FailureReason.EXECUTION_FAILED
	else:
		# 被 fallback 恢复的失败不把正常完成变成失败；提交记录仍保留。
		_current.failure_reason = AbilityResult.FailureReason.NONE
		_current.feature_name = ""
	_copy_commit(_current, commit)
	_last_finished = _current.copy()
	return _last_finished.copy()

func _copy_commit(result: AbilityResult, commit: Dictionary) -> void:
	result.costs.assign(commit["costs"])
	result.cooldowns.assign(commit["cooldowns"])
