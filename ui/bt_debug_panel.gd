extends Window
class_name BTDebugPanel

const ENTITY_GROUP_NAME := "Entities"

## 切换面板显示的快捷键（使用 Input Map 中的 action 名称）
@export var toggle_action: String = "toggle_bt_debug"
@export var ability_comp_name : String = "GameplayAbilityComponent"

# UI 节点引用
@onready var entity_list: ItemList = %EntityList
@onready var tree_view: Tree = %TreeView
@onready var blackboard_view: RichTextLabel = %BlackboardView
@onready var active_nodes_view: RichTextLabel = %ActiveNodesView
@onready var execution_history_view: RichTextLabel = %ExecutionHistoryView
@onready var refresh_button: Button = %RefreshButton
@onready var clear_history_button: Button = %ClearHistoryButton

# 实体数据 {entity_name: {node: Node, instance: GameplayAbilityInstance}}
var _entities: Dictionary = {}
var _selected_entity: Node = null
var _selected_instance: GameplayAbilityInstance = null

# 树视图根节点
var _tree_root_item: TreeItem = null

func _ready() -> void:
	# 连接信号
	entity_list.item_selected.connect(_on_entity_selected)
	refresh_button.pressed.connect(_on_refresh_pressed)
	clear_history_button.pressed.connect(_on_clear_history_pressed)

func _process(delta: float) -> void:
	if not visible:
		return

	if is_instance_valid(_selected_instance):
		_update_tree_view()
		_update_blackboard_view()
		_update_active_nodes_view()
		_update_execution_history_view()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		toggle_visibility()

## 切换面板显示/隐藏
func toggle_visibility() -> void:
	if visible:
		# 隐藏窗口
		visible = false
		set_process(false)
	else:
		# 显示窗口（使用 popup_centered 确保窗口居中显示）
		popup_centered()
		# 显示时刷新实体列表
		_scan_entities()
		set_process(true)
		# 将窗口置于最前
		move_to_foreground()

## 扫描场景中所有包含 GameplayAbilityComponent 的实体
func _scan_entities() -> void:
	_entities.clear()
	entity_list.clear()

	# 使用 Group 机制获取所有能力实体
	var entities: Array[Node] = get_tree().get_nodes_in_group(ENTITY_GROUP_NAME)

	# 遍历实体，查找对应的 GameplayAbilityComponent
	for entity in entities:
		if not is_instance_valid(entity):
			continue

		# 获取能力组件
		var ability_comp : GameplayAbilityComponent = GameplayAbilitySystem.get_component_by_interface(entity, ability_comp_name)
		if not is_instance_valid(ability_comp) or not ability_comp is GameplayAbilityComponent:
			continue

		# 连接信号
		if not ability_comp.ability_activated.is_connected(_on_ability_activated):
			ability_comp.ability_activated.connect(_on_ability_activated)

		# 查找正在运行的技能实例
		var active_instance: GameplayAbilityInstance = ability_comp.get_current_casting_ability()

		if not is_instance_valid(active_instance):
			# 如果没有正在运行的技能，尝试获取第一个技能实例
			var ability_ids = ability_comp.get_all_ability_ids()
			if ability_ids.size() > 0:
				active_instance = ability_comp.get_ability_instance(ability_ids[0])

		# 生成实体名称
		var entity_name = entity.name if entity.name != "" else str(entity.get_path())
		if _entities.has(entity_name):
			entity_name = str(entity.get_path())

		_entities[entity_name] = {
			"node": entity,
			"instance": active_instance
		}

	# 更新列表显示
	for entity_name in _entities.keys():
		var data = _entities[entity_name]
		var display_name = entity_name
		if is_instance_valid(data.instance):
			var ability_id = data.instance.get_definition().ability_id
			display_name += " [%s]" % ability_id
		entity_list.add_item(display_name)

	# 如果有实体，默认选择第一个
	if entity_list.get_item_count() > 0:
		entity_list.select(0)
		_on_entity_selected(0)

## 更新树视图
func _update_tree_view() -> void:
	tree_view.clear()
	_tree_root_item = null

	if not is_instance_valid(_selected_instance):
		return

	var bt_instance = _selected_instance.get_bt_instance()
	if not is_instance_valid(bt_instance) or not is_instance_valid(bt_instance.tree_root):
		return
		
	# 递归构建树视图
	_tree_root_item = tree_view.create_item()
	_build_tree_item(_tree_root_item, bt_instance.tree_root, bt_instance)

## 递归构建树项
func _build_tree_item(parent_item: TreeItem, node: GAS_BTNode, instance: GAS_BTInstance) -> void:
	if not is_instance_valid(node):
		return

	# 获取节点名称
	var node_name = _get_node_name(node)

	# 检查节点是否正在运行（使用 _node_status，不干扰存储数据）
	var is_running = instance.has_node_status(node)

	# 确定状态文本和颜色
	var status_text = " [RUNNING]" if is_running else ""
	var status_color = Color.CYAN if is_running else Color.WHITE

	# 创建树项
	var item = tree_view.create_item(parent_item)
	item.set_text(0, node_name + status_text)
	item.set_custom_color(0, status_color)

	# 如果是组合节点，递归处理子节点
	if node is GAS_BTComposite:
		var composite = node as GAS_BTComposite
		for child in composite.children:
			_build_tree_item(item, child, instance)
	elif node is GAS_BTDecorator:
		var decorator = node as GAS_BTDecorator
		if is_instance_valid(decorator.child):
			_build_tree_item(item, decorator.child, instance)

## 获取节点名称
func _get_node_name(node: GAS_BTNode) -> String:
	if not is_instance_valid(node):
		return "null"
	
	# 获取节点类型（类名）
	var node_type: String = ""
	var script = node.get_script()
	if is_instance_valid(script):
		var node_class_name = script.get_global_name()
		if node_class_name != "":
			node_type = node_class_name
		else:
			node_type = node.get_class()
	else:
		node_type = node.get_class()

	# 获取节点名称（使用节点的 _get_node_name 方法）
	var custom_name: String = ""
	if node.has_method("_get_node_name"):
		var name_result = node.call("_get_node_name")
		if name_result is StringName:
			custom_name = name_result
		elif name_result is String:
			custom_name = name_result

	# 如果节点名称就是类型名（未设置自定义名称），只显示类型
	if custom_name == node_type or custom_name.is_empty():
		return "[%s]" % node_type
	else:
		# 格式化显示：名称[类型]
		return "%s[%s]" % [custom_name, node_type]

## 更新黑板视图
func _update_blackboard_view() -> void:
	var text = "[b]黑板变量[/b]\n\n"

	if not is_instance_valid(_selected_instance):
		text += "未选择实体或技能未激活"
		blackboard_view.text = text
		return

	var bt_instance = _selected_instance.get_bt_instance()
	if not is_instance_valid(bt_instance):
		text += "行为树实例不存在"
		blackboard_view.text = text
		return

	# 获取所有黑板变量
	var blackboard = _selected_instance.get_blackboard()
	var all_vars = blackboard.get_all_vars()

	if all_vars.is_empty():
		text += "无黑板变量"
	else:
		for key in all_vars.keys():
			var value = all_vars[key]
			text += "[color=cyan]%s[/color]: %s\n" % [key, _format_value(value)]

	blackboard_view.text = text

## 更新活动节点视图
func _update_active_nodes_view() -> void:
	var text = "[b]活动节点[/b]\n\n"
	if not is_instance_valid(_selected_instance):
		text += "未选择实体或技能未激活"
		active_nodes_view.text = text
		return

	# 获取所有黑板变量
	var blackboard = _selected_instance.get_blackboard()
	var active_nodes = blackboard.get_all_node_data()
	var active_count = active_nodes.size()

	text += "活动节点数量: %d\n\n" % active_count

	if active_count > 0:
		for node_info in active_nodes:
			var node_name = node_info.get("node_name", "unknown")
			var node_data = node_info.get("data", null)
			text += "[color=cyan]%s[/color]: %s\n" % [node_name, _format_value(node_data)]
	else:
		text += "无活动节点"

	active_nodes_view.text = text

## 更新执行记录视图
func _update_execution_history_view() -> void:
	var text = "[b]执行记录[/b]\n\n"
	if not is_instance_valid(_selected_instance):
		text += "未选择实体或技能未激活"
		execution_history_view.text = text
		return

	var bt_instance = _selected_instance.get_bt_instance()
	if not is_instance_valid(bt_instance):
		text += "行为树实例不存在"
		blackboard_view.text = text
		return
	
	# 获取执行历史
	var history = bt_instance.get_execution_history()
	var history_count = history.size()

	text += "记录数量: %d\n\n" % history_count
	if history_count <= 0:
		text += "无执行记录"
		blackboard_view.text = text
		return

	var display_count = min(history_count, 40)  # 最多显示20条
	for i in range(history_count - display_count, history_count):
		var record : Dictionary = history[i]
		var node = record.get("node", null)
		var status = record.get("status", -1)
		var timestamp = record.get("timestamp", 0.0)
		var frame = record.get("frame", 0)

		if not is_instance_valid(node):
			continue

		# 获取节点名称
		var node_name = _get_node_name(node)

		# 状态文本和颜色
		var status_text = ""
		var status_color = Color.WHITE
		match status:
			GAS_BTNode.Status.SUCCESS:
				status_text = "SUCCESS"
				status_color = Color.GREEN
			GAS_BTNode.Status.FAILURE:
				status_text = "FAILURE"
				status_color = Color.RED
			GAS_BTNode.Status.RUNNING:
				status_text = "RUNNING"
				status_color = Color.CYAN
			_:
				status_text = "UNKNOWN"
		# 格式化时间戳（保留2位小数）
		var time_str = "%.2f" % timestamp
		# 显示记录：[时间] 节点名称 -> 状态 (帧号)
		text += "[color=gray]%s[/color] [color=cyan]%s[/color] -> [color=%s]%s[/color] (帧:%d)\n" % [
				time_str,
				node_name,
				_status_color_to_hex(status_color),
				status_text,
				frame
			]
	execution_history_view.text = text

## 将状态颜色转换为十六进制字符串（用于 BBCode）
func _status_color_to_hex(color: Color) -> String:
	return "#%02x%02x%02x" % [
		int(color.r * 255),
		int(color.g * 255),
		int(color.b * 255)
	]

## 格式化值显示
func _format_value(value: Variant) -> String:
	if value == null:
		return "[null]"

	if value is Node:
		return value.name if is_instance_valid(value) else "[invalid Node]"

	if value is Array:
		return "[Array: %d items]" % value.size()

	if value is Dictionary:
		return "[Dictionary: %d keys]" % value.size()

	return str(value)
	
func _on_ability_activated(ability_instance: GameplayAbilityInstance) -> void:
	if not is_instance_valid(ability_instance):
		return
	
	_scan_entities()

## 实体选择回调
func _on_entity_selected(index: int) -> void:
	if index < 0 or index >= entity_list.get_item_count():
		return

	var entity_name = entity_list.get_item_text(index)
	# 提取原始名称（去掉 [ability_id] 部分）
	var base_name = entity_name.split(" [")[0]

	if not _entities.has(base_name):
		return

	var data = _entities[base_name]
	_selected_entity = data.node
	_selected_instance = data.instance

	# 更新视图
	_update_tree_view()
	_update_blackboard_view()
	_update_active_nodes_view()
	_update_execution_history_view()

## 刷新按钮回调
func _on_refresh_pressed() -> void:
	_scan_entities()

## 清空执行记录按钮回调
func _on_clear_history_pressed() -> void:
	if not is_instance_valid(_selected_instance):
		return

	var bt_instance = _selected_instance._bt_instance
	if not is_instance_valid(bt_instance):
		return

	# 清空执行历史
	bt_instance.execution_history.clear()
	# 立即更新视图
	_update_execution_history_view()
