extends TargetPicker
class_name PickerRandomN

## 随机选取 N 个目标
## 将输入列表打乱后，取前 N 个

@export var amount: int = 1

func pick(targets: Array[Node], _context: Dictionary) -> Array[Node]:
	if targets.size() <= amount:
		return targets
		
	var picked = targets.duplicate()
	picked.shuffle()
	return picked.slice(0, amount)
