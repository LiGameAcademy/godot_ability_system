extends ToggleAbilityDefinition
class_name SacrificeAbilityDefinition

"""
继承自 ToggleAbilityDefinition，基础结构：
Root Sequence
├── AbilityNodePlayAnimation      # 1. 播放动画
├── GAS_BTWait                        # 2. 前摇等待
├── AbilityNodeTargetSearch       # 3. 查找目标
├── GAS_BTRepeatUntilFailure          # 4. 循环执行直到关闭
│   └── GAS_BTSelector                # 5. 切换选择器
│       ├── Turn Off Sequence    # 分支1：关闭逻辑
│       │   ├── GAS_BTCheckVar        # toggle_action == "turn_off"
│       │   ├── AbilityNodeRemoveStatus
│       │   ├── GAS_BTSetVar (clear icon)
│       │   ├── AbilityNodeCommitCooldown
│       │   └── GAS_BTCheckVar (end marker, 返回 FAILURE)
│       ├── Turn On Sequence      # 分支2：开启逻辑
│       │   ├── GAS_BTCheckVar        # toggle_action == "turn_on"
│       │   ├── AbilityNodeCommitCost        # 初始消耗
│       │   ├── AbilityNodeApplyStatus
│       │   ├── GAS_BTSetVar (icon_when_active)
│       │   └── GAS_BTSetVar (set toggle_action = "on")
│       └── Keep On Sequence      # 分支3：保持状态（子类扩展，包含周期性逻辑）
│           ├── GAS_BTCheckVar        # toggle_action == "on"
│           ├── GAS_BTRepeatPeriodic             # 【子类扩展】周期性逻辑
│           │   └── Periodic Sequence
│           │       ├── AbilityNodeTargetSearch (选择自身)
│           │       ├── AbilityNodeApplyCost (检查并消耗生命值，不足时返回 FAILURE)
│           │       ├── AbilityNodeTargetSearch (选择周围敌人)
│           │       └── AbilityNodeApplyEffect (对敌人造成伤害)
│           └── GAS_BTWaitSignal      # timeout = -1（无限等待），收到输入后进入关闭分支
└── GAS_BTWait                        # 6. 后摇等待
"""

@export_group("Sacrifice Settings")
## 周期性消耗的生命值（每秒）
@export var periodic_health_cost: float = 1.0
## 周期性消耗的生命值 Vital ID
@export var periodic_health_vital_id: StringName = &"health"
## 周期性伤害检测半径
@export var damage_radius: float = 3.0
## 周期性伤害倍数
@export var periodic_damage_multiplier: float = 1.5
## 周期性执行间隔（秒）
@export var periodic_interval: float = 1.0
## 区域目标策略（用于查找周围敌人）
@export var area_targeting_strategy: AreaTargetingStrategy = null
## 周期性伤害效果（对周围敌人应用的效果）
@export var periodic_damage_effect: GameplayEffect = null

func _build_keep_on_sequence() -> GAS_BTSequence:
	# 重写保持分支：在保持状态时执行周期性逻辑
	var keep_on_sequence = GAS_BTSequence.new()
	keep_on_sequence.node_id = "keep_on_sequence"

	# 检查是否为保持状态
	var check_keep_on = GAS_BTCheckVar.new()
	check_keep_on.key = "toggle_action"
	check_keep_on.value = "on"
	check_keep_on.node_id = "check_keep_on"
	keep_on_sequence.children.append(check_keep_on)

	# 周期性逻辑：检查消耗 + 消耗生命值 + 对敌人造成伤害
	# 这个逻辑会在保持状态时持续执行，直到生命值不足或收到关闭信号
	var periodic_repeat = GAS_BTRepeatPeriodic.new()
	periodic_repeat.period = periodic_interval
	periodic_repeat.execute_immediately = false  # 等待第一个周期
	periodic_repeat.node_id = "periodic_repeat"

	# 周期性执行的序列
	var periodic_sequence = GAS_BTSequence.new()
	periodic_sequence.node_id = "periodic_sequence"

	# 1. 选择自身目标策略（确保后续节点操作的是自身）
	var self_target_node = AbilityNodeTargetSearch.new()
	var self_targeting = SelfTargetingStrategy.new()
	self_target_node.strategy = self_targeting
	self_target_node.write_to_key = target_key
	self_target_node.node_id = "select_self_target"
	periodic_sequence.children.append(self_target_node)

	# 2. 检查并消耗生命值（如果不足，返回 FAILURE，中断周期性任务）
	var cost_node = AbilityNodeApplyCost.new()
	cost_node.vital_id = periodic_health_vital_id
	cost_node.cost_amount = periodic_health_cost
	cost_node.allow_overdraft = false
	cost_node.check_only = false  # 检查并消耗
	cost_node.target_key = target_key
	cost_node.node_id = "check_and_apply_periodic_cost"
	periodic_sequence.children.append(cost_node)

	# 3. 选择周围目标策略（查找敌人）
	var area_target_node = AbilityNodeTargetSearch.new()
	# 如果用户配置策略，创建默认的
	if is_instance_valid(area_targeting_strategy):
		area_target_node.strategy = area_targeting_strategy
		area_target_node.write_to_key = "area_targets"
		area_target_node.fail_if_empty = false  # 没有目标时静默成功
		area_target_node.node_id = "select_area_targets"
		periodic_sequence.children.append(area_target_node)

	# 4. 对周围敌人应用伤害效果
	if is_instance_valid(periodic_damage_effect):
		var apply_effect_node = AbilityNodeApplyEffect.new()
		apply_effect_node.target_key = "area_targets"
		apply_effect_node.effects.append(periodic_damage_effect)
		apply_effect_node.node_id = "apply_area_damage"
		periodic_sequence.children.append(apply_effect_node)

	periodic_repeat.child = periodic_sequence
	keep_on_sequence.children.append(periodic_repeat)

	return keep_on_sequence
	
## 验证配置的合理性
func _validate_configuration() -> void:
	super()
	
	# 验证：周期性消耗应该非负
	if periodic_health_cost < 0.0:
		push_error("SacrificeAbilityDefinition [%s]: periodic_health_cost 不能为负数 (%.2f)" % [ability_id, periodic_health_cost])
		periodic_health_cost = 0.0
	# 验证：周期性执行间隔应该为正
	if periodic_interval <= 0.0:
		push_error("SacrificeAbilityDefinition [%s]: periodic_interval 必须为正数 (%.2f)" % [ability_id, periodic_interval])
		periodic_interval = 1.0
	# 验证：伤害半径应该非负
	if damage_radius < 0.0:
		push_error("SacrificeAbilityDefinition [%s]: damage_radius 不能为负数 (%.2f)" % [ability_id, damage_radius])
		damage_radius = 0.0
	# 验证：如果配置了周期性消耗，应该配置了 Vital ID
	if periodic_health_cost > 0.0 and periodic_health_vital_id.is_empty():
		push_warning(
				"SacrificeAbilityDefinition [%s]: 配置了 periodic_health_cost (%.2f) 但没有配置 periodic_health_vital_id。\n" % [ability_id, periodic_health_cost] +
				"周期性消耗可能无法正常工作。"
			)
	
	# 验证：如果配置了周期性伤害效果，应该配置了区域目标策略或伤害半径
	if is_instance_valid(periodic_damage_effect):
		if not is_instance_valid(area_targeting_strategy) and damage_radius <= 0.0:
			push_warning(
				"SacrificeAbilityDefinition [%s]: 配置了 periodic_damage_effect 但没有配置 area_targeting_strategy 或 damage_radius。\n" % ability_id +
				"周期性伤害可能无法正常工作。"
			)
