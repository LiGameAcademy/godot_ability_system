extends GameplayAbilityFeature
class_name EffectModifierFeature

## 效果修改器 Feature
## 在技能激活时，应用效果修改器到 context
##
## 工作原理：
## 1. 在 on_activate 时，遍历所有效果修改器
## 2. 检查修改器是否影响当前技能
## 3. 如果影响，调用修改器的 apply_to_context 方法
## 4. 修改后的 context 会被注入到黑板，供行为树节点读取

## 效果修改器列表（由 外部 注入）
var effect_modifiers: Array[AbilityEffectModifier] = []

## 技能激活时调用
func on_activate(ability: GameplayAbilityInstance, context: Dictionary) -> void:
	if not is_instance_valid(ability):
		return

	# 获取技能ID
	var ability_id: StringName = ability.get_definition().ability_id

	# 遍历所有效果修改器
	for modifier: AbilityEffectModifier in effect_modifiers:
		if not is_instance_valid(modifier):
			continue

		# 检查是否影响此技能
		if not modifier.affects_ability(ability_id):
			continue

		# 应用修改到 context
		modifier.apply_to_context(context)
