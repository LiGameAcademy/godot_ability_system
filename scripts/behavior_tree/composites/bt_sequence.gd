extends GAS_BTComposite
class_name GAS_BTSequence

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	# 1. 获取上次运行到的索引 (默认为 0)
	var current_index = _get_storage(instance, 0)

	for i in range(current_index, children.size()):
		var child = children[i]
		var result = child.tick(instance, delta)
		
		if result == Status.RUNNING:
			# 记录当前运行到了谁
			_set_storage(instance, i)
			return Status.RUNNING
		if result == Status.FAILURE:
			# 失败了，清理状态，重置当前运行的子节点(如果有必要)，返回失败
			reset(instance)
			return Status.FAILURE

	# 全部执行完，返回成功
	reset(instance)
	return Status.SUCCESS
