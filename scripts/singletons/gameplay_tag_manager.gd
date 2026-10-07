extends Node

## 标签服务入口：定义由 Registry 管理，实体计数存在实体自己的 TagState 中。
const TAG_GROUP_PREFIX: String = "tag_"
const STATE_META: StringName = &"gas_tag_state"
var _registry: GameplayTagRegistry = GameplayTagRegistry.new()
var _initialized: bool = false
var _query_revision: int = 0
var _cache_enabled: bool = true
var _mutating: Dictionary[int, WeakRef] = {}
var _pending_releases: Dictionary[int, Array] = {}
var _flushing_releases: Dictionary[int, bool] = {}

signal tag_added(target: Node, tag_id: StringName)
signal tag_removed(target: Node, tag_id: StringName)

func initialize(tag_or_tags: Variant, recursive: bool = true) -> void:
	if tag_or_tags is GameplayTag:
		register_tag(tag_or_tags as GameplayTag)
	elif tag_or_tags is Array:
		for value: Variant in tag_or_tags:
			if value is GameplayTag:
				register_tag(value as GameplayTag)
			else:
				push_warning("TagManager: initialize expects GameplayTag resources")
	elif tag_or_tags is String:
		register_tags_from_directory(String(tag_or_tags), recursive)
	else:
		push_warning("TagManager: Unsupported initialization input")
		return
	_initialized = true

func register_tag(tag: GameplayTag) -> bool:
	return _registry.register(tag)

func register_tags(tags: Array[GameplayTag]) -> int:
	var count: int = 0
	for tag: GameplayTag in tags:
		if register_tag(tag):
			count += 1
	return count

func register_tags_from_directory(dir_path: String, recursive: bool = true) -> int:
	return _registry.register_directory(dir_path, recursive)

func unregister_tag(tag_id: StringName) -> bool:
	return _registry.unregister(tag_id)

## 查询不会创建实体状态，也不会移除任何互斥来源。
func can_add_tags(target: Node, tag_ids: Array[StringName], ignored_sources: Array[StringName] = []) -> bool:
	if not is_instance_valid(target) or not validate_tag_list(tag_ids):
		return false
	for id: StringName in tag_ids:
		for other: StringName in tag_ids:
			if tags_conflict(id, other):
				return false
	var state: GameplayTagState = _get_state(target)
	if not is_instance_valid(state):
		return true
	for held: StringName in state.get_tags():
		if state.get_count(held, ignored_sources) == 0:
			continue
		for id: StringName in tag_ids:
			if tags_conflict(id, held):
				return false
	return true

## 空来源保留旧的匿名计数；具名来源仅能释放自己的计数。
func add_tag(target: Node, tag_id: StringName, source_id: StringName = &"") -> bool:
	return add_tags(target, [tag_id], source_id)

## 整批先校验，再提交计数与组，最后发出 0 -> 1 事件。
func add_tags(target: Node, tag_ids: Array[StringName], source_id: StringName = &"") -> bool:
	if tag_ids.is_empty():
		return is_instance_valid(target)
	if not can_add_tags(target, tag_ids) or not _can_mutate(target):
		return false
	var target_id: int = target.get_instance_id()
	_mutating[target_id] = weakref(target)
	var state: GameplayTagState = _get_state(target, true)
	var appeared: Array[StringName] = []
	for id: StringName in tag_ids:
		if state.get_count(id) == 0:
			appeared.append(id)
			target.add_to_group(_group_name(id))
		state.acquire(id, source_id)
	for id: StringName in appeared:
		if not is_instance_valid(target):
			break
		tag_added.emit(target, id)
	_end_mutation(target_id)
	return true

func remove_tag(target: Node, tag_id: StringName, source_id: StringName = &"") -> bool:
	if not _can_mutate(target):
		return false
	var state: GameplayTagState = _get_state(target)
	if not is_instance_valid(state) or state.get_source_count(tag_id, source_id) == 0:
		return false
	var target_id: int = target.get_instance_id()
	_mutating[target_id] = weakref(target)
	state.release(tag_id, source_id)
	if state.get_count(tag_id) == 0:
		target.remove_from_group(_group_name(tag_id))
		tag_removed.emit(target, tag_id)
	_end_mutation(target_id)
	return true

func remove_tags(target: Node, tag_ids: Array[StringName], source_id: StringName = &"") -> void:
	for id: StringName in tag_ids:
		if not is_instance_valid(target):
			break
		remove_tag(target, id, source_id)

## 一次释放该来源的所有标签；不存在的来源不发变化事件。
func remove_source(target: Node, source_id: StringName) -> bool:
	if not is_instance_valid(target):
		return false
	if _mutating.has(target.get_instance_id()):
		var queued: Array[StringName] = []
		queued.assign(_pending_releases.get(target.get_instance_id(), []))
		if not queued.has(source_id):
			queued.append(source_id)
		_pending_releases[target.get_instance_id()] = queued
		return true
	var state: GameplayTagState = _get_state(target)
	if not is_instance_valid(state):
		return false
	var found: bool = false
	for id: StringName in state.get_tags():
		found = found or state.get_source_count(id, source_id) > 0
	if not found:
		return false
	var target_id: int = target.get_instance_id()
	_mutating[target_id] = weakref(target)
	var disappeared: Array[StringName] = state.remove_source(source_id)
	for id: StringName in disappeared:
		target.remove_from_group(_group_name(id))
	for id: StringName in disappeared:
		if not is_instance_valid(target):
			break
		tag_removed.emit(target, id)
	_end_mutation(target_id)
	return true

## 显式管理操作：清空该标签全部来源，调用方负责同步自己的业务状态。
func force_remove_tag(target: Node, tag_id: StringName) -> void:
	_clear_tags(target, [tag_id])

func clear_all_tags(target: Node) -> void:
	var state: GameplayTagState = _get_state(target)
	if is_instance_valid(state):
		_clear_tags(target, state.get_tags())

func has_tag(target: Node, tag_id: StringName, include_inherited: bool = true) -> bool:
	var state: GameplayTagState = _get_state(target)
	if not is_instance_valid(state):
		return false
	if _cache_enabled:
		var cached: Variant = state.get_query(tag_id, include_inherited, _registry.revision + _query_revision)
		if cached is bool:
			return bool(cached)
	var found: bool = state.get_count(tag_id) > 0
	if include_inherited and not found:
		for held: StringName in state.get_tags():
			if tag_inherits_from(held, tag_id):
				found = true
				break
	if _cache_enabled:
		state.save_query(tag_id, include_inherited, found)
	return found

func has_any_tag(target: Node, tag_list: Array[StringName], include_inherited: bool = true) -> bool:
	for id: StringName in tag_list:
		if has_tag(target, id, include_inherited):
			return true
	return false

func has_all_tags(target: Node, tag_list: Array[StringName], include_inherited: bool = true) -> bool:
	if not is_instance_valid(target):
		return false
	for id: StringName in tag_list:
		if not has_tag(target, id, include_inherited):
			return false
	return true

func get_tag_count(target: Node, tag_id: StringName) -> int:
	var state: GameplayTagState = _get_state(target)
	return state.get_count(tag_id) if is_instance_valid(state) else 0

func get_tag_source_count(target: Node, tag_id: StringName, source_id: StringName) -> int:
	var state: GameplayTagState = _get_state(target)
	return state.get_source_count(tag_id, source_id) if is_instance_valid(state) else 0

func get_all_tags(target: Node) -> Array[StringName]:
	var state: GameplayTagState = _get_state(target)
	return state.get_tags() if is_instance_valid(state) else []

func clear_query_cache(target: Node = null) -> void:
	if target == null:
		_query_revision += 1
		return
	var state: GameplayTagState = _get_state(target)
	if is_instance_valid(state):
		state.clear_queries()

func get_tag_inheritance_chain(tag_id: StringName) -> Array[StringName]:
	return _registry.get_chain(tag_id)

func get_tag_exclusions(tag_id: StringName) -> Array[StringName]:
	return _registry.get_exclusions(tag_id)

func tag_inherits_from(tag_id: StringName, parent_tag_id: StringName) -> bool:
	return _registry.inherits(tag_id, parent_tag_id)

func tags_conflict(first: StringName, second: StringName) -> bool:
	return _registry.conflicts(first, second)

func get_tag_resource(tag_id: StringName) -> GameplayTag:
	return _registry.get_tag(tag_id)

func get_all_tag_resources() -> Dictionary[StringName, GameplayTag]:
	return _registry.get_tags()

func is_tag_registered(tag_id: StringName) -> bool:
	return _registry.has_tag(tag_id)

func validate_tag(tag_id: StringName) -> bool:
	return _registry.validate(tag_id)

func validate_tag_list(tag_ids: Array[StringName]) -> bool:
	for id: StringName in tag_ids:
		if not validate_tag(id):
			return false
	return true

func print_debug_status(target: Node) -> void:
	if not is_instance_valid(target):
		return
	print("TagManager: Debug status for [%s]:" % target.name)
	for id: StringName in get_all_tags(target):
		var resource: GameplayTag = get_tag_resource(id)
		var display: String = resource.display_name if is_instance_valid(resource) else "Unregistered"
		print("  - [%s] (%s): count=%d" % [id, display, get_tag_count(target, id)])

func _get_state(target: Node, create: bool = false) -> GameplayTagState:
	if not is_instance_valid(target):
		return null
	var value: Variant = target.get_meta(STATE_META) if target.has_meta(STATE_META) else null
	if value is GameplayTagState:
		return value as GameplayTagState
	if not create:
		return null
	var state: GameplayTagState = GameplayTagState.new()
	target.set_meta(STATE_META, state)
	return state

func _can_mutate(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	if _mutating.has(target.get_instance_id()):
		push_warning("TagManager: Defer tag changes made inside tag notification callbacks")
		return false
	return true

func _clear_tags(target: Node, tag_ids: Array[StringName]) -> void:
	if not _can_mutate(target):
		return
	var state: GameplayTagState = _get_state(target)
	if not is_instance_valid(state):
		return
	var target_id: int = target.get_instance_id()
	_mutating[target_id] = weakref(target)
	var disappeared: Array[StringName] = []
	for id: StringName in tag_ids:
		if state.clear_tag(id):
			target.remove_from_group(_group_name(id))
			disappeared.append(id)
	for id: StringName in disappeared:
		if not is_instance_valid(target):
			break
		tag_removed.emit(target, id)
	_end_mutation(target_id)

func _group_name(tag_id: StringName) -> StringName:
	return StringName(TAG_GROUP_PREFIX + String(tag_id))

## 状态在标签通知中结束时，将来源释放到当前通知结束后，仍在本次调用内清理。
func _end_mutation(target_id: int) -> void:
	var target_ref: WeakRef = _mutating.get(target_id)
	_mutating.erase(target_id)
	if _flushing_releases.has(target_id):
		return
	var target: Node = target_ref.get_ref() as Node if is_instance_valid(target_ref) else null
	_flushing_releases[target_id] = true
	# 释放通知还能请求释放其他来源；迭代排空，避免每个来源增加一层调用栈。
	while is_instance_valid(target) and _pending_releases.has(target_id):
		var queued: Array[StringName] = []
		queued.assign(_pending_releases[target_id])
		_pending_releases.erase(target_id)
		for source_id: StringName in queued:
			if not is_instance_valid(target):
				break
			remove_source(target, source_id)
	_pending_releases.erase(target_id)
	_flushing_releases.erase(target_id)
