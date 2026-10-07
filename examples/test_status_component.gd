extends Node3D

const BURN_STATUS: GameplayStatusData = preload("burn_status.tres")
@onready var status_comp: GameplayStatusComponent = %GameplayStatusComponent
signal example_completed()

func _ready() -> void:
	var registered_here: Array[StringName] = []
	for tag_id: StringName in BURN_STATUS.tags:
		if not TagManager.is_tag_registered(tag_id):
			var tag: GameplayTag = GameplayTag.new()
			tag.id = tag_id
			TagManager.register_tag(tag)
			registered_here.append(tag_id)
	var burn: GameplayStatusData = BURN_STATUS
	status_comp.apply_status(burn, self, 1, {})
	status_comp.apply_status(burn, self, 1, {})
	var instance: GameplayStatusInstance = status_comp.get_status(&"burn")
	assert(is_instance_valid(instance) and instance.stacks == 2)
	status_comp.remove_statuses_by_tags([&"status.burn"])
	assert(not status_comp.has_status(&"burn"))
	for tag_id: StringName in registered_here:
		TagManager.unregister_tag(tag_id)
	print("状态示例通过：叠层、按标签移除")
	example_completed.emit()
