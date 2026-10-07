@abstract
extends Resource
class_name GameplayAbilityFeature

## 特性名称（用于调试和日志）
var feature_name: String = ""

func _init(p_feature_name: String = "") -> void:
	feature_name = p_feature_name if not p_feature_name.is_empty() else get_script().get_path().get_file().get_basename()

## ========== 主动技能钩子（仅对 ActiveAbility 有效）==========
## 初始化
func initialize(_instance: GameplayAbilityInstance) -> void:
	pass

## [子类可重写] 只读解析意图，不修改实例、资源或黑板。
## 返回本次请求的覆盖值；例如关闭切换技能时跳过费用与冷却。
func get_activation_overrides(_ability: GameplayAbilityInstance) -> Dictionary:
	return {}

## [子类可重写] 只读检查。不要写入 context、实例、资源或黑板。
## 需要执行准备的扩展应在 on_activate 中完成。
func can_activate(ability: GameplayAbilityInstance, context: Dictionary) -> bool:
	return true

## 激活
func on_activate(ability: GameplayAbilityInstance, context: Dictionary) -> void:
	pass

## [子类可重写] 技能被取消时的处理
func on_cancel(ability: GameplayAbilityInstance, context: Dictionary) -> void:
	pass

## [子类可重写] 技能完成时的处理
func on_completed(ability: GameplayAbilityInstance) -> void:
	pass

## ========== 通用钩子（对所有技能类型有效）==========
## [子类可重写] 每帧更新
func update(ability: GameplayAbilityInstance, delta: float) -> void:
	pass

## ========== 被动技能钩子 ==========
## [子类可重写] 技能学习时的处理
func on_learned(ability: GameplayAbilityInstance, ability_comp: Node) -> void:
	pass

## [子类可重写] 技能遗忘时的处理
func on_forgotten(ability: GameplayAbilityInstance, ability_comp: Node) -> void:
	pass

## [子类可重写] 获取特性描述（用于UI显示）
func get_description() -> String:
	return ""

## [子类可重写] 获取动画名称
func get_animation_name() -> StringName:
	return &""

## 获取当前技能实例中 Feature 的持久数据，不依赖执行黑板键。
func _get_data(instance: GameplayAbilityInstance, key: String, default: Variant = null) -> Variant:
	return instance.get_feature_data(feature_name, key, default)

func _set_data(instance: GameplayAbilityInstance, key: String, value: Variant) -> void:
	instance.set_feature_data(feature_name, key, value)
