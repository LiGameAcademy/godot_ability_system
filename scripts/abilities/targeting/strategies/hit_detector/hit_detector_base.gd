@abstract
extends Resource
class_name HitDetectorBase

## 命中检测器基类（抽象类）
## 使用策略模式，封装不同的命中检测逻辑
## 解决物理检测（Area3D）与数学检测（距离/位置）的兼容性问题
##
## 核心思想：技能不关心"如何检测目标"，只关心"检测到了哪些目标"
## 通过多态实现，支持不同的检测策略

## 检测目标
## [param] caster: Node 施法者（Node3D 或 Node2D）
## [param] context: Dictionary 上下文信息，可能包含：
##   - "target_position": Vector3/Vector2 目标位置（用于AOE技能）
##   - "target_unit": Node 锁定目标（用于指向性技能）
##   - "detection_radius": float 检测半径（可选覆盖）
##   - "collision_mask": int 碰撞遮罩（物理检测时使用）
##   - "facing_angle": float 面朝角度（弧度，用于近战攻击盒等）
##   - "facing_direction": Vector3/Vector2 面朝方向向量（用于近战攻击盒等）
## [return] Array[Node] 检测到的目标实体列表（已转换为实体根节点）
func get_targets(caster: Node, context: Dictionary = {}) -> Array[Node]:
	return _get_targets(caster, context)

## 验证检测器配置是否有效
func is_valid() -> bool:
	return _is_valid()

## 获取检测器描述（用于调试和UI显示）
func get_description() -> String:
	return _get_description()

## [子类重写] 检测目标的具体实现
@abstract func _get_targets(caster: Node, context: Dictionary) -> Array[Node]

## [子类重写] 验证配置
func _is_valid() -> bool:
	return true

## [子类重写] 获取描述
func _get_description() -> String:
	return "Hit Detector"
