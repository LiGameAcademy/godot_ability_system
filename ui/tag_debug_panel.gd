extends MarginContainer

@onready var refresh_button: Button = %RefreshButton
@onready var entity_list: ItemList = %EntityList
@onready var tag_count_label: Label = %TagCountLabel
@onready var tag_container: GridContainer = %TagContainer
@onready var tag_id_input: LineEdit = %TagIdInput
@onready var clear_all_tags_button: Button = %ClearAllTagsButton
@onready var remove_tag_button: Button = %RemoveTagButton
@onready var add_tag_button: Button = %AddTagButton
@onready var force_remove_tag_button: Button = %ForceRemoveTagButton

@export var toggle_action: String = "toggle_tag_debug"
@export var TAG_DISPLAY_ITEM_SCENE : PackedScene = preload("tag_display_item.tscn")

var _entities: Dictionary = {}
var _selected_entity: Node = null

var _tag_display_items: Dictionary = {}

func _ready() -> void:
	# 连接信号
	entity_list.item_selected.connect(_on_entity_selected)
	add_tag_button.pressed.connect(_on_add_tag_pressed)
	remove_tag_button.pressed.connect(_on_remove_tag_pressed)
	force_remove_tag_button.pressed.connect(_on_force_remove_tag_pressed)
	clear_all_tags_button.pressed.connect(_on_clear_all_tags_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)

	# 监听标签变化信号（避免重复连接）
	if TagManager.tag_added.is_connected(_on_tag_added):
		TagManager.tag_added.disconnect(_on_tag_added)
	TagManager.tag_added.connect(_on_tag_added)

	if TagManager.tag_removed.is_connected(_on_tag_removed):
		TagManager.tag_removed.disconnect(_on_tag_removed)
	TagManager.tag_removed.connect(_on_tag_removed)

	# 初始隐藏面板（调试面板默认隐藏）
	visible = false

	# 初始扫描
	_scan_entities()

## 处理未处理的输入事件（用于快捷键）
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		toggle_visibility()
		get_viewport().set_input_as_handled()

## 切换面板显示/隐藏
func toggle_visibility() -> void:
	visible = not visible
	if visible:
		# 显示时刷新实体列表
		_scan_entities()
	
## 扫描场景中所有实体
func _scan_entities() -> void:
	_entities.clear()
	entity_list.clear()

	# 扫描所有属于 "Entities" 组的节点
	for node in get_tree().get_nodes_in_group("Entities"):
		var entity_name = node.name if node.name != "" else str(node.get_path())
		if _entities.has(entity_name):
			entity_name = str(node.get_path())
		_entities[entity_name] = node

	# 更新列表显示
	for entity_name in _entities.keys():
		var entity = _entities[entity_name]
		var display_name = "%s (%s)" % [entity_name, entity.get_class()]
		entity_list.add_item(display_name)

## 更新标签显示
func _update_tag_display() -> void:
	# 清除旧的标签显示项
	for item in _tag_display_items.values():
		if is_instance_valid(item):
			item.queue_free()
	_tag_display_items.clear()

	if not is_instance_valid(_selected_entity):
		tag_count_label.text = "标签数量: 0"
		return

	# 获取所有标签
	var all_tags = TagManager.get_all_tags(_selected_entity)

	# 更新标签数量显示
	tag_count_label.text = "标签数量: %d" % all_tags.size()

	# 为每个标签创建显示项
	for tag_id in all_tags:
		var tag_resource = TagManager.get_tag_resource(tag_id)
		var tag_count = TagManager.get_tag_count(_selected_entity, tag_id)
		var display_item = TAG_DISPLAY_ITEM_SCENE.instantiate()
		if is_instance_valid(display_item):
			tag_container.add_child(display_item)
			_tag_display_items[tag_id] = display_item
			display_item.setup(tag_id, tag_resource, tag_count)

## 实体选择回调
func _on_entity_selected(index: int) -> void:
	if index < 0 or index >= _entities.size():
		return
	var entity_name = _entities.keys()[index]
	_selected_entity = _entities[entity_name]

	# 更新标签显示
	_update_tag_display()

## 标签添加回调（由 TagManager 信号触发）
func _on_tag_added(target: Node, _tag_id: StringName) -> void:
	if target == _selected_entity:
		_update_tag_display()

## 标签移除回调（由 TagManager 信号触发）
func _on_tag_removed(target: Node, tag_id: StringName) -> void:
	if target == _selected_entity:
		_update_tag_display()

## 添加标签
func _on_add_tag_pressed() -> void:
	if not is_instance_valid(_selected_entity):
		push_warning("TagDebugPanel: No entity selected")
		return

	var tag_id_str = tag_id_input.text.strip_edges()
	if tag_id_str.is_empty():
		push_warning("TagDebugPanel: Tag ID is empty")
		return

	var tag_id = StringName(tag_id_str)
	# 验证标签是否已注册
	if not TagManager.is_tag_registered(tag_id):
		push_warning("TagDebugPanel: Tag [%s] is not registered" % tag_id_str)
		return
	
	# 添加标签
	TagManager.add_tag(_selected_entity, tag_id)
	# 更新显示
	_update_tag_display()

	# 清空输入框
	tag_id_input.text = ""

## 移除标签
func _on_remove_tag_pressed() -> void:
	if not is_instance_valid(_selected_entity):
		push_warning("TagDebugPanel: No entity selected")
		return

	var tag_id_str = tag_id_input.text.strip_edges()
	if tag_id_str.is_empty():
		push_warning("TagDebugPanel: Tag ID is empty")
		return

	var tag_id = StringName(tag_id_str)
	# 验证标签是否已注册
	if not TagManager.is_tag_registered(tag_id):
		push_warning("TagDebugPanel: Tag [%s] is not registered" % tag_id_str)
		return
	
	# 移除标签
	TagManager.remove_tag(_selected_entity, tag_id)

	# 更新显示
	_update_tag_display()
	# 清空输入框
	tag_id_input.text = ""
	
## 强制移除标签
func _on_force_remove_tag_pressed() -> void:
	if not is_instance_valid(_selected_entity):
		push_warning("TagDebugPanel: No entity selected")
		return

	var tag_id_str = tag_id_input.text.strip_edges()
	if tag_id_str.is_empty():
		push_warning("TagDebugPanel: Tag ID is empty")
		return

	var tag_id = StringName(tag_id_str)
	# 验证标签是否已注册
	if not TagManager.is_tag_registered(tag_id):
		push_warning("TagDebugPanel: Tag [%s] is not registered" % tag_id_str)
		return
	
	# 强制移除标签
	TagManager.force_remove_tag(_selected_entity, tag_id)
	
	# 更新显示
	_update_tag_display()
	# 清空输入框
	tag_id_input.text = ""

## 清除所有标签
func _on_clear_all_tags_pressed() -> void:
	if not is_instance_valid(_selected_entity):
		push_warning("TagDebugPanel: No entity selected")
		return
	
	# 清除所有标签
	TagManager.clear_all_tags(_selected_entity)
	
	# 更新显示
	_update_tag_display()

## 刷新实体列表
func _on_refresh_pressed() -> void:
	_scan_entities()
	if is_instance_valid(_selected_entity):
		# 尝试重新选择当前实体
		for i in range(entity_list.item_count):
			var item_text = entity_list.get_item_text(i)
			if _selected_entity.name in item_text or str(_selected_entity.get_path()) in item_text:
				entity_list.select(i)
				_on_entity_selected(i)
				break
