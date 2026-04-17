extends GAS_BTObserver
class_name GAS_BTCheckVarDecorator

@export var key: String
@export var value: Variant
@export var check_exist_only: bool = false

# 重写：判断黑板变更是否相关
func is_relevant(changed_key: String) -> bool:
	return changed_key == key

# 重写：具体的检查逻辑
func check_condition(instance: GAS_BTInstance) -> bool:
	if not _has_var(instance, key):
		return false
	if check_exist_only:
		return true
	return _get_var(instance, key) == value
