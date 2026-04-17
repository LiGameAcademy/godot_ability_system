extends GameplayVital
class_name HealthVital

## 生命值 Vital
## 处理伤害、治疗、死亡等逻辑

const DEATH_GROUP_NAME: String = "death"

## 是否存活
var is_alive: bool:
	get:
		return current_value > 0

func _init(p_comp: GameplayAttributeComponent = null) -> void:
	# 设置 HealthVital 的默认值（在调用 super 之前设置）
	vital_id = &"health"
	display_name = "生命值"
	max_value_attribute = &"max_health"  # 依赖 "health" 属性作为上限
	#regen_rate_attribute = &"health_regen"  # 可选：自动回复

## 生命值恢复信号
signal health_restored()
## 生命值耗尽信号
signal health_depleted(instigator: Node)
## 接受伤害时发出（在计算减免之前）
signal damage_received(damage_info: GameplayDamageInfo)
## 受到伤害时发出（在计算减免之后）
signal damage_applied(damage_info: GameplayDamageInfo, final_damage: float)

func modify_value(amount: float, is_regen: bool = false) -> void:
	if amount >= 0:
		heal(amount)
	else:
		_modify_value(amount, is_regen)

## 核心伤害应用接口
## [param] damage_info: GameplayDamageInfo 伤害信息
## [param] owner_entity: Node 拥有者实体
## [return] float 最终伤害值（用于 Cue 系统）
func apply_damage(damage_info: GameplayDamageInfo, owner_entity: Node) -> float:
	if not is_alive: return 0.0
	# 发出伤害接收信号（在计算减免之前）
	damage_received.emit(damage_info)
	AbilityEventBus.trigger_game_event(&"damage_received", {
		"damage_info": damage_info
	})
	
	# 在应用伤害前被BUFF修改为0或更少
	var final_damage = damage_info.final_damage
	if final_damage <= 0: return 0.0

	# 应用伤害
	if final_damage > 0:
		_modify_value(-final_damage)
	
	# UI系统可以监听这个信号来显示伤害飘字
	damage_applied.emit(damage_info, final_damage)
	AbilityEventBus.trigger_game_event(&"damage_applied", {
		"damage_info": damage_info
	})

	# 处理死亡
	if not is_alive:
		_die(damage_info.instigator, owner_entity)

	# 返回最终伤害值（供 Cue 系统使用）
	return final_damage

## 受到治疗
## [param] amount: float 要增加的生命值数量
func heal(amount: float) -> void:
	if not is_alive: return

	_modify_value(amount)

	# 发出治疗信号
	health_restored.emit()

## 死亡处理
## [param] instigator: Node 造成死亡的实体
## [param] owner_entity: Node 拥有者实体
func _die(instigator: Node, owner_entity: Node) -> void:
	if is_instance_valid(owner_entity):
		owner_entity.add_to_group(DEATH_GROUP_NAME)
	# 发出死亡信号
	health_depleted.emit(instigator)
