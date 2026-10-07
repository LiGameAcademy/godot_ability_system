@abstract
extends Resource
class_name AbilityEffectModifier

## 项目通过这个小接口提供天赋等效果修改器，插件不引用业务类名。
## 配置保持只读，修改仅作用于本次激活的 context。
@abstract func affects_ability(ability_id: StringName) -> bool
@abstract func apply_to_context(context: Dictionary) -> void
