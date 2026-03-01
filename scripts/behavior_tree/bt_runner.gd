extends Node
class_name GAS_BTRunner

const NodeStatus := GAS_BTNode.Status
enum RunnerMode {
	IDLE,       # _process
	PHYSICS,    # _physics_process
	MANUAL,     # 仅外部调用
}

@export var tree_root: GAS_BTNode
@export var run_mode: RunnerMode = RunnerMode.PHYSICS
@export var active: bool = true:
	set(v):
		active = v
		_update_process_mode()
## 黑板默认数据 (配置参数)
## 这里填写的 Key-Value 会在技能实例化时自动注入到黑板中
## 用途：配置 伤害范围、投射物速度、BUFF持续时间 等
@export var blackboard_defaults: Dictionary = {}

var _instance: GAS_BTInstance

signal tree_finished(result: NodeStatus)

func _ready() -> void:
	var agent = get_parent()
	if not tree_root:
		push_warning("GAS_BTRunner: No Tree Root assigned for " + agent.name)
		active = false
		return

	_instance = GAS_BTInstance.new(agent, tree_root, GAS_BTBlackboard.new(blackboard_defaults), self)
	
	_update_process_mode()

func _process(delta: float) -> void:
	tick(delta)

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not is_instance_valid(_instance):
		return
	
	var result = _instance.tick(delta)
	if result != NodeStatus.RUNNING:
		tree_finished.emit(result)

func reset() -> void:
	if not is_instance_valid(_instance):
		return
	_instance.reset()

func get_blackboard() -> GAS_BTBlackboard:
	return _instance.blackboard if is_instance_valid(_instance) else null

func _update_process_mode() -> void:
	set_process(active and run_mode == RunnerMode.IDLE)
	set_physics_process(active and run_mode == RunnerMode.PHYSICS)
