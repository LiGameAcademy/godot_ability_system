@abstract
extends AbilityPreviewStrategy
class_name GroundIndicatorPreviewStrategy

## 地面指示器预览策略
## 职责：
## 1. 实例化并更新视觉指示器（Indicator）
## 2. 将鼠标位置转换为技能所需的上下文数据（Context）
## 
## 注意：与 TargetingStrategy（目标选择策略）不同
## - AbilityPreviewStrategy：预览阶段，显示指示器，获取鼠标位置
## - TargetingStrategy：执行阶段，在行为树中搜索目标单位

@export_group("Visuals")
## 指示器预制体（如圆形贴花、箭头模型）
@export var indicator_scene: PackedScene

@export_group("Constraints")
## 最大施法距离
@export var max_range: float = 10.0
## 是否贴地（通常为 true）
@export var snap_to_ground: bool = true

var _indicator : Node3D
var _finished : bool = false
var _result_context : Dictionary = {}
var _mouse_position : Vector3 = Vector3.ZERO
var caster : Node

func begin(caster: Node, ability_instance: GameplayAbilityInstance, extra_context: Dictionary = {}) -> void:
	_indicator = _create_indicator(caster)

func update(delta: float, input_context: Dictionary = {}) -> void:
	_mouse_position = input_context.get("mouse_position", Vector3.ZERO)
	if not is_instance_valid(_indicator):
		return
	_update_indicator(_indicator, caster, _mouse_position)

	# 比如当检测到点击确认按键， 就设置 _finished = true 并且写入 result
	if Input.is_action_just_pressed("confirm_cast"):
		_finished = true
		_result_context ={
			"target_position": _get_clamped_position(caster.global_position, _mouse_position),
			"target_type": "position"
		}

func cancel() -> void:
	_cancel_indicator()

## [3] 获取数据：确定目标，返回 Context 字典
## 注意：返回的 context 会传递给行为树，供 TargetingStrategy 使用
## context 中应包含 target_position，供 GroundTargetingStrategy 等策略读取
func get_result_context() -> Dictionary:
	var final_pos = _get_clamped_position(caster.global_position, _mouse_position)
	return {
		"target_position": final_pos,  # 供 TargetingStrategy 使用的位置
		"target_type": "position"
	}
	
## [1] 开始瞄准：创建指示器
func _create_indicator(parent: Node) -> Node3D:
	if is_instance_valid(indicator_scene):
		var instance = indicator_scene.instantiate()
		# 通常添加到当前场景根节点，避免跟随角色旋转（视需求而定）
		var root = parent.get_tree().current_scene
		root.add_child(instance)
		return instance
	return null

## [2] 更新循环：根据鼠标位置更新指示器
## [param] indicator: 由 _create_indicator 创建的实例
## [param] caster: 施法者
## [param] mouse_position: 鼠标在世界空间的位置（通常是 Raycast 击中点）
@abstract func _update_indicator(indicator: Node3D, caster: Node3D, mouse_position: Vector3) -> void

## [API] 取消预览
func _cancel_indicator() -> void:
	if is_instance_valid(_indicator):
		_indicator.queue_free()
		_indicator = null

## [辅助] 计算限制在最大距离内的位置
func _get_clamped_position(caster_pos: Vector3, target_pos: Vector3) -> Vector3:
	var dir = target_pos - caster_pos
	# 忽略 Y 轴高度差，只计算平面距离
	var flat_dir = Vector3(dir.x, 0, dir.z)

	if flat_dir.length() > max_range:
		flat_dir = flat_dir.normalized() * max_range
		return Vector3(caster_pos.x + flat_dir.x, target_pos.y, caster_pos.z + flat_dir.z)

	return target_pos
