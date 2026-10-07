extends RefCounted
class_name GameplayEffectApplication

## 一次可撤销应用的所有权。配置 ID 和来源标签仅用于识别，不参与撤销选择。
var application_id: StringName:
	get:
		return _application_id
var _application_id: StringName
var config_id: StringName = &""
var source_group: StringName = &""
var _children: Array[GameplayEffectApplication] = []
var _revoked: bool = false
var _updating: bool = false

func _init() -> void:
	_application_id = StringName("effect_application.%s" % get_instance_id())

func add_child(application: GameplayEffectApplication) -> void:
	if is_instance_valid(application) and application != self and not _children.has(application):
		if _revoked:
			application.revoke()
		else:
			_children.append(application)

func is_revoked() -> bool:
	return _revoked

## 先标记已撤销，使信号回调中的重复撤销也保持幂等。
func revoke() -> void:
	if _revoked:
		return
	_revoked = true
	_revoke()
	for child: GameplayEffectApplication in _children:
		child.revoke()
	_children.clear()

## 只更新已经创建的持续应用，不重新执行初次逻辑或 Cue。
func set_stacks(stacks: int) -> void:
	if _revoked or _updating or stacks < 1:
		return
	_updating = true
	_set_stacks(stacks)
	for child: GameplayEffectApplication in _children.duplicate():
		if _revoked:
			break
		child.set_stacks(stacks)
	_updating = false

func _revoke() -> void:
	pass

func _set_stacks(_stacks: int) -> void:
	pass
