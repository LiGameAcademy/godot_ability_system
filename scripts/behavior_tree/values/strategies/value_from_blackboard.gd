extends BTValueStrategy
class_name ValueFromBlackboard

## [策略] 从黑板获取值
## 从行为树黑板中读取指定 Key 的值

@export var key: String = ""
@export var default_value: Variant

func _get_value(context: Dictionary, blackboard: GAS_BTBlackboard) -> Variant:
	# 1. 有效性检查
	if not is_instance_valid(blackboard):
		return default_value
		
	# 2. 读取值		
	return blackboard.get_var(key, default_value)
