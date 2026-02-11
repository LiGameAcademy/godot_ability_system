@abstract
extends Resource
class_name StatusFeature

## 状态特性基类（抽象类）
## 将状态的各种功能抽象为独立的 Feature

## 特性名称（用于调试和日志）
@export var feature_name: String = ""

## 应用特性（状态应用时调用）
func apply_feature(instance: GameplayStatusInstance, context: Dictionary) -> void:
	_apply_feature(instance, context)
	
## 更新特性（状态更新时调用）
func update_feature(instance: GameplayStatusInstance, delta: float) -> void:
	_update_feature(instance, delta)
	
## 移除特性（状态移除时调用）
func remove_feature(instance: GameplayStatusInstance, context: Dictionary) -> void:
	_remove_feature(instance, context)
	
## 处理事件（事件触发时调用）
func handle_event(instance: GameplayStatusInstance, event_id: StringName, context: Dictionary) -> void:
	_handle_event(instance, event_id, context)
	
## 检查此状态是否可以被指定事件触发
func can_trigger_on_event(event_type: StringName) -> bool:
	return false

func has_event_listening() -> bool:
	return false

## [子类重写] 应用特性的具体实现
func _apply_feature(instance: GameplayStatusInstance, context: Dictionary) -> void:
	pass

## [子类重写] 更新特性的具体实现
func _update_feature(instance: GameplayStatusInstance, delta: float) -> void:
	pass

## [子类重写] 移除特性的具体实现
func _remove_feature(instance: GameplayStatusInstance, context: Dictionary) -> void:
	pass

## [子类重写] 处理事件的具体实现
func _handle_event(instance: GameplayStatusInstance, event_id: StringName, context: Dictionary) -> void:
	pass
