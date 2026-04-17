extends GAS_BTAction
class_name GAS_BTSetVar

## 设置黑板变量节点
## 通用的设置黑板变量的节点，支持任意类型的值
##
## 用途：
## - 设置图标ID：配合 DynamicIconFeature 使用
## - 设置状态标志：用于条件判断
## - 设置任意运行时数据：供其他节点使用
##
## 示例：
## - 设置图标ID：variable_key = "current_icon_id", value = "active"
## - 清除变量：value = null（会清除黑板中的变量）

@export var variable_key: String = ""   ## 变量键
@export var value: Variant        ## 要设置的值（支持任意类型）

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	if variable_key.is_empty():
		push_warning("GAS_BTSetVar: variable_key is empty!")
		return Status.FAILURE

	# 如果 value 为 null，则清除变量；否则设置变量
	if value == null:
		_clear_var(instance, variable_key)
	else:
		_set_var(instance, variable_key, value)
	
	return Status.SUCCESS
