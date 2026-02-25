extends Resource
class_name TargetPicker

## 目标选取器 (抽象类)
## 用于在 Filtering (过滤) 和 Sorting (排序) 之后，对目标列表进行最终的裁切/选取
## 
## 典型应用：
## - 取前 N 个 (First N)
## - 随机取 N 个 (Random N)
## - 取后 N 个 (Last N)

## 选取目标
## [param] targets: Array[Node] 输入的目标列表 (通常已排序)
## [param] context: Dictionary 上下文
## [return] Array[Node] 最终选取的目标列表
func pick(targets: Array[Node], context: Dictionary) -> Array[Node]:
	return targets
