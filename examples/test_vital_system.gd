extends Node3D

@export var player_data: PlayerData = null

@onready var vital_component: GameplayVitalAttributeComponent = $GameplayVitalAttributeComponent

@export var damage_strategy: DamageLogicStrategy = null

func _ready() -> void:
	if not is_instance_valid(player_data):
		push_error("PlayerData is not set")
		return

	# 初始化属性系统
	vital_component.initialize(player_data.attribute_sets, player_data.vitals)

	# 监听信号
	vital_component.vital_value_changed.connect(_on_vital_changed)
	vital_component.vital_depleted.connect(_on_vital_depleted)

	## 设置自定义伤害策略（如果提供）
	#if is_instance_valid(damage_strategy):
		#DamageCalculator.set_strategy(damage_strategy)
		#print("Using custom damage strategy: %s" % damage_strategy.get_script().get_path())

	# 运行测试
	await get_tree().create_timer(0.5).timeout
	_run_tests()

func _run_tests() -> void:
	print("\n=== Day 07: Testing Vital System (Basic) ===")
	
	# 测试 1：初始状态
	_test_initial_state()
	await get_tree().create_timer(1.0).timeout
	
	# 测试 2：Vital 操作 API
	_test_vital_api()
	await get_tree().create_timer(1.0).timeout
	
	# 测试 3：属性变化时 Vital 联动
	_test_attribute_vital_linkage()
	await get_tree().create_timer(1.0).timeout
	
	# 测试 4：自动回复（如果有配置）
	await _test_auto_regen()
	
	# 测试 5：基础伤害计算
	await _test_basic_damage()
	
	# 测试 6：策略切换
	await _test_strategy_switch()

	# 测试 7：防御力影响
	await _test_defense_impact()

## 测试 1：初始状态
func _test_initial_state() -> void:
	print("\n--- Test 1: Initial State ---")
	var health_vital = vital_component.get_vital(&"health")
	if is_instance_valid(health_vital):
		print("Health: %.1f / %.1f (%.1f%%)" % [
			health_vital.current_value,
			health_vital._cached_max,
			health_vital.get_percent() * 100.0
		])
	var mana_vital = vital_component.get_vital(&"mana")
	if is_instance_valid(mana_vital):
		print("Mana: %.1f / %.1f (%.1f%%)" % [
			mana_vital.current_value,
			mana_vital._cached_max,
			mana_vital.get_percent() * 100.0
		])

## 测试 2：Vital 操作 API
func _test_vital_api() -> void:
	print("\n--- Test 2: Vital API ---")
	# 测试 has_vital
	print("Has health: %s" % vital_component.has_vital(&"health"))
	print("Has mana: %s" % vital_component.has_vital(&"mana"))
	
	# 测试 get_vital_value
	var health_value = vital_component.get_vital_value(&"health")
	print("Health value: %.1f" % health_value)
	
	# 测试 modify_vital
	print("Before modify: %.1f" % health_value)
	vital_component.modify_vital(&"health", -20.0)
	await get_tree().process_frame
	print("After -20 HP: %.1f" % vital_component.get_vital_value(&"health"))
	
	# 测试 has_sufficient_vital
	print("Has sufficient health (50): %s" % vital_component.has_sufficient_vital(&"health", 50.0))
	print("Has sufficient health (271): %s" % vital_component.has_sufficient_vital(&"health", 271.0))

## 测试 3：属性变化时 Vital 联动
func _test_attribute_vital_linkage() -> void:
	print("\n--- Test 3: Attribute-Vital Linkage ---")
	var health_vital = vital_component.get_vital(&"health")
	if not is_instance_valid(health_vital): return
	
	var old_max = health_vital.get_max_value()
	var old_current = health_vital.current_value
	
	print("Before: %.1f / %.1f" % [old_current, old_max])
	# 增加体质属性
	var current_vitality = vital_component.get_value(&"vitality")
	vital_component.set_base_value(&"vitality", current_vitality + 10.0)

	await get_tree().process_frame
	print("After +10 Vitality:")
	print("  Max Health: %.1f (was %.1f)" % [health_vital._cached_max, old_max])
	print("  Current Health: %.1f (should remain %.1f)" % [health_vital.current_value, old_current])

	# 验证
	assert(health_vital.current_value == old_current, "Current HP should remain unchanged")
	assert(health_vital._cached_max > old_max, "Max HP should increase")

## 测试 4：自动回复
func _test_auto_regen() -> void:
	print("\n--- Test 4: Auto Regen ---")
	
	var mana_vital = vital_component.get_vital(&"mana")
	if not is_instance_valid(mana_vital):
		print("Mana vital not found, skipping regen test")
		return
	
	# 消耗一些法力
	var current_mana = mana_vital.current_value
	vital_component.modify_vital(&"mana", -30.0)
	await get_tree().process_frame
	
	print("After -30 Mana: %.1f / %.1f" % [mana_vital.current_value, mana_vital._cached_max])

	# 等待几秒，观察自动回复（如果有配置）
	print("Waiting 3 seconds for regen...")
	await get_tree().create_timer(3.0).timeout

	print("After 3 seconds: %.1f / %.1f" % [mana_vital.current_value, mana_vital._cached_max])
	# 注意：如果 regen_rate_attribute 未配置，法力值不会自动回复

## 测试 5：基础伤害计算
func _test_basic_damage() -> void:
	print("\n--- Test 5: Basic Damage Calculation ---")

	var health_vital = vital_component.get_vital(&"health")
	if not is_instance_valid(health_vital): return
	
	print("Initial Health: %.1f / %.1f" % [health_vital.current_value, health_vital.get_max_value()])
	
	# 创建伤害信息
	var damage_info = GameplayDamageInfo.new(self, null, 50.0)  # 50 点基础伤害
	
	# 应用伤害
	var final_damage = health_vital.apply_damage(damage_info, self)
	
	print("Base Damage: %.1f" % damage_info.base_damage)
	print("Final Damage: %.1f" % final_damage)
	print("After Damage: %.1f / %.1f" % [health_vital.current_value, health_vital.get_max_value()])

	# 验证：最终伤害应该小于等于基础伤害（因为防御力）
	assert(final_damage <= damage_info.base_damage, "Final damage should be <= base damage")

## 测试 6：策略切换
func _test_strategy_switch() -> void:
	print("\n--- Test 6: Strategy Switch ---")
	
	var health_vital = vital_component.get_vital(&"health")
	if not is_instance_valid(health_vital): return

	# 使用默认策略
	print("Using default strategy (SimpleDamageLogic)")
	var damage_info1 = GameplayDamageInfo.new(self, null, 50.0)
	var final_damage1 = health_vital.apply_damage(damage_info1, self)
	print("Final Damage: %.1f" % final_damage1)
	
	await get_tree().process_frame

	# 切换到自定义策略
	if is_instance_valid(damage_strategy):
		DamageCalculator.set_strategy(damage_strategy)
		print("Switched to custom strategy")

		var damage_info2 = GameplayDamageInfo.new(self, null, 50.0)
		var final_damage2 = health_vital.apply_damage(damage_info2, self)
		print("Final Damage (custom): %.1f" % final_damage2)

## 测试 7：防御力影响
func _test_defense_impact() -> void:
	print("\n--- Test 7: Defense Impact ---")
	
	var health_vital = vital_component.get_vital(&"health")
	if not is_instance_valid(health_vital): return
	
	# 记录初始防御力
	var initial_defense = vital_component.get_value(&"defense")
	print("Initial Defense: %.1f" % initial_defense)

	# 测试 1：低防御力
	var damage_info1 = GameplayDamageInfo.new(self, null, 50.0)
	var final_damage1 = health_vital.apply_damage(damage_info1, self)
	print("Damage with Defense %.1f: %.1f" % [initial_defense, final_damage1])
	await get_tree().process_frame

	# 增加防御力
	vital_component.set_base_value(&"defense", initial_defense + 20.0)
	await get_tree().process_frame
	print("New Defense: %.1f" % vital_component.get_value(&"defense"))
	
	# 测试 2：高防御力
	var damage_info2 = GameplayDamageInfo.new(self, null, 50.0)
	var final_damage2 = health_vital.apply_damage(damage_info2, self)
	print("Damage with Defense %.1f: %.1f" % [vital_component.get_value(&"defense"), final_damage2])

	# 验证：防御力越高，受到的伤害越少
	assert(final_damage2 < final_damage1, "Higher defense should reduce damage")

func _on_vital_changed(vital_id: StringName, current: float, max: float, percent: float, is_regen: bool) -> void:
	if is_regen: return
	print("Vital [%s] changed: %.1f / %.1f (%.1f%%)" % [vital_id, current, max, percent * 100.0])
	
func _on_vital_depleted(vital_id: StringName) -> void:
	print("⚠️ Vital [%s] depleted!" % vital_id)
