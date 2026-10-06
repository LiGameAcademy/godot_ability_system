@abstract
extends Resource
class_name GameplayEffect

## 游戏效果基类（抽象类）
## 所有具体效果都继承此类，实现 _apply 方法

# --- 过滤与组合 ---
@export var filters: Array[GameplayFilterData] = []  ## 过滤器，如果为空，则不过滤
@export var sub_effects: Array[GameplayEffect] = []  ## 子效果，支持效果组合

# --- 标签要求（标签系统集成）---
@export_group("Tag Requirements")
## 目标必须拥有的标签（效果生效的前置条件）
## 如果目标没有所有必需的标签，效果不会生效
## 例如：对燃烧状态的目标造成1.5倍伤害，需要设置 target_required_tags = ["status.burn"]
@export var target_required_tags: Array[StringName] = []
## 目标不能拥有的标签（效果生效的阻止条件，如免疫）
## 如果目标拥有任意一个阻止标签，效果不会生效
## 例如：伤害效果默认阻止 state.invulnerable 标签，实现免疫机制
@export var target_blocked_tags: Array[StringName] = []

# --- 视觉反馈（逻辑与表现分离）---
@export_group("Visual Feedback")
## 游戏提示（Cue），用于逻辑与表现分离
## 当效果应用成功时，会执行此 Cue 来播放表现（特效、音效、飘字等）
## 注意：Cue 系统将在 Day 15 详细讲解，这里先预留接口
@export var cue: GameplayCue = null

## 应用效果（核心入口）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: 效果执行上下文
func apply(target: Node, instigator: Node, context: Dictionary = {}) -> void:
	# 1. 检查过滤器（如果被过滤，直接返回）
	if not _check_filters(target, instigator, context):
		return
	
	# 2. 执行具体逻辑（子类实现）
	_apply(target, instigator, context)

	# 3. 执行 Cue（逻辑与表现分离）
	if is_instance_valid(cue):
		_execute_cue(target, context)

	# 4. 递归应用子效果
	_apply_sub_effects(target, instigator, context)

## 移除效果（核心入口）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: 效果执行上下文
func remove(target: Node, instigator: Node, context: Dictionary = {}) -> void:
	# 1. 执行具体移除逻辑（子类实现，默认空实现）
	_remove(target, instigator, context)
	
	# 2. 递归移除子效果
	_remove_sub_effects(target, instigator, context)

## 检查过滤器
## 叠层更新只调用持续效果钩子，不触发 apply/remove 事件或 Cue。
## 状态实例先对所有效果执行移除阶段，再统一执行新层数阶段。
func update_stacks(target: Node, instigator: Node, context: Dictionary, remove_previous: bool) -> void:
	if not remove_previous and not _check_filters(target, instigator, context):
		return
	_update_stacks(target, instigator, context, remove_previous)
	for effect: GameplayEffect in sub_effects:
		if is_instance_valid(effect):
			effect.update_stacks(target, instigator, context, remove_previous)

## 一次性效果默认不响应层数更新；持续修正按需覆写。
func _update_stacks(_target: Node, _instigator: Node, _context: Dictionary, _remove_previous: bool) -> void:
	pass

## 检查过滤器
func _check_filters(target: Node, instigator: Node, context: Dictionary) -> bool:
	# 1. 检查传统过滤器
	for filter : GameplayFilterData in filters:
		if not filter.check(target, instigator, context):
			return false

	# 2. 检查标签要求（标签系统集成）
	# 检查阻止标签（免疫检查）
	if not target_blocked_tags.is_empty():
		if TagManager.has_any_tag(target, target_blocked_tags):
			print("GameplayEffect: Target blocked tags found for effect %s" % get_path())
			return false
			
	# 检查必须标签（连携检查）
	if not target_required_tags.is_empty():
		if not TagManager.has_all_tags(target, target_required_tags):
			print("GameplayEffect: Target required tags not found for effect %s" % get_path())
			return false

	return true

## 执行 Cue（逻辑与表现分离）
func _execute_cue(target: Node, context: Dictionary) -> void:
	if not is_instance_valid(cue):
		return
	
	GameplayCueManager.execute_cue(cue, target, context)

func _apply_sub_effects(target: Node, instigator: Node, context: Dictionary) -> void:
	# 注意：子效果也需要克隆，避免运行时状态共享
	for effect in sub_effects:
		if not is_instance_valid(effect):
			continue
		
		# 克隆子效果实例
		var sub_effect_inst = effect.duplicate(true) as GameplayEffect
		if not is_instance_valid(sub_effect_inst):
			continue
		
		# 递归应用子效果（每个子效果会自己执行完整的 apply 流程）
		sub_effect_inst.apply(target, instigator, context)

## 移除子效果（内部方法，供基类和子类使用）
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: 上下文信息
func _remove_sub_effects(target: Node, instigator: Node, context: Dictionary) -> void:
	for effect in sub_effects:
		if not is_instance_valid(effect):
			continue
		# 克隆子效果实例
		var sub_effect_inst = effect.duplicate(true) as GameplayEffect
		if not is_instance_valid(sub_effect_inst):
			continue
		
		sub_effect_inst.remove(target, instigator, context)

@abstract func _apply(target: Node, instigator: Node, context: Dictionary)  -> void

## [子类重写] 移除效果的具体实现
## [param] target: Node 目标节点
## [param] instigator: Node 施法者节点
## [param] context: 上下文信息
func _remove(_target: Node, _instigator: Node, _context: Dictionary) -> void:
	# 默认空实现，大多数效果不需要移除逻辑
	pass
