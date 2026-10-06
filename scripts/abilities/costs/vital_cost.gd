extends AbilityCostBase
class_name VitalCost

## Vital 消耗器
## 消耗指定的 Vital（如魔法值、怒气、能量、生命值等）

@export_group("Vital Cost")
## 要消耗的 Vital ID（如 "mana", "rage", "energy", "health"）
@export var vital_id: StringName = &"mana"
## 消耗数量
@export var amount: float = 10.0
## 是否允许透支（如果为 false，必须完全满足才能消耗）
@export var allow_overdraft: bool = false
## vital组件的称
@export var vital_comp_name : StringName = "GameplayVitalAttributeComponent"

func _can_pay(_ability_comp: Node, instigator: Node) -> bool:
	var vital_comp: GameplayVitalAttributeComponent = _resolve_component(instigator)
	if not is_instance_valid(vital_comp) or not vital_comp.has_vital(vital_id):
		return false
	if allow_overdraft:
		return vital_comp.get_vital_value(vital_id) > 0.0
	return vital_comp.has_sufficient_vital(vital_id, amount)

func _try_pay(_ability_comp: Node, instigator: Node) -> bool:
	var vital_comp: GameplayVitalAttributeComponent = _resolve_component(instigator)
	if not is_instance_valid(vital_comp) or not vital_comp.has_vital(vital_id):
		return false
	if allow_overdraft:
		vital_comp.modify_vital(vital_id, -amount)
		return true
	return vital_comp.modify_vital(vital_id, -amount)

func _get_cost_description() -> String:
	# 描述只依赖配置，不保存上一次查询的角色。
	return "消耗 %s: %.0f" % [vital_id, amount]

func _resolve_component(instigator: Node) -> GameplayVitalAttributeComponent:
	if not is_instance_valid(instigator):
		return null
	return GameplayAbilitySystem.get_component_by_interface(instigator, vital_comp_name) as GameplayVitalAttributeComponent
