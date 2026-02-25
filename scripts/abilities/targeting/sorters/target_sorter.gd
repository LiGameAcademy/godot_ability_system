extends Resource
class_name TargetSorter

## 目标排序器 (抽象类)
## 用于为数组排序提供比较函数

## 比较两个目标
## [param] a: Node 目标 A
## [param] b: Node 目标 B
## [param] context: Dictionary 上下文
## [return] bool 如果 a 应该排在 b 前面，返回 true
func compare(a: Node, b: Node, context: Dictionary) -> bool:
	# 默认实现：保持原序 (不交换)
	return false

## 预处理 (可选)
## 在排序开始前调用，可用于缓存一些计算结果（如参考点位置）
## [param] targets: Array[Node] 所有目标
## [param] context: Dictionary 上下文
func prepare(targets: Array[Node], context: Dictionary) -> void:
	pass

