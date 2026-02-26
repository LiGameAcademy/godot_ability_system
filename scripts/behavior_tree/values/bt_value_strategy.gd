@abstract
extends Resource
class_name BTValueStrategy

## [抽象基类] 行为树数值获取策略
## 用于从各种来源 (黑板、Context、属性等) 获取任意类型的值
## 区别于 TargetingStrategy ，它不局限于获取 Node 数组，也不进行筛选

## 获取值
## [param] context: 技能执行上下文 (包含 instigator, target_unit, etc.)
## [param] blackboard: 行为树黑板 (可选，部分策略可能需要)
## [return] Variant: 获取到的值 (可能为 null)
func get_value(context: Dictionary, blackboard: GAS_BTBlackboard = null) -> Variant:
	return _get_value(context, blackboard)

## [子类重写] 具体获取逻辑
@abstract func _get_value(_context: Dictionary, _blackboard: GAS_BTBlackboard) -> Variant
