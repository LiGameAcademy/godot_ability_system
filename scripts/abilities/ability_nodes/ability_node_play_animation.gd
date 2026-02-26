extends AbilityNodeBase
class_name AbilityNodePlayAnimation

enum CastTargetType{
	INSTIGATOR,			## 施法者
	TARGET,				## 目标
}

@export var cast_target_type : CastTargetType = CastTargetType.INSTIGATOR
@export var animation_name: StringName = ""
@export var animation_speed: float = 1.0
@export var play_animation_method: StringName = "play_animation"

## [生命周期] 节点激活时调用（只跑一次）
func _enter(instance: GAS_BTInstance) -> void:
	# 1. 获取上下文和施法者
	var context = _get_context(instance)
	var final_targets : Array[Node] = []
	if cast_target_type == CastTargetType.INSTIGATOR:
		final_targets.append(context.get("instigator"))
	elif cast_target_type == CastTargetType.TARGET:
		final_targets.append_array(_get_target_list(instance, false))
	
	if final_targets.is_empty():
		return
	
	# 获取时间缩放
	var time_scale: float = instance.blackboard.get_var("time_scale", 1.0)
	var final_speed = animation_speed * time_scale

	for target in final_targets:
		if not is_instance_valid(target):
			continue
		
		if not target.has_method(play_animation_method):
			push_warning("AbilityNodePlayAnimation: 方法 '%s' 在 AbilityInstance 上不存在。动画 '%s' 播放失败。" % [play_animation_method, animation_name])
			continue

		target.call(play_animation_method, animation_name, final_speed)

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	return Status.SUCCESS
