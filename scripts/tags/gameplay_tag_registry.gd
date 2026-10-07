extends RefCounted
class_name GameplayTagRegistry

## 只读配置资源的登记与关系索引，不管理实体运行计数。
var revision: int = 0
var _tags: Dictionary[StringName, GameplayTag] = {}
var _parents: Dictionary[StringName, Array] = {}
var _exclusions: Dictionary[StringName, Array] = {}
var _invalid_chains: Array[StringName] = []
var _dirty: bool = true

func register(tag: GameplayTag) -> bool:
	if not is_instance_valid(tag) or tag.id.is_empty() or _tags.has(tag.id):
		push_warning("TagManager: Invalid or already registered tag")
		return false
	_tags[tag.id] = tag
	revision += 1
	_dirty = true
	return true

func unregister(tag_id: StringName) -> bool:
	if not _tags.erase(tag_id):
		return false
	revision += 1
	_dirty = true
	return true

func register_directory(path: String, recursive: bool) -> int:
	var directory: DirAccess = DirAccess.open(path)
	if not is_instance_valid(directory):
		push_warning("TagManager: Cannot open tag directory: " + path)
		return 0
	var count: int = 0
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		var full_path: String = path.path_join(entry)
		if directory.current_is_dir() and not entry.begins_with(".") and recursive:
			count += register_directory(full_path, true)
		elif entry.ends_with(".tres"):
			var tag: GameplayTag = load(full_path) as GameplayTag
			if register(tag):
				count += 1
		entry = directory.get_next()
	directory.list_dir_end()
	return count

func get_tag(tag_id: StringName) -> GameplayTag:
	return _tags.get(tag_id)

func get_tags() -> Dictionary[StringName, GameplayTag]:
	return _tags.duplicate()

func has_tag(tag_id: StringName) -> bool:
	return _tags.has(tag_id)

func get_chain(tag_id: StringName) -> Array[StringName]:
	_ensure_relations()
	var chain: Array[StringName] = [tag_id]
	chain.append_array(_parents.get(tag_id, []))
	return chain

func inherits(tag_id: StringName, parent_id: StringName) -> bool:
	return get_chain(tag_id).has(parent_id)

func conflicts(first: StringName, second: StringName) -> bool:
	for excluded: StringName in _declared_exclusions(first):
		if inherits(second, excluded):
			return true
	for excluded: StringName in _declared_exclusions(second):
		if inherits(first, excluded):
			return true
	return false

func get_exclusions(tag_id: StringName) -> Array[StringName]:
	_ensure_relations()
	if not _exclusions.has(tag_id):
		var matches: Array[StringName] = []
		for other_id: StringName in _tags:
			if conflicts(tag_id, other_id):
				matches.append(other_id)
		_exclusions[tag_id] = matches
	var result: Array[StringName] = []
	result.assign(_exclusions[tag_id])
	return result

func validate(tag_id: StringName) -> bool:
	_ensure_relations()
	var tag: GameplayTag = get_tag(tag_id)
	if not is_instance_valid(tag) or _invalid_chains.has(tag_id):
		push_warning("TagManager: Unknown tag or invalid parent chain: " + String(tag_id))
		return false
	for id: StringName in get_chain(tag_id):
		var entry: GameplayTag = get_tag(id)
		for excluded: StringName in entry.mutually_exclusive_tags:
			if not _tags.has(excluded) or inherits(tag_id, excluded):
				push_warning("TagManager: Invalid exclusion on tag " + String(id))
				return false
	return true

func _declared_exclusions(tag_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in get_chain(tag_id):
		var tag: GameplayTag = get_tag(id)
		if is_instance_valid(tag):
			for excluded: StringName in tag.mutually_exclusive_tags:
				if _tags.has(excluded) and not result.has(excluded):
					result.append(excluded)
	return result

func _ensure_relations() -> void:
	if not _dirty:
		return
	_dirty = false
	_parents.clear()
	_exclusions.clear()
	_invalid_chains.clear()
	for tag_id: StringName in _tags:
		var chain: Array[StringName] = []
		var visited: Array[StringName] = [tag_id]
		var current: GameplayTag = _tags[tag_id]
		while not current.parent_tag_id.is_empty():
			var parent_id: StringName = current.parent_tag_id
			if visited.has(parent_id) or not _tags.has(parent_id):
				_invalid_chains.append(tag_id)
				break
			visited.append(parent_id)
			chain.append(parent_id)
			current = _tags[parent_id]
		_parents[tag_id] = chain
