extends Resource
class_name GameplayVital

## 属性状态

## Vital 配置字段
@export_group("Identity")
@export var vital_id: StringName = &""  ## Vital ID（唯一标识）
@export var display_name: String = ""   ## 显示名称

@export_group("Attribute Dependencies")
## 决定最大值的属性 ID (如 "health", "mana")
@export var max_value_attribute: StringName = &""
## 决定恢复速度的属性 ID (如 "health_regen", "mana_regen")，留空则不自动恢复
@export var regen_rate_attribute: StringName = &""

# --- 运行时数据 ---
var _owner_comp: GameplayAttributeComponent  ## 属性组件引用
var current_value: float = 0.0  				## 当前值
var _cached_max: float = 0.0     			## 缓存的最大值

# --- 信号 ---
signal value_changed(current: float, max: float, percent: float, is_regen: bool)
signal depleted()  # 归零
signal full()      # 满值

# --- 逻辑 ---
## 初始化 Vital 实例
## 绑定到指定的属性组件并初始化数值
## [param] p_comp: GameplayAttributeComponent 属性组件引用
func initialize(p_comp: GameplayAttributeComponent) -> void:
	_owner_comp = p_comp
	# 初始化数值（必须在设置 _owner_comp 之后）
	_update_cached_max()
	current_value = _cached_max
	# 连接属性变化信号（确保 Vital 能响应属性变化）
	if is_instance_valid(_owner_comp):
		if _owner_comp.attribute_value_changed.is_connected(_on_attribute_changed):
			_owner_comp.attribute_value_changed.disconnect(_on_attribute_changed)
		_owner_comp.attribute_value_changed.connect(_on_attribute_changed)

func create_instance(p_comp: GameplayAttributeComponent) -> GameplayVital:
	var instance : GameplayVital = duplicate(true)
	instance.initialize(p_comp)
	return instance

## 处理恢复
func process_regen(delta: float):
	if regen_rate_attribute == &"": return
	
	var rate = _owner_comp.get_value(regen_rate_attribute)
	if rate != 0:
		modify_value(rate * delta, true)

## 修改值
## [param] amount: float 修改量（正数为增加，负数为减少）
## [param] is_regen: bool 是否为自动回复（默认 false）
## 注意：depleted 和 full 信号始终会发射（如果条件满足）
func modify_value(amount: float, is_regen: bool = false) -> void:
	_modify_value(amount, is_regen)

## 扣除已经汇总的内置 Vital 费用。全部检查通过后写入，再发送变化通知。
## payments 保存本次实际扣款额；本入口不处理冷却、退款或重复提交。
static func try_pay_batch(payments: Dictionary[GameplayVital, float]) -> bool:
	var batch: VitalCostBatch = VitalCostBatch.new([], null)
	batch.payments = payments.duplicate()
	return batch.try_pay()

## 获取最大值
## [return] float 当前的最大值
func get_max_value() -> float:
	return _cached_max

## 获取百分比
## [return] float 百分比（0.0-1.0）
func get_percent() -> float:
	return current_value / _cached_max if _cached_max > 0 else 0.0

## 更新缓存的最大值
func _update_cached_max() -> void:
	if not is_instance_valid(_owner_comp):
		push_error("Vital: _owner component is not valid!")
		return
	var old_max = _cached_max
	_cached_max = _owner_comp.get_value(max_value_attribute)
	if old_max != _cached_max:
		value_changed.emit(current_value, _cached_max, get_percent(), false)

func _modify_value(amount: float, is_regen: bool = false) -> void:
	_update_cached_max()
	var old_val = current_value
	current_value = clampf(current_value + amount, 0.0, _cached_max)
	
	if old_val == current_value: return

	value_changed.emit(current_value, _cached_max, get_percent(), is_regen)
	
	if current_value <= 0 and old_val > 0:
		depleted.emit()
	elif current_value >= _cached_max and old_val < _cached_max:
		full.emit()

## 属性变化回调
## [param] attr_id: StringName 变化的属性ID
## [param] val: float 新值
func _on_attribute_changed(attr_id: StringName, val: float) -> void:
	if attr_id != max_value_attribute: return
	_update_cached_max()
	# 策略：最大值变大时，保持当前值不变，但截断上限
	if current_value > _cached_max:
		current_value = _cached_max
		value_changed.emit(current_value, _cached_max, get_percent(), false)
