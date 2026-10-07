extends Node3D

@export var attribute_sets: Array[GameplayAttributeSet] = []
@export var vitals: Array[GameplayVital] = []
@export var damage_effect_res: GE_ApplyDamage = null
@export var heal_effect_res: GE_ModifyVital = null
@onready var player: Node3D = $Player
@onready var enemy: Node3D = $Enemy
@onready var player_vital_component: GameplayVitalAttributeComponent = $Player/GameplayVitalAttributeComponent
@onready var enemy_vital_component: GameplayVitalAttributeComponent = $Enemy/GameplayVitalAttributeComponent
signal example_completed()

func _ready() -> void:
	player_vital_component.initialize(attribute_sets, vitals)
	enemy_vital_component.initialize(attribute_sets, vitals)
	var immunity: GameplayTag = GameplayTag.new()
	immunity.id = &"state.invulnerable"
	var registered_here: bool = not TagManager.is_tag_registered(immunity.id)
	if registered_here:
		TagManager.register_tag(immunity)
	var health: GameplayVital = enemy_vital_component.get_vital(&"health")
	var before: float = health.current_value
	damage_effect_res.apply(enemy, player, {})
	assert(health.current_value < before)
	# 两个实例共享配置，伤害只改变目标的运行时生命。
	assert(is_equal_approx(player_vital_component.get_vital_value(&"health"), before))
	heal_effect_res.apply(enemy, player, {})
	assert(is_equal_approx(health.current_value, before))
	TagManager.add_tag(enemy, immunity.id)
	damage_effect_res.apply(enemy, player, {})
	assert(is_equal_approx(health.current_value, before))
	TagManager.remove_tag(enemy, immunity.id)
	if registered_here:
		TagManager.unregister_tag(immunity.id)
	print("效果示例通过：伤害、治疗、标签免疫、角色隔离")
	example_completed.emit()
