extends GAS_BTComposite
class_name GAS_BTDynamicSequence

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	# 每次 tick 都从头开始
	for i in range(children.size()):
		var child = children[i]
		var result = child.tick(instance, delta)

		if result == Status.RUNNING:
			# 记住当前正在运行的子节点索引
			_set_storage(instance, i)
			return Status.RUNNING

		if result == Status.FAILURE:
			# 一旦有失败，立即返回失败
			reset(instance)
			return Status.FAILURE

	# 如果所有子节点都返回 SUCCESS
	reset(instance)
	return Status.SUCCESS
