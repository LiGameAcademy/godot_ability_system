extends GAS_BTAction
class_name GAS_BTCheckVar

@export var key: String = ""
@export var value: Variant
# 只检查参数是否存在
@export var check_exist_only: bool = false

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	if key.is_empty():
		push_warning("BTCheckVarAction: key is empty!")
		return Status.FAILURE

	# 检查变量是否存在
	if not _has_var(instance, key):
		return Status.FAILURE

	# 如果只检查存在性，返回成功
	if check_exist_only:
		return Status.SUCCESS
		
	# 检查变量值是否匹配
	var var_value = _get_var(instance, key)
	if var_value == value:
		return Status.SUCCESS
	else:
		return Status.FAILURE
