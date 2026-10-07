extends RefCounted
class_name GameplayTagState

## 单个实体的运行计数。内层字典为 source_id -> 引用数，不持有实体引用。
var _sources: Dictionary[StringName, Dictionary] = {}
var _queries: Dictionary[StringName, Dictionary] = {}
var _query_revision: int = -1

func acquire(tag_id: StringName, source_id: StringName) -> void:
	var sources: Dictionary[StringName, int] = {}
	if _sources.has(tag_id):
		sources.assign(_sources[tag_id])
	sources[source_id] = sources.get(source_id, 0) + 1
	_sources[tag_id] = sources
	_queries.clear()

func release(tag_id: StringName, source_id: StringName) -> bool:
	if get_source_count(tag_id, source_id) == 0:
		return false
	var sources: Dictionary = _sources[tag_id]
	sources[source_id] = int(sources[source_id]) - 1
	if sources[source_id] == 0:
		sources.erase(source_id)
	if sources.is_empty():
		_sources.erase(tag_id)
	_queries.clear()
	return true

func clear_tag(tag_id: StringName) -> bool:
	var changed: bool = _sources.erase(tag_id)
	if changed:
		_queries.clear()
	return changed

func remove_source(source_id: StringName) -> Array[StringName]:
	var disappeared: Array[StringName] = []
	for tag_id: StringName in _sources.keys():
		var sources: Dictionary = _sources[tag_id]
		sources.erase(source_id)
		if sources.is_empty():
			_sources.erase(tag_id)
			disappeared.append(tag_id)
	_queries.clear()
	return disappeared

func get_source_count(tag_id: StringName, source_id: StringName) -> int:
	var sources: Dictionary = _sources.get(tag_id, {})
	return int(sources.get(source_id, 0))

func get_count(tag_id: StringName, ignored_sources: Array[StringName] = []) -> int:
	var sources: Dictionary = _sources.get(tag_id, {})
	var total: int = 0
	for source_id: StringName in sources:
		if not ignored_sources.has(source_id):
			total += int(sources[source_id])
	return total

func get_tags() -> Array[StringName]:
	return _sources.keys()

func clear_queries() -> void:
	_queries.clear()

func get_query(tag_id: StringName, inherited: bool, revision: int) -> Variant:
	if _query_revision != revision:
		_queries.clear()
		_query_revision = revision
	var queries: Dictionary = _queries.get(tag_id, {})
	return queries.get(inherited)

func save_query(tag_id: StringName, inherited: bool, value: bool) -> void:
	var queries: Dictionary = _queries.get(tag_id, {})
	queries[inherited] = value
	_queries[tag_id] = queries
