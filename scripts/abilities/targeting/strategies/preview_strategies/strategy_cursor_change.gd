extends AbilityPreviewStrategy
class_name StrategyCursorChange

## 光标样式策略
## 最简单的预览方式：只改变鼠标光标样式
## 适用于：大多数需要瞄准的技能（火球术、治疗术等）

@export_group("Cursor Settings")
## 瞄准时的光标纹理
@export var cursor_texture: Texture2D = null
## 光标热点位置（相对于纹理左上角的偏移）
@export var cursor_hotspot: Vector2 = Vector2.ZERO
## 默认光标纹理（取消瞄准时恢复）
@export var default_cursor_texture: Texture2D = null
@export var default_cursor_hotspot: Vector2 = Vector2.ZERO

## 存储默认光标（用于恢复）
var _saved_default_cursor: Texture2D = null
var _saved_default_hotspot: Vector2 = Vector2.ZERO

## [1] 开始瞄准：改变光标样式
func begin(caster: Node, ability_instance: GameplayAbilityInstance, extra_context: Dictionary = {}) -> void:
	if not is_instance_valid(cursor_texture):
		push_warning("StrategyCursorChange: cursor_texture is not set!")

	# 保存当前光标（如果还没有保存）
	if _saved_default_cursor == null:
		# 注意：Godot 没有直接获取当前光标的方法
		# 如果配置了 default_cursor_texture，使用它；否则假设是系统默认
		_saved_default_cursor = default_cursor_texture
		_saved_default_hotspot = default_cursor_hotspot

	# 设置新的光标
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, cursor_hotspot)

func get_result_context() -> Dictionary:
	_restore_default_cursor()
	return super()

func cancel_targeting() -> void:
	_restore_default_cursor()

## [4] 恢复默认光标（在取消瞄准时调用）
func _restore_default_cursor() -> void:
	if _saved_default_cursor:
		Input.set_custom_mouse_cursor(_saved_default_cursor, Input.CURSOR_ARROW, _saved_default_hotspot)
	else:
		# 如果没有保存的默认光标，恢复系统默认光标
		Input.set_custom_mouse_cursor(null)
