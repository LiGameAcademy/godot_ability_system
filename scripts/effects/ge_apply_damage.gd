extends GameplayEffect
class_name GE_ApplyDamage

@export var damage_multiplier: float = 1.0
@export var invulnerable_block_tag: StringName = &"state.invulnerable"
@export var damage_strategy: DamageLogicStrategy = null
@export var vital_comp_name: StringName = &"GameplayVitalAttributeComponent"
@export var vital_id: StringName = &"health"

func _init() -> void:
	if target_blocked_tags.is_empty() and not invulnerable_block_tag.is_empty():
		target_blocked_tags = [invulnerable_block_tag]

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	_apply_result(target, instigator, context)

func _apply_result(target: Node, instigator: Node, context: Dictionary) -> GameplayEffectResult:
	var multiplier: Variant = context.get("damage_multiplier", 1.0)
	var stack_value: Variant = context.get("stacks", 1)
	var strategy_value: Variant = context.get("damage_strategy", damage_strategy)
	if not (multiplier is float or multiplier is int) or not stack_value is int or stack_value < 1:
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	if strategy_value != null and not strategy_value is DamageLogicStrategy:
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	var combined_multiplier: float = damage_multiplier * float(multiplier)
	if not is_finite(combined_multiplier) or combined_multiplier < 0.0:
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	var vital_comp: GameplayVitalAttributeComponent = GameplayAbilitySystem.get_component_by_interface(target, vital_comp_name) as GameplayVitalAttributeComponent
	if not is_instance_valid(vital_comp):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.MISSING_DEPENDENCY)
	var health: HealthVital = vital_comp.get_vital(vital_id) as HealthVital
	if not is_instance_valid(health):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.MISSING_DEPENDENCY)
	var calculation: Dictionary = context.duplicate(true)
	calculation["damage_multiplier"] = combined_multiplier
	var amount: float = DamageCalculator.calculate_final_damage(target, instigator, calculation, strategy_value as DamageLogicStrategy) * int(stack_value)
	if not is_finite(amount):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	if not is_instance_valid(target):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_TARGET)
	var source_value: Variant = context.get("source_node")
	if source_value != null and not source_value is Node:
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	var source: Node = source_value as Node if is_instance_valid(source_value) else null
	var info: GameplayDamageInfo = GameplayDamageInfo.new(instigator if is_instance_valid(instigator) else null, source, amount)
	info.final_damage = amount
	var actual: float = health.apply_damage(info, target)
	var result: GameplayEffectResult = GameplayEffectResult.new(GameplayEffectResult.Status.APPLIED if actual > 0.0 else GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.NONE if actual > 0.0 else GameplayEffectResult.Reason.NO_CHANGE)
	result.outputs = {"final_damage": actual}
	return result
