extends RefCounted
class_name GameplayEffectResult

enum Status { APPLIED, NOT_APPLIED, FAILED, PARTIAL, UNVERIFIED }
enum Reason { NONE, INVALID_TARGET, NO_TARGET, MISSING_DEPENDENCY, INVALID_CONFIGURATION, FILTERED, IMMUNE, REQUIRED_TAG_MISSING, NO_CHANGE, NO_EFFECTS, LEGACY_UNVERIFIED }

var status: Status
var reason: Reason
var target_id: int = 0
var effect_path: String = ""
var outputs: Dictionary = {}
var children: Array[GameplayEffectResult] = []
## 副本共享同一个撤销能力；数值事实仍独立复制。
var application: GameplayEffectApplication = null

func _init(value: Status = Status.NOT_APPLIED, why: Reason = Reason.NONE) -> void:
	status = value
	reason = why

func did_apply() -> bool:
	return status in [Status.APPLIED, Status.PARTIAL]

func has_failure() -> bool:
	if status == Status.FAILED:
		return true
	if status == Status.PARTIAL and reason in [Reason.INVALID_TARGET, Reason.MISSING_DEPENDENCY, Reason.INVALID_CONFIGURATION]:
		return true
	for child: GameplayEffectResult in children:
		if child.has_failure():
			return true
	return false

func copy() -> GameplayEffectResult:
	var result: GameplayEffectResult = GameplayEffectResult.new(status, reason)
	result.target_id = target_id
	result.effect_path = effect_path
	result.outputs = outputs.duplicate(true)
	result.application = application
	for child: GameplayEffectResult in children:
		result.children.append(child.copy())
	return result

## 保留每项结果；部分成功不回滚，也不把已经发生的操作当成未执行。
static func aggregate(results: Array[GameplayEffectResult]) -> GameplayEffectResult:
	var result: GameplayEffectResult = GameplayEffectResult.new(Status.NOT_APPLIED, Reason.NO_EFFECTS)
	var applied: bool = false
	var not_applied: bool = false
	var failed: bool = false
	var unknown: bool = false
	var applications: Array[GameplayEffectApplication] = []
	for child: GameplayEffectResult in results:
		if is_instance_valid(child.application) and not applications.has(child.application):
			applications.append(child.application)
		result.children.append(child)
		applied = applied or child.did_apply()
		not_applied = not_applied or child.status != Status.APPLIED
		failed = failed or child.has_failure()
		unknown = unknown or child.status == Status.UNVERIFIED
		if child.reason != Reason.NONE and result.reason in [Reason.NONE, Reason.NO_EFFECTS]:
			result.reason = child.reason
	if applied:
		result.status = Status.PARTIAL if not_applied else Status.APPLIED
		if not not_applied:
			result.reason = Reason.NONE
	elif unknown:
		result.status = Status.UNVERIFIED
		result.reason = Reason.LEGACY_UNVERIFIED
	elif failed:
		result.status = Status.FAILED
	if applications.size() == 1:
		result.application = applications[0]
	elif applications.size() > 1:
		result.application = GameplayEffectApplication.new()
		for application: GameplayEffectApplication in applications:
			result.application.add_child(application)
	return result
