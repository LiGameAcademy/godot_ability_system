extends ActiveAbilityDefinition
class_name ProjectileAbilityDefinition

## 投射物技能配置模板
## 
## 用途：
## 快速创建标准的 "动画 -> 前摇 -> 冷却 -> 查找目标 -> 转向目标 -> 发射投射物 -> 后摇" 流程的技能。
## 支持投射物撞击时生成魔法阵（可选）。
## 
## 如果需要更复杂的逻辑，请直接使用基类 GameplayAbilityDefinition 并手动配置 Execution Tree。

@export_group("Projectile Settings")
## 投射物数据（包含场景、速度、生命周期、穿透等配置）
@export var projectile_data: ProjectileData = null
## 发射数量（多重施法）
@export var projectile_count: int = 1
## 散射角度（度，0 表示不散射）
@export var spread_angle: float = 0.0
## 枪口挂点名（用于定位发射点，如 "body", "muzzle"）
@export var muzzle_attachment_point: StringName = &"body"
## 是否在发射前转向目标位置（鼠标位置或目标节点）
@export var face_target: bool = true
## 转向速度（弧度/秒，0 或负数表示瞬间转向）
@export var face_target_rotation_speed: float = 12.0

func _build_effect_nodes() -> GAS_BTNode:
	var sequence = GAS_BTSequence.new()
	var nodes : Array[GAS_BTNode]
	#  转向目标位置（如果配置了）
	# 注意：AbilityNodeFaceTarget 会自动从 context.target_position 获取鼠标位置
	if face_target:
		var face_target_node = AbilityNodeFaceTarget.new()
		face_target_node.instant = (face_target_rotation_speed <= 0.0)
		face_target_node.rotation_speed = face_target_rotation_speed
		face_target_node.node_id = "face_target"
		nodes.append(face_target_node)

	# 发射投射物（核心逻辑）
	if is_instance_valid(projectile_data):
		var spawn_node = AbilityNodeSpawnProjectile.new()
		spawn_node.projectile_data = projectile_data
		spawn_node.projectile_count = projectile_count
		spawn_node.spread_angle = spread_angle
		spawn_node.muzzle_attachment_point = muzzle_attachment_point
		spawn_node.node_id = "spawn_projectile"
		nodes.append(spawn_node)

	sequence.children = nodes
	return sequence

## 验证配置的合理性
func _validate_configuration() -> void:
	super()
	
	# 验证：投射物数量应该为正
	if projectile_count <= 0:
		push_error("ProjectileAbilityDefinition [%s]: projectile_count 必须为正数 (%d)" % [ability_id, projectile_count])
		projectile_count = 1

	# 验证：散射角度应该非负
	if spread_angle < 0.0:
		push_error("ProjectileAbilityDefinition [%s]: spread_angle 不能为负数 (%.2f)" % [ability_id, spread_angle])
		spread_angle = 0.0

	# 验证：应该配置投射物数据
	if not is_instance_valid(projectile_data):
		push_warning(
			"ProjectileAbilityDefinition [%s]: 没有配置 projectile_data，技能可能不会产生任何效果。\n" % ability_id +
			"请确保这是预期的行为。"
		)
