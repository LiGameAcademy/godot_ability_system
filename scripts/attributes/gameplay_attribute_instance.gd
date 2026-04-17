extends RefCounted
class_name GameplayAttributeInstance

## 属性运行时实例
## 核心职责：维护 BaseValue，管理 Modifiers，计算 FinalValue

const ModifierType = GameplayAttributeModifier.ModifierType

var attribute_def: GameplayAttribute  					## 属性定义（资源）
var base_value: float = 0.0 : set = _set_base_value		## 基础值
var scalable_value: ScalableValue = null  				## 可扩展数值
var current_level: int = 1 : set = _set_current_level  	## 当前等级

var _modifiers: Dictionary[ModifierType, Array] = {}  	## 修改器列表
# 性能优化
var _cached_final_value: float = 0.0						## 缓存
var _dirty : bool = true									## 脏标记
## 索引：source_id -> Array[GameplayAttributeModifier]（性能优化，用于批量移除）
var _modifiers_by_source_id: Dictionary[StringName, Array] = {}

signal base_value_changed(old_val: float, new_value: float)	## 当基础值实际改变时发出
signal value_changed(old_val: float, new_value: float)		## 当最终值实际改变时发出

func _init(attr_res: GameplayAttribute = null, init_val: float = 0.0, p_scalable_value: ScalableValue = null) -> void:
	attribute_def = attr_res
	scalable_value = p_scalable_value
	
	# 如果设置了 scalable_value，使用它计算初始值
	if is_instance_valid(scalable_value):
		base_value = scalable_value.get_value_at_level(current_level)
	else:
		base_value = init_val

## 获取最终值（当前实现：直接返回基础值，后续会加入 Modifier 计算）
## [return] float 最终值
func get_value() -> float:
	if _dirty:
		_recalculate_value()
	return _cached_final_value

## 设置可扩展数值（会重新计算 base_value）
func set_scalable_value(value: ScalableValue) -> void:
	scalable_value = value
	if is_instance_valid(scalable_value):
		base_value = scalable_value.get_value_at_level(current_level)
		_on_data_changed()

## 添加修改器
## [param] mod: GameplayAttributeModifier 修改器实例
func add_modifier(mod: GameplayAttributeModifier) -> void:
	var _mods : Array = _modifiers.get(mod.modifier_type, [])
	if _mods.has(mod):
		push_warning("AttributeInstance: _modifiers has mod: %s" %mod)
		return
	if not _modifiers.has(mod.modifier_type):
		_modifiers[mod.modifier_type] = []
	_modifiers[mod.modifier_type].append(mod)
	if not mod.source_id.is_empty():
		if not _modifiers_by_source_id.has(mod.source_id):
			_modifiers_by_source_id[mod.source_id] = []
		_modifiers_by_source_id[mod.source_id].append(mod)
	_on_data_changed()

## 移除修改器
## [param] mod: GameplayAttributeModifier 修改器实例
func remove_modifier(mod: GameplayAttributeModifier) -> void:
	var _mods : Array = _modifiers.get(mod.modifier_type, [])
	if not _mods.has(mod):
		push_warning("AttributeInstance: _modifiers not has mod: %s" %mod)
		return
	_modifiers[mod.modifier_type].erase(mod)
	_on_data_changed()

## 根据 source_id 批量移除修改器
## [param] source_id: StringName 来源ID
## 性能优化：使用索引直接查找，避免遍历所有修改器
func remove_modifiers_by_source(source_id: StringName) -> void:
	if source_id.is_empty():
		return
	
	# 使用索引直接查找（O(1) 查找）
	if not _modifiers_by_source_id.has(source_id):
		return

	var mods_to_remove: Array = _modifiers_by_source_id[source_id].duplicate()
	if mods_to_remove.is_empty():
		return

	# 移除所有匹配的修改器
	for mod in mods_to_remove:
		if not is_instance_valid(mod):
			continue

		# 从主列表移除
		var _mods: Array = _modifiers.get(mod.modifier_type, [])
		_mods.erase(mod)

	# 清理索引
	_modifiers_by_source_id.erase(source_id)
	_on_data_changed()

func get_modifers() -> Array[GameplayAttributeModifier]:
	var modifiers : Array[GameplayAttributeModifier]
	for mods in _modifiers.values():
		modifiers.append_array(mods)
	return modifiers

## 重新计算最终值（当前版本：只处理基础值和范围限制）
func _recalculate_value() -> void:
	var final := base_value
	
	# 1. 预计算：先归类，避免多次遍历	
	var override_mods : Array = _modifiers.get(ModifierType.OVERRIDE, [])
	if override_mods.size() > 1:
		push_warning("ArratributeInstance: override modifiers size > 1 !")
		
	if not override_mods.is_empty():
		var mod : GameplayAttributeModifier = override_mods[0]
		final = mod.value
	else:
		var sum_add = 0.0
		var product_mult = 0.0
		for mod in _modifiers.get(ModifierType.ADD, []):
			sum_add += mod.value
		for mod in _modifiers.get(ModifierType.MULTIPLY, []):
			product_mult += mod.value
		# 标准公式：(基础值 + 加法修正) * (1 + 乘法修正总和)
		# 假设 Modifier 的 Multiply 填 0.1 代表增加 10%
		final = (base_value + sum_add) * (1.0 + product_mult)
		
	# 限制范围
	if is_instance_valid(attribute_def):
		final = clampf(final, attribute_def.min_value, attribute_def.max_value)
	else:
		push_warning("AttributeInstance: attribute def is not valid!")
	
	_cached_final_value = final
	_dirty = false

## 设置基础值（会触发重新计算）
func _set_base_value(val: float) -> void:
	if base_value == val:
		return
	
	base_value =val
	_on_data_changed()
	base_value_changed.emit(base_value, val)

## 设置等级（会重新计算 base_value）
func _set_current_level(level: int) -> void:
	if current_level == level: 
		return
	current_level = max(1, level)  # 等级至少为 1
	# 如果设置了 scalable_value，重新计算 base_value
	if is_instance_valid(scalable_value):
		var old_base = base_value
		base_value = scalable_value.get_value_at_level(current_level)
		# 如果 base_value 变化，触发重新计算
		if not is_equal_approx(old_base, base_value):
			_on_data_changed()
	else:
		# 没有 scalable_value，只更新等级标记
		_on_data_changed()

## 内部通知：数据变化时触发重新计算
func _on_data_changed() -> void:
	var old_val = _cached_final_value
	_dirty = true
	var new_val = get_value()
	# 如果值发生变化，发出信号
	if not is_equal_approx(old_val, new_val):
		value_changed.emit(old_val, new_val)
