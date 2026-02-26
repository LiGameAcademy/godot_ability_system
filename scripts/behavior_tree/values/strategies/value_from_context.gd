extends BTValueStrategy
class_name ValueFromContext

## [策略] 从上下文获取值
## 从 Context 字典中读取指定 Key 的值

@export var key: String = ""
@export var default_value: Variant

func _get_value(context: Dictionary, _blackboard: GAS_BTBlackboard) -> Variant:
	return context.get(key, default_value)
