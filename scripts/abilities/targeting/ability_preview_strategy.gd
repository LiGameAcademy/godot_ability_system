@abstract
extends Resource
class_name AbilityPreviewStrategy

## 技能预览策略基类

signal preview_confirmed(context: Dictionary)
signal preview_cancelled

## 开始预览方法（可以是创建UI/指示器/注册输入等）
## extra_context 可以传入诸如battle_manager、回合制场景引用等
@abstract func begin(caster: Node, ability_instance: GameplayAbilityInstance, extra_context: Dictionary = {}) -> void

## 每帧更新
func update(delta: float, input_context: Dictionary = {}) -> void:
	# input_context 可以放入： mouse_position、hovered_unit、当前控制模式等
	pass

## 是否正在预览
func is_targeting() -> bool:
	return false

## 是否已经完成（获取了有效的预览的结果）
func is_finished() -> bool:
	# 对于纯自动预览， begin之后就直接完成
	return true

## 是否被取消
func is_cancelled() -> bool:
	return false

## 结束预览/取消（释放指示器/ 隐藏UI元素等）
func cancel() -> void:
	pass

## 获取预览结果的上下文
## 只在 is_finished 为 ture 并且 没有取消的时候才调用
func get_result_context() -> Dictionary:
	return {}
