extends Node
class_name GameplayAttributeComponent

## 游戏性属性组件
## 管理角色的属性系统（攻击力、防御力等）

## 如果传入的属性集不为空，则使用传入的属性集
@export var _active_sets: Array[GameplayAttributeSet] = []
# ID -> Instance（运行时实例）
var _attributes: Dictionary[StringName, GameplayAttributeInstance] = {}

## 当前等级（用于计算 ScalableValue）
var current_level: int = 1 : set = _set_current_level

# 信号：当属性值发生变化时发出
signal attribute_value_changed(id: StringName, new_val: float)
## 等级变化信号
signal level_changed(old_level: int, new_level: int)

## 初始化属性组件
## [param] sets: Array[GameplayAttributeSet] 属性集数组
func initialize(sets: Array[GameplayAttributeSet] = []) -> void:
	if not sets.is_empty():
		_active_sets = sets.duplicate(true)
	
	# 遍历所有属性集，批量创建实例
	for attr_set in _active_sets:
		var new_instances : Dictionary[StringName, GameplayAttributeInstance] = attr_set.instantiate_attributes()
		for id in new_instances:
			var instance = new_instances[id]
			# 设置实例的等级（用于 ScalableValue 计算）
			instance.current_level = current_level
			_register_instance(id, new_instances[id])

	# 再处理依赖关系 (此时所有属性都已存在，可以互相读取)
	for atr_set in _active_sets:
		atr_set.resolve_dependencies(self)

## 获取属性值
## [param] id: StringName 属性ID
## [param] default: float 默认值（如果属性不存在）
## [return] float 属性值
func get_value(id: StringName, default: float = 0.0) -> float:
	if not has_attribute(id):
		push_warning("GameplayAttributeComponent: Attribute with id %s not found" % id)
		return default
	return _attributes[id].get_value()

## 获取属性基础值
## [param] id: StringName 属性ID
## [param] default: float 默认值（如果属性不存在）
## [return] float 属性基础值
func get_base_value(id: StringName, default: float = 0.0) -> float:
	if not has_attribute(id):
		push_warning("GameplayAttributeComponent: Attribute with id %s not found" % id)
		return default
	return _attributes[id].base_value

## 获取属性当前值与基础值的比例 (current / base)
## [param] id: StringName 属性ID
## [param] default_ratio: float 默认比例（如果属性不存在或基础值为0）
## [return] float 比例值
func get_attribute_ratio(id: StringName, default_ratio: float = 1.0) -> float:
	if not has_attribute(id):
		push_warning("GameplayAttributeComponent: Attribute with id %s not found, returning default ratio" % id)
		return default_ratio
		
	var base = _attributes[id].base_value
	if is_zero_approx(base):
		push_warning("GameplayAttributeComponent: Base value of attribute %s is zero, returning default ratio" % id)
		return default_ratio
		
	return _attributes[id].get_value() / base

## 获取属性实例
## [param] id: StringName 属性ID
## [return] GameplayAttributeInstance 属性实例（如果不存在返回 null）
func get_attribute(id: StringName) -> GameplayAttributeInstance:
	return _attributes.get(id, null)

## 设置基础值
## [param] id: StringName 属性ID
## [param] val: float 新的基础值
func set_base_value(id: StringName, val: float) -> bool:
	if has_attribute(id):
		_attributes[id].base_value = val
		return true
	push_warning("AttributeComponent: can not set base value: %s" %id)
	return false

## 检查属性是否存在
## [param] id: StringName 属性ID
## [return] bool 是否存在
func has_attribute(id: StringName) -> bool:
	return _attributes.has(id)

## 添加属性修改器
## [param] mod: GameplayAttributeModifier 修改器实例
func add_modifier(mod: GameplayAttributeModifier) -> void:
	if _attributes.has(mod.attribute_id):
		_attributes[mod.attribute_id].add_modifier(mod)

## 移除属性修改器
## [param] mod: GameplayAttributeModifier 修改器实例
func remove_modifier(mod: GameplayAttributeModifier) -> void:
	if _attributes.has(mod.attribute_id):
		_attributes[mod.attribute_id].remove_modifier(mod)

## 根据 source_id 批量移除属性修改器
## [param] source_id: StringName 来源ID
func remove_modifiers_by_source(source_id: StringName) -> void:
	if source_id.is_empty():
		return

	# 遍历所有属性实例，移除匹配的修改器
	for attribute_id in _attributes.keys():
		var instance = _attributes[attribute_id]
		if is_instance_valid(instance):
			instance.remove_modifiers_by_source(source_id)

## 获取当前等级
## [return] int 当前等级
func get_level() -> int:
	return current_level

## 设置等级（公共接口）
## [param] level: int 新等级
func set_level(level: int) -> void:
	_set_current_level(level)

## 注册属性实例（内部方法）
## [param] id: StringName 属性ID
## [param] instance: GameplayAttributeInstance 属性实例
func _register_instance(id: StringName, instance: GameplayAttributeInstance) -> bool:
	if has_attribute(id):
		push_warning("Attribute with id %s already registered" % id)
		return false
	_attributes[id] = instance
	# 转发信号：当实例值变化时，组件也发出信号
	instance.value_changed.connect(
		func(old, new) -> void: 
			attribute_value_changed.emit(id, new)
			_handle_dependency(id, new)
	)
	return true

## 处理依赖关系
## [param] attr_id: StringName 变化的属性ID
## [param] new_val: float 新值
func _handle_dependency(attr_id: StringName, new_val: float) -> void:
	# 通知所有 Set，看看有没有人关心这个属性的变化
	for attribute_set in _active_sets:
		attribute_set.on_attribute_changed(self, attr_id, new_val)

## 设置等级（会更新所有使用 ScalableValue 的属性）
func _set_current_level(level: int) -> void:
	if current_level == level: 
		return
	var old_level = current_level
	current_level = max(1, level)

	# 更新所有使用 ScalableValue 的属性实例
	for instance in _attributes.values():
		if is_instance_valid(instance):
			instance.current_level = current_level
	level_changed.emit(old_level, current_level)
