extends GAS_BTComposite
class_name GAS_BTDynamicSelector

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	# 每次 tick 都从第一个子节点开始
	for i in range(children.size()):
		var child = children[i]
		var result = child.tick(instance, delta)

		if result == Status.SUCCESS:
			# 一旦有成功，立即返回成功
			reset(instance)
			return Status.SUCCESS

		if result == Status.RUNNING:
			# 记住当前正在运行的子节点索引
			_set_storage(instance, i)
			return Status.RUNNING

		# 如果是 FAILURE，就继续尝试下一个子节点

	# 如果所有子节点都失败
	reset(instance)
	return Status.FAILURE
