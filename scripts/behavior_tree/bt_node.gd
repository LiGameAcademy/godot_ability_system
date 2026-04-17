@abstract
extends Resource
class_name GAS_BTNode

enum Status { 
	SUCCESS,   # 成功：节点执行完成且成功
	FAILURE,   # 失败：节点执行完成但失败
	RUNNING    # 运行中：节点正在执行，需要继续更新
}

@export var node_id: StringName = ""

## 增加 delta 参数，这对计时类节点至关重要
func tick(instance: GAS_BTInstance, delta: float) -> int:
	# 1. 检查是否是"首次进入"
	var was_running = instance.has_node_status(self)
	var previous_status = instance.get_node_status(self, -1)

	if not was_running:
		_enter(instance)
		# 首次进入时记录
		instance.record_node_execution(self, Status.RUNNING)
		instance.set_node_status(self, Status.RUNNING)

	# 2. 执行具体的业务逻辑 (由子类实现)
	var result = _tick(instance, delta)

	# 3. 记录执行历史（只在状态改变时记录，避免每帧都记录）
	if previous_status != result:
		instance.record_node_execution(self, result)

	# 4. 处理生命周期结束
	if result != Status.RUNNING:
		# 如果结果是 成功 或 失败，说明节点运行结束
		_exit(instance)
		# 清理运行状态（但不清理存储数据）
		instance.erase_node_status(self)
		# 清理存储数据（由节点自己决定是否清理）
		instance.blackboard.erase_node_data(self)
	else:
		# 如果是 RUNNING，更新状态
		instance.set_node_status(self, result)
	return result

## 强制清理状态 (用于中断)
func reset(instance: GAS_BTInstance) -> void:
	# 如果当前被标记为正在运行，则触发退出逻辑
	if instance.has_node_status(self):
		_exit(instance)
		instance.erase_node_status(self)
		instance.blackboard.erase_node_data(self)

## [虚函数] 业务逻辑入口
## 子类不要重写 tick()，而是重写 _tick()
@abstract func _tick(instance: GAS_BTInstance, delta: float) -> int

## [虚函数] 节点激活时调用 (只调用一次)
## 用于：注册观察者、初始化临时变量、播放开始动画
func _enter(instance: GAS_BTInstance) -> void: pass

## [虚函数] 节点结束时调用 (成功或失败都会调用)
## 用于：注销观察者、清理临时变量、停止动画
func _exit(instance: GAS_BTInstance) -> void: pass

## [语法糖] 获取我的私有变量
func _get_storage(instance: GAS_BTInstance, default: Variant = null) -> Variant:
	return instance.blackboard.get_node_data(self, default)

## [语法糖] 设置我的私有变量
func _set_storage(instance: GAS_BTInstance, value: Variant) -> void:
	instance.blackboard.set_node_data(self, value)

## [语法糖] 清理
func _clear_storage(instance: GAS_BTInstance) -> void:
	instance.blackboard.erase_node_data(self)

func _get_var(instance: GAS_BTInstance, key: String, default: Variant = null) -> Variant:
	return instance.blackboard.get_var(key, default)

func _set_var(instance: GAS_BTInstance, key: String, value: Variant) -> void:
	instance.blackboard.set_var(key, value)

func _has_var(instance: GAS_BTInstance, key: String) -> bool:
	return instance.blackboard.has_var(key)

func _clear_var(instance: GAS_BTInstance, key: String) -> void:
	instance.blackboard.erase_var(key)

func _get_node_name() -> StringName:
	return node_id if not node_id.is_empty() else get_class()

func _to_string() -> String:
	var script = get_script()
	if script:
		var script_name = script.get_global_name()
		if script_name != "":
			return script_name

	return get_class()
