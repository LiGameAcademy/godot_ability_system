extends TargetPicker
class_name PickerLastN

## 选取后 N 个目标
## 如果输入列表已排序（如按距离），这相当于取"最远的 N 个"

@export var amount: int = 1

func pick(targets: Array[Node], _context: Dictionary) -> Array[Node]:
	if targets.size() <= amount:
		return targets
	return targets.slice(targets.size() - amount)
