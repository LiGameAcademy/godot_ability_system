extends RefCounted
class_name GAS_BTBlackboard

# 只有这部分数据的变化会触发信号 / 中断逻辑
var _data: Dictionary = {}
# 这部分数据变化 **静默处理**，不发信号，专门给 GAS_BTNode 存中间状态用
# Key 是 GAS_BTNode 引用 (Object)，不是 String
var _node_memory: Dictionary = {}

## 信号：当某个 Key 的值改变时发出
signal value_changed(key: String, value: Variant)
signal value_cleared()

func _init(data_defaults: Dictionary = {}) -> void:
	_data = data_defaults.duplicate()

func set_var(key: String, value: Variant) -> void:
	var old_value = _data.get(key)
	# 只有值真的改变了才发信号，避免死循环和性能浪费
	if old_value != value:
		_data[key] = value
		value_changed.emit(key, value)

func get_var(key: String, default: Variant = null) -> Variant:
	return _data.get(key, default)

func has_var(key: String) -> Variant:
	return _data.has(key)

func erase_var(key: String) -> Variant:
	return _data.erase(key)

func clear() -> void:
	_data.clear()
	_node_memory.clear()

## [调试] 获取所有变量（用于调试面板）
func get_all_vars() -> Dictionary:
	return _data.duplicate()

func set_node_data(node: GAS_BTNode, value: Variant) -> void:
	_node_memory[node] = value

func get_node_data(node: GAS_BTNode, default: Variant = null) -> Variant:
	return _node_memory.get(node, default)

func erase_node_data(node: GAS_BTNode) -> void:
	_node_memory.erase(node)

## [调试] 获取所有节点数据（用于调试面板）
## 返回 Array[Dictionary]，每个 Dictionary 包含 node_name 和 data
func get_all_node_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in _node_memory.keys():
		if is_instance_valid(node):
			var node_name = str(node)
			result.append({
				"node_name": node_name,
				"data": _node_memory[node],
				"node_ref": node  # 保留引用用于后续操作
			})
	return result
