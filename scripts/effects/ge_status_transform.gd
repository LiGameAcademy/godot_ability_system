extends GameplayEffect
class_name GE_StatusTransform

@export_group("Match Config")
@export var match_tags: Array[StringName] = []
@export var require_all_tags: bool = false
@export var remove_matched_statuses: bool = true
@export_group("Transform Result")
@export var statuses_to_apply: Dictionary[GameplayStatusData, int] = {}

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	_apply_result(target, instigator, context)

func _apply_result(target: Node, instigator: Node, context: Dictionary) -> GameplayEffectResult:
	if match_tags.is_empty() and statuses_to_apply.is_empty():
		return GameplayEffectResult.new(GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.NO_CHANGE)
	if not _check_match_tags(target):
		return GameplayEffectResult.new(GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.FILTERED)
	for data: GameplayStatusData in statuses_to_apply:
		if not is_instance_valid(data) or statuses_to_apply[data] < 1 or data.max_stacks < 1 or not is_finite(data.duration):
			return GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
	var results: Array[GameplayEffectResult] = []
	if remove_matched_statuses and not match_tags.is_empty():
		var dispel: GE_DispelStatus = GE_DispelStatus.new()
		dispel.tags_to_remove = match_tags
		var removed: GameplayEffectResult = dispel.apply(target, instigator, context.duplicate(true))
		results.append(removed)
		if removed.has_failure():
			return GameplayEffectResult.aggregate(results)
	for data: GameplayStatusData in statuses_to_apply:
		if not is_instance_valid(target):
			results.append(GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_TARGET))
			break
		var effect: GE_ApplyStatus = GE_ApplyStatus.new()
		effect.status_data = data
		effect.stacks = statuses_to_apply[data]
		# 转换配置是此处权威来源，不继承外层的 status_data/status_stacks 覆盖。
		var request: Dictionary = context.duplicate(true)
		request.erase("status_data")
		request.erase("status_stacks")
		var applied: GameplayEffectResult = effect.apply(target, instigator if is_instance_valid(instigator) else null, request)
		results.append(applied)
		if applied.has_failure() and child_failure_policy == ChildFailurePolicy.STOP_ON_FAILURE:
			break
	return GameplayEffectResult.aggregate(results)

func _check_match_tags(target: Node) -> bool:
	if match_tags.is_empty():
		return true
	return TagManager.has_all_tags(target, match_tags) if require_all_tags else TagManager.has_any_tag(target, match_tags)
