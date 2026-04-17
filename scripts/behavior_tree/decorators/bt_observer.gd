extends GAS_BTDecorator
class_name GAS_BTObserver

## 中断类型
enum AbortType {
	NONE,           # 不中断，仅作为普通条件使用
	SELF,           # 如果自身正在运行且条件不再满足，中断自己
	LOWER_PRIORITY, # 如果优先级较低的节点正在运行且条件变得满足，中断它们
}
@export var abort_type: AbortType = AbortType.NONE

func _enter(instance: GAS_BTInstance):
	if abort_type != AbortType.NONE:
		# 告诉 Instance：我要监听黑板变化
		instance.register_observer(self)

func _exit(instance: GAS_BTInstance):
	if abort_type != AbortType.NONE:
		instance.unregister_observer(self)

## [核心] 重写装饰器的执行逻辑：先检查条件，再执行子节点
func _tick_decorator(instance: GAS_BTInstance, delta: float) -> int:
	if not is_instance_valid(child):
		return Status.FAILURE

	# 【关键】在执行子节点之前，先检查条件是否满足
	var condition_met = check_condition(instance)

	if not condition_met:
		# 条件不满足，返回失败，不执行子节点
		return Status.FAILURE
		
	# 条件满足，执行子节点
	return child.tick(instance, delta)

## [虚函数] 检查变更的 Key 是否与我有关
func is_relevant(key: String) -> bool:
	return false

## [虚函数] 检查条件是否满足
func check_condition(instance: GAS_BTInstance) -> bool:
	return true

## [回调] 当黑板数据改变时，由 Instance 调用此函数
func on_blackboard_change(instance: GAS_BTInstance, key: String):
	# 子类判断 key 是否是自己关心的变量
	if not is_relevant(key): return 
	var is_success = check_condition(instance)
	var status = GAS_BTNode.Status.SUCCESS if is_success else GAS_BTNode.Status.FAILURE

	# 调用 Instance 的中断逻辑
	instance.evaluate_interruption(self, status)
