extends RefCounted
class_name AbilityResult

## 请求与执行结果，不使用行为树的控制流枚举。
enum Status { IDLE, READY, REJECTED, STARTED, INPUT_RECEIVED, RUNNING, FINISHING, COMPLETED, FAILED, CANCELLED, FORGOTTEN, OWNER_EXIT }
enum FailureReason { NONE, DISABLED, DISPOSED, BUSY, NOT_ACTIVE, INVALID_CONFIGURATION, COOLDOWN, COST, FEATURE_BLOCKED, EXECUTION_FAILED }

var status: Status = Status.IDLE
var failure_reason: FailureReason = FailureReason.NONE
var feature_name: String = ""
var execution_id: int = 0
var costs: Array[String] = []
var cooldowns: Array[String] = []

func _init(result_status: Status = Status.IDLE, reason: FailureReason = FailureReason.NONE, generation: int = 0, feature: String = "") -> void:
	status = result_status
	failure_reason = reason
	execution_id = generation
	feature_name = feature

## 接收请求不等于付款、命中或技能完成。READY 仅用于只读资格查询。
func is_accepted() -> bool:
	return status in [Status.STARTED, Status.INPUT_RECEIVED]

func copy() -> AbilityResult:
	var result: AbilityResult = AbilityResult.new(status, failure_reason, execution_id, feature_name)
	result.costs = costs.duplicate()
	result.cooldowns = cooldowns.duplicate()
	return result
