@abstract
extends Resource
class_name GameplayEffect

## 配置保持只读；运行输出通过 GameplayEffectResult 返回。
enum ChildFailurePolicy { STOP_ON_FAILURE, CONTINUE }
## 所有过滤器通过后才执行；空项按配置错误处理。
@export var filters: Array[GameplayFilterData] = []
## 主效果生效后按顺序执行，失败策略由 child_failure_policy 决定。
@export var sub_effects: Array[GameplayEffect] = []
@export var child_failure_policy: ChildFailurePolicy = ChildFailurePolicy.STOP_ON_FAILURE
@export_group("Tag Requirements")
## 目标需要拥有全部标签。
@export var target_required_tags: Array[StringName] = []
## 目标拥有任意标签时，返回免疫而不执行。
@export var target_blocked_tags: Array[StringName] = []
@export_group("Visual Feedback")
## 主效果实际生效后播放；子效果失败不撤销已经播放的表现。
@export var cue: GameplayCue = null

func apply(target: Node, instigator: Node, context: Dictionary = {}) -> GameplayEffectResult:
	var result: GameplayEffectResult = _apply_chain(target, instigator, context.duplicate(true), [self])
	# 保留已发布的单目标 final_damage 输出，其他新输出从结果读取。
	if result.outputs.has("final_damage"):
		context["final_damage"] = result.outputs["final_damage"]
	return result

func _apply_chain(target: Node, instigator: Node, context: Dictionary, ancestors: Array[GameplayEffect]) -> GameplayEffectResult:
	var target_id: int = target.get_instance_id() if is_instance_valid(target) else 0
	var blocked: GameplayEffectResult = _check_requirements(target, instigator, context)
	if is_instance_valid(blocked):
		return _identify(blocked, target_id)
	var primary: GameplayEffectResult = _apply_result(target, instigator if is_instance_valid(instigator) else null, context)
	if not is_instance_valid(primary):
		primary = GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	_identify(primary, target_id)
	if not primary.did_apply():
		return primary
	context.merge(primary.outputs, true)
	if is_instance_valid(target) and is_instance_valid(cue):
		_execute_cue(target, context.duplicate(true))
	var results: Array[GameplayEffectResult] = [primary]
	for template: GameplayEffect in sub_effects:
		var child: GameplayEffectResult
		if not is_instance_valid(target):
			child = GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_TARGET)
		elif not is_instance_valid(template) or ancestors.has(template) or ancestors.size() >= 64:
			child = GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
		else:
			# 只复制运行对象；嵌套配置只读，避免深复制循环效果结构。
			var runtime: GameplayEffect = template.duplicate(false) as GameplayEffect
			var path: Array[GameplayEffect] = ancestors.duplicate()
			path.append(template)
			child = runtime._apply_chain(target, instigator if is_instance_valid(instigator) else null, context.duplicate(true), path)
		if child.target_id == 0:
			child.target_id = target_id
		results.append(child)
		if child.has_failure() and child_failure_policy == ChildFailurePolicy.STOP_ON_FAILURE:
			break
	var combined: GameplayEffectResult = GameplayEffectResult.aggregate(results)
	combined.outputs = primary.outputs.duplicate(true)
	return _identify(combined, target_id)

func _identify(result: GameplayEffectResult, target_id: int) -> GameplayEffectResult:
	result.target_id = target_id
	result.effect_path = resource_path if not resource_path.is_empty() else (get_script() as Script).resource_path
	return result

## 旧 void 钩子仍能执行，但不能据此认定生效，也不继续 Cue / 子效果。
func _apply_result(target: Node, instigator: Node, context: Dictionary) -> GameplayEffectResult:
	_apply(target, instigator, context)
	return GameplayEffectResult.new(GameplayEffectResult.Status.UNVERIFIED, GameplayEffectResult.Reason.LEGACY_UNVERIFIED)

func _check_requirements(target: Node, instigator: Node, context: Dictionary) -> GameplayEffectResult:
	if not is_instance_valid(target):
		return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_TARGET)
	for filter: GameplayFilterData in filters:
		if not is_instance_valid(filter):
			return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
		var accepted: bool = filter.check(target, instigator if is_instance_valid(instigator) else null, context.duplicate(true))
		if not is_instance_valid(target):
			return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_TARGET)
		if not accepted:
			return GameplayEffectResult.new(GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.FILTERED)
	if not target_blocked_tags.is_empty() and TagManager.has_any_tag(target, target_blocked_tags):
		return GameplayEffectResult.new(GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.IMMUNE)
	if not target_required_tags.is_empty() and not TagManager.has_all_tags(target, target_required_tags):
		return GameplayEffectResult.new(GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.REQUIRED_TAG_MISSING)
	return null

func _check_filters(target: Node, instigator: Node, context: Dictionary) -> bool:
	return not is_instance_valid(_check_requirements(target, instigator, context))

func _execute_cue(target: Node, context: Dictionary) -> void:
	GameplayCueManager.execute_cue(cue, target, context)

## 兼容入口可传入 application；没有句柄时仅执行旧扩展的移除钩子。
func remove(target: Node, instigator: Node, context: Dictionary = {}) -> void:
	var application: Variant = context.get("application")
	if application is GameplayEffectApplication:
		(application as GameplayEffectApplication).revoke()
		return
	if not is_instance_valid(target):
		return
	_remove(target, instigator, context)
	for template: GameplayEffect in sub_effects:
		if is_instance_valid(template):
			var runtime: GameplayEffect = template.duplicate(true) as GameplayEffect
			runtime.remove(target, instigator, context)

func update_stacks(target: Node, instigator: Node, context: Dictionary, remove_previous: bool) -> void:
	if not is_instance_valid(target) or (not remove_previous and not _check_filters(target, instigator, context)):
		return
	_update_stacks(target, instigator, context, remove_previous)
	for effect: GameplayEffect in sub_effects:
		if is_instance_valid(effect):
			effect.update_stacks(target, instigator, context, remove_previous)

func _update_stacks(_target: Node, _instigator: Node, _context: Dictionary, _remove_previous: bool) -> void:
	pass

func _apply(_target: Node, _instigator: Node, _context: Dictionary) -> void:
	pass

func _remove(_target: Node, _instigator: Node, _context: Dictionary) -> void:
	pass
