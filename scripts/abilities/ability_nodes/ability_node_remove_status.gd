extends AbilityNodeBase
class_name AbilityNodeRemoveStatus

@export var status_ids: Array[StringName] = []

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	# 获取目标列表（使用 instigator 作为回退）
	var target_list = _get_target_list(instance, true)
	if target_list.is_empty():
		return Status.SUCCESS
	# 移除所有目标的状态
	for target in target_list:
		if not is_instance_valid(target):
			continue
		# 获取目标的状态组件
		var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
		if not is_instance_valid(status_comp):
			push_warning("AbilityNodeRemoveStatus: Target %s has no GameplayStatusComponent!" % target.name)
			continue
		# 移除所有指定的状态
		for status_id in status_ids:
			if status_id.is_empty():
				continue
			status_comp.remove_status(status_id)
	return Status.SUCCESS
