extends Resource
class_name GameplayAbilityDefinition

## 是技能的静态定义，包含所有配置信息

@export var ability_id: StringName                  	## 技能的唯一ID
@export var ability_name: String                    	## 技能名称
@export_multiline var description: String           	## 技能描述
@export var icon: Texture							## 技能图标
@export var disabled: bool = false                  	## 技能是否禁用
@export var tags: Array[StringName] = []            	## 技能标签

@export_group("Targeting Preview")
## 预览策略（AbilityPreviewStrategy，用于预览阶段的视觉表现）
## 如果为空，则视为瞬发/无需预览
## 注意：这与行为树中的 TargetingStrategy（目标选择策略）不同
@export var preview_strategy: AbilityPreviewStrategy = null
## 是否开启智能施法（跳过预览，直接向鼠标位置释放）
@export var smart_cast: bool = false

@export_group("Features")
## 技能特性列表（可组合的行为特性）
## 通过组合不同的特性，可以实现复杂的技能行为
@export var features: Array[GameplayAbilityFeature] = []

@export_group("Behavior Logic")
## 核心行为树 (描述技能的具体执行流程)
@export var execution_tree: GAS_BTNode

## 黑板默认数据 (配置参数)
## 这里填写的 Key-Value 会在技能实例化时自动注入到黑板中
## 用途：配置 伤害范围、投射物速度、BUFF持续时间 等
@export var blackboard_defaults: Dictionary = {}

## [核心] 创建运行时实例
## 这将把静态的 Definition 转化为动态的 Instance
func create_instance(owner: Node) -> GameplayAbilityInstance:
	var errors: PackedStringArray = get_configuration_errors()
	if not errors.is_empty():
		push_warning("Ability [%s]: %s" % [ability_id, "; ".join(errors)])
		return null
	var instance: GameplayAbilityInstance = GameplayAbilityInstance.new(owner, self, _get_execution_tree())

	# 默认数据由实例独立复制；这里仅初始化特性。
	# 大部分特性是无状态的 Resource，直接引用即可
	for feature: GameplayAbilityFeature in features:
		if not is_instance_valid(feature):
			continue
		instance.add_feature(feature.feature_name, feature)
	return instance

## 只读校验：返回字段和原因，不修正共享配置。
## 没有执行树的基类定义可用于纯被动特性，但不能主动激活。
func get_configuration_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	var names: Array[String] = []
	for feature: GameplayAbilityFeature in features:
		if not is_instance_valid(feature):
			errors.append("features contains an empty resource")
		elif names.has(feature.feature_name):
			errors.append("duplicate feature: %s" % feature.feature_name)
		else:
			names.append(feature.feature_name)
	return errors

func _get_execution_tree() -> GAS_BTNode:
	return execution_tree

func _check_number(errors: PackedStringArray, field: String, value: float, positive: bool = false) -> void:
	if not is_finite(value) or value < 0.0 or (positive and value == 0.0):
		errors.append("%s must be finite and %s" % [field, "positive" if positive else "non-negative"])

func _check_quick_features(errors: PackedStringArray, quick_costs: Array[AbilityCostBase], quick_cooldown: float, quick_input: StringName = &"") -> void:
	for cost: AbilityCostBase in quick_costs:
		if not is_instance_valid(cost):
			errors.append("costs contains an empty resource")
	for feature: GameplayAbilityFeature in features:
		if not is_instance_valid(feature):
			continue
		if not quick_costs.is_empty() and feature.feature_name == "CostFeature":
			errors.append("costs conflicts with explicit CostFeature; keep one configuration")
		if quick_cooldown > 0.0 and feature.feature_name == "CooldownFeature":
			errors.append("cooldown_duration conflicts with explicit CooldownFeature; keep one configuration")
		if not quick_input.is_empty() and feature.feature_name == "AbilityInputFeature":
			errors.append("input_action conflicts with explicit AbilityInputFeature; keep one configuration")
