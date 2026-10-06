extends GameplayEffect
class_name GE_ApplyDamage

## 应用伤害效果
## 默认会阻挡带有 state.invulnerable 标签的目标（免疫伤害）

@export var damage_multiplier: float = 1.0  ## 伤害倍数
@export var invulnerable_block_tag: StringName = &"state.invulnerable"  ## 免疫伤害标签
@export var damage_strategy : DamageLogicStrategy = null
@export var vital_comp_name : StringName = &"GameplayVitalAttributeComponent"
@export var vital_id : StringName = &"health"

func _init() -> void:
	# 为伤害效果提供默认的免疫标签，避免在每个资源里手工配置
	if target_blocked_tags.is_empty() and not invulnerable_block_tag.is_empty():
		target_blocked_tags = [invulnerable_block_tag]

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	var calculation_context: Dictionary = context.duplicate()
	calculation_context["damage_multiplier"] = damage_multiplier * float(context.get("damage_multiplier", 1.0))
	var strategy: DamageLogicStrategy = context.get("damage_strategy", damage_strategy) as DamageLogicStrategy
	
	# 1. 获取 HealthVital
	var vital_comp: GameplayVitalAttributeComponent = GameplayAbilitySystem.get_component_by_interface(target, vital_comp_name) as GameplayVitalAttributeComponent
	if not is_instance_valid(vital_comp):
		push_warning("GE_ApplyDamage: target has no compatible Vital component")
		return
	var health_vital: HealthVital = vital_comp.get_vital(vital_id) as HealthVital
	if not is_instance_valid(health_vital):
		push_warning("GE_ApplyDamage: configured vital is not a HealthVital")
		return
	
	# 直接从 context Dictionary 读取
	var stacks = context.get("stacks", 1)
	
	# 2. 计算最终伤害
	var final_damage: float = DamageCalculator.calculate_final_damage(target, instigator, calculation_context, strategy)
	
	# 3. 创建 GameplayDamageInfo
	var damage_info = GameplayDamageInfo.new(instigator, context.get("source_node", null), final_damage * stacks)
	damage_info.final_damage = damage_info.base_damage
	
	# 4. 应用伤害（由 HealthVital 负责）
	damage_info.final_damage = health_vital.apply_damage(damage_info, target)
	
	# 5. 保存到上下文
	context["final_damage"] = damage_info.final_damage
