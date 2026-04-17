extends AbilityNodeBase
class_name AbilityNodeFaceTarget

## 转向目标位置
## 职责：让施法者转向目标位置（瞬间或平滑转向）
## 注意：修改的是 visuals 节点的 rotation.y，与 player.gd 的移动旋转逻辑一致

@export_group("Target Configuration")
## 目标位置 Key（从黑板或 Context 获取位置）
@export var target_position_key: String = "target_position"

@export_group("Rotation Settings")
## 是否瞬间转向（不插值）
@export var instant: bool = false
## 转向速度（弧度/秒，仅在非瞬间模式下有效）
@export var rotation_speed: float = 12.0

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	var agent = instance.agent
	if not is_instance_valid(agent) or not agent is Node3D:
		push_warning("AbilityNodeFaceTarget: Agent is not a valid Node3D")
		return Status.FAILURE
	var agent_3d = agent as Node3D
	# 1. 获取 visuals 节点（用于旋转，与 player.gd 保持一致）
	var visuals_node = _get_visuals_node(agent_3d)
	if not is_instance_valid(visuals_node):
		push_warning("AbilityNodeFaceTarget: Cannot find visuals node")
		return Status.FAILURE
	
	# 2. 获取目标位置
	var target_position = _get_target_position(instance)
	if target_position == Vector3.INF:
		# 没有有效目标位置，视为成功（允许空挥）
		return Status.SUCCESS

	# 3. 计算目标方向（水平方向）
	var direction = target_position - agent_3d.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		# 目标太近，无需转向
		return Status.SUCCESS

	direction = direction.normalized()
	# 4. 计算目标角度（与 player.gd 的旋转逻辑一致）
	# 注意：模型朝向 -Z，所以需要计算从角色到目标的角度，然后加 π
	var base_angle = atan2(direction.x, direction.z)
	var target_angle = base_angle + PI

	# 5. 应用转向
	if instant:
		# 瞬间转向
		visuals_node.rotation.y = target_angle
		return Status.SUCCESS
	else:
		# 平滑转向（使用 lerp_angle，与 player.gd 一致）
		var current_angle = visuals_node.rotation.y
		var angle_diff = abs(angle_difference(current_angle, target_angle))

		if angle_diff < 0.01:
			# 已经朝向目标
			return Status.SUCCESS
		# 使用 lerp_angle 平滑转向
		visuals_node.rotation.y = lerp_angle(current_angle, target_angle, rotation_speed * delta)
		# 如果还没完全转向，继续运行
		if angle_diff > 0.01:
			return Status.RUNNING
		else:
			return Status.SUCCESS

## 获取目标位置（优先级：Context.custom_data.target_position > Context.hit_position > 黑板 target_position > input_target）
func _get_target_position(instance: GAS_BTInstance) -> Vector3:
	# 优先级1: 从 Context 获取 target_position（player.gd 设置的鼠标位置）
	var context = _get_context(instance)
	if context is Dictionary:
		# 优先从 context 获取 target_position
		if context.has(target_position_key) and context[target_position_key] is Vector3:
			return context[target_position_key] as Vector3
		# 其次从 hit_position 获取（投射物命中位置）
		if context.has("hit_position") and context["hit_position"] is Vector3:
			var hit_pos = context["hit_position"] as Vector3
			return hit_pos

	# 优先级2: 从黑板直接获取 target_position
	var target_pos = _get_var(instance, target_position_key)
	if target_pos is Vector3:
		return target_pos as Vector3

	# 优先级3: 从 Context 获取 input_target（用户指定的目标节点）
	if context is Dictionary:
		if context.has("input_target"):
			var input_target = context["input_target"]
			if is_instance_valid(input_target) and input_target is Node3D:
				return (input_target as Node3D).global_position

	# 没有有效目标位置
	return Vector3.INF

## 获取 visuals 节点（用于旋转）
func _get_visuals_node(agent: Node3D) -> Node3D:
	# 尝试从 agent 的子节点中查找 "Visuals" 节点
	if agent.has_method("get_visuals"):
		return agent.get_visuals()
	
	# 如果找不到，返回 agent 本身（某些角色可能没有 visuals 子节点）
	return agent

## 计算角度差（考虑周期性）
func angle_difference(from: float, to: float) -> float:
	var diff = to - from
	# 将角度差归一化到 [-PI, PI] 范围
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	return diff
