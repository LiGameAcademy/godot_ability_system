extends GameplayAbilityFeature
class_name PassiveStatusFeature

@export_group("Status Settings")
## 学习时应用的状态列表
@export var statuses: Dictionary[GameplayStatusData, int] = {}

## 技能学习时应用状态
func on_learned(ability: GameplayAbilityInstance, ability_comp: Node) -> void:
	if statuses.is_empty():
		return

	# 获取状态组件
	var status_comp : GameplayStatusComponent = _get_status_component(ability_comp)
	if not is_instance_valid(status_comp):
		return

	# 获取施法者（实体）
	var instigator: Node = _get_instigator(ability_comp)
	if not is_instance_valid(instigator):
		return

	var context: Dictionary = {
		"source_id": ability.get_definition().ability_id,
		"ability_instance": ability
	}

	# 应用所有状态
	for status_data: GameplayStatusData in statuses:
		if not is_instance_valid(status_data):
			continue
		
		var stacks : int = statuses[status_data]
		status_comp.apply_status(status_data, instigator, stacks, context)

		# 学习记录属于实例持久状态，不随一次施法的黑板清理。
		var status_id: StringName = status_data.status_id
		if not status_id.is_empty():
			var applied_statuses: Array[StringName] = _get_applied_statuses(ability)
			if not applied_statuses.has(status_id):
				applied_statuses.append(status_id)
			_set_applied_statuses(ability, applied_statuses)

## 技能遗忘时移除状态
func on_forgotten(ability: GameplayAbilityInstance, ability_comp: Node) -> void:
	# 获取状态组件
	var status_comp: GameplayStatusComponent = _get_status_component(ability_comp)
	if not is_instance_valid(status_comp):
		return

	# 获取已应用的状态ID列表
	var applied_statuses: Array[StringName] = _get_applied_statuses(ability)

	# 移除所有已应用的状态
	for status_id: StringName in applied_statuses:
		if not status_id.is_empty():
			status_comp.remove_status(status_id)

	# 清空已应用状态列表
	_set_applied_statuses(ability, [])

## 获取状态组件
## [param] ability_comp: Node 技能组件
## [return] GameplayStatusComponent 状态组件，如果不存在则返回 null
func _get_status_component(ability_comp: Node) -> GameplayStatusComponent:
	if not is_instance_valid(ability_comp):
		return null

	# 从实体查找状态组件
	var entity: Node = ability_comp.get_parent()
	if is_instance_valid(entity):
		# 尝试通过接口查询（使用 AutoLoad 单例）
		var status_comp: Node = GameplayAbilitySystem.get_component_by_interface(entity, "GameplayStatusComponent")
		if is_instance_valid(status_comp) and status_comp is GameplayStatusComponent:
			return status_comp as GameplayStatusComponent

		# 尝试直接查找节点
		for child: Node in entity.get_children():
			if child is GameplayStatusComponent:
				return child as GameplayStatusComponent

	return null

## 获取施法者（实体）
## [param] ability: GameplayAbilityInstance 技能实例
## [param] ability_comp: Node 技能组件
## [return] Node 实体节点，如果不存在则返回 null
func _get_instigator(ability_comp: Node) -> Node:
	# 从 ability_comp 的父节点获取（实体）
	if is_instance_valid(ability_comp):
		var entity: Node = ability_comp.get_parent()
		if is_instance_valid(entity):
			return entity

	return null

## 获取已应用的状态ID列表（从 Feature 持久数据读取）
## [param] ability: GameplayAbilityInstance 技能实例
## [return] Array[StringName] 已应用的状态ID列表
func _get_applied_statuses(ability: GameplayAbilityInstance) -> Array[StringName]:
	var stored: Variant = _get_data(ability, "applied_statuses", [])
	if stored is Array:
		# 转换为 StringName 数组
		var result: Array[StringName] = []
		for item: Variant in stored:
			if item is StringName:
				result.append(item)
			elif item is String:
				result.append(StringName(item))
		return result
	return []

## 设置已应用的状态ID列表（存储到 Feature 持久数据）
## [param] ability: GameplayAbilityInstance 技能实例
## [param] statuses: Array[StringName] 已应用的状态ID列表
func _set_applied_statuses(ability: GameplayAbilityInstance, statuses: Array[StringName]) -> void:
	_set_data(ability, "applied_statuses", statuses)
