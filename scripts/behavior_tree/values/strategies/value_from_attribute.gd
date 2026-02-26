extends BTValueStrategy
class_name ValueFromAttribute

## [策略] 从属性组件获取值
## 使用 GameplayVitalAttributeComponent 接口获取属性值

@export var attribute_name: StringName
@export var default_value: float = 0.0

func _get_value(context: Dictionary, _blackboard: GAS_BTBlackboard) -> Variant:
	var instigator = context.get("instigator")
	if not is_instance_valid(instigator):
		return default_value
		
	var component = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayVitalAttributeComponent")
	
	if is_instance_valid(component):
		return component.get_value(attribute_name, default_value)
		
	return default_value
