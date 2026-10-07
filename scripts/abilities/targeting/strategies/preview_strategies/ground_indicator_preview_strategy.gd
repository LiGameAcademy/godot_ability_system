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

var _indicator: Node3D
var _finished: bool = false
var _result_context: Dictionary = {}
var _mouse_position: Vector3 = Vector3.ZERO
var _origin_position: Vector3 = Vector3.ZERO
var _has_explicit_origin: bool = false
var caster: Node

## caster 只表示技能所属对象。普通 Node 通过 origin_position 提供 3D 世界坐标；
## Node3D 旧调用仍可省略坐标。indicator_parent 可指定指示器挂载节点，默认使用 caster。
func begin(caster: Node, ability_instance: GameplayAbilityInstance, extra_context: Dictionary = {}) -> void:
	cancel()
	self.caster = caster
	if not is_instance_valid(caster) or not _update_origin(extra_context):
		cancel()
		return
	_mouse_position = _origin_position
	if is_instance_valid(indicator_scene):
		var parent_value: Variant = extra_context.get("indicator_parent", caster)
		var indicator_parent: Node = parent_value as Node if parent_value is Node else null
		_indicator = _create_indicator(indicator_parent)
		if not is_instance_valid(_indicator):
			cancel()

func is_targeting() -> bool:
	return _is_session_valid() and not _finished

func is_finished() -> bool:
	return _finished

func update(delta: float, input_context: Dictionary = {}) -> void:
	if not _is_session_valid():
		cancel()
		return
	if _finished:
		return
	if not _update_origin(input_context):
		cancel()
		return
	var mouse_value: Variant = input_context.get("mouse_position", _mouse_position)
	if not mouse_value is Vector3 or not (mouse_value as Vector3).is_finite():
		push_warning("Ground preview mouse_position must be a finite Vector3")
		cancel()
		return
	_mouse_position = mouse_value as Vector3
	if is_instance_valid(_indicator):
		_update_indicator(_indicator, _origin_position, _mouse_position)

	if InputMap.has_action("confirm_cast") and Input.is_action_just_pressed("confirm_cast"):
		_result_context = get_result_context()
		_finished = true

func cancel() -> void:
	_cancel_indicator()
	caster = null
	_finished = false
	_result_context.clear()
	_has_explicit_origin = false
	_origin_position = Vector3.ZERO
	_mouse_position = Vector3.ZERO

## [3] 获取数据：确定目标，返回 Context 字典
## 注意：返回的 context 会传递给行为树，供 TargetingStrategy 使用
## context 中应包含 target_position，供 GroundTargetingStrategy 等策略读取
func get_result_context() -> Dictionary:
	if not _is_session_valid():
		cancel()
		return {}
	if _finished:
		return _result_context.duplicate()
	var final_pos: Vector3 = _get_clamped_position(_get_origin_position(), _mouse_position)
	return {
		"target_position": final_pos,  # 供 TargetingStrategy 使用的位置
		"target_type": "position"
	}
	
## [1] 开始瞄准：创建指示器
func _create_indicator(parent: Node) -> Node3D:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion():
		push_warning("Ground preview indicator_parent must be a live Node in the scene tree")
		return null
	if not indicator_scene.can_instantiate():
		push_warning("Ground preview indicator_scene must contain a scene")
		return null
	var instance: Node = indicator_scene.instantiate()
	if not instance is Node3D:
		push_warning("Ground preview indicator_scene must have a Node3D root")
		instance.free()
		return null
	var indicator: Node3D = instance as Node3D
	# 显式挂载，同时避免继承宿主的旋转和缩放。
	indicator.top_level = true
	parent.add_child(indicator)
	indicator.global_position = _origin_position
	return indicator

## [2] 更新循环：根据鼠标位置更新指示器
## [param] indicator: 由 _create_indicator 创建的实例
## [param] origin_position: 外部提供或从 Node3D 旧调用读取的世界坐标
## [param] mouse_position: 鼠标在世界空间的位置（通常是 Raycast 击中点）
@abstract func _update_indicator(indicator: Node3D, origin_position: Vector3, mouse_position: Vector3) -> void

func _is_session_valid() -> bool:
	if not is_instance_valid(caster) or caster.is_queued_for_deletion():
		return false
	return not is_instance_valid(indicator_scene) or (is_instance_valid(_indicator) and not _indicator.is_queued_for_deletion())

func _update_origin(context: Dictionary) -> bool:
	if context.has("origin_position"):
		var origin_value: Variant = context["origin_position"]
		if not origin_value is Vector3 or not (origin_value as Vector3).is_finite():
			push_warning("Ground preview origin_position must be a finite Vector3")
			return false
		_origin_position = origin_value as Vector3
		_has_explicit_origin = true
	elif not _has_explicit_origin:
		if not caster is Node3D:
			push_warning("Ground preview requires origin_position when caster is not a Node3D")
			return false
		_origin_position = (caster as Node3D).global_position
	return true

func _get_origin_position() -> Vector3:
	if not _has_explicit_origin and caster is Node3D:
		return (caster as Node3D).global_position
	return _origin_position

## [API] 取消预览
func _cancel_indicator() -> void:
	if is_instance_valid(_indicator):
		_indicator.queue_free()
		_indicator = null

## [辅助] 计算限制在最大距离内的位置
func _get_clamped_position(caster_pos: Vector3, target_pos: Vector3) -> Vector3:
	var dir: Vector3 = target_pos - caster_pos
	# 忽略 Y 轴高度差，只计算平面距离
	var flat_dir: Vector3 = Vector3(dir.x, 0, dir.z)

	if flat_dir.length() > max_range:
		flat_dir = flat_dir.normalized() * max_range
		return Vector3(caster_pos.x + flat_dir.x, target_pos.y, caster_pos.z + flat_dir.z)

	return target_pos
