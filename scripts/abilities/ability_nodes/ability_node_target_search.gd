extends AbilityNodeBase
class_name AbilityNodeTargetSearch

## [核心] 目标获取策略资源
@export var strategy: TargetingStrategy
## [输入] 初始目标来源 Key (通常是 context 或 input_target)
## 如果策略依赖"点击的目标"作为中心点（如传染技能），这很重要
@export var input_target_key: String = "target"
## [输出] 结果写入黑板的 Key
@export var write_to_key: String = "targets"
## [逻辑] 如果没找到任何目标，是否视为节点失败？
## True: 返回 FAILURE (中断 Sequence)
## False: 返回 SUCCESS (允许空挥)
@export var fail_if_empty: bool = false

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	# 1. 安全检查
	if not is_instance_valid(strategy):
		push_warning("AbilityNodeTargetSearch: Missing strategy.")
		return Status.FAILURE
	
	# 2. 获取上下文和施法者
	var context = _get_context(instance)
	var instigator = context.get("instigator")
	var input_target = _get_var(instance, input_target_key)
	
	# 3. 执行策略 (核心逻辑)
	var found_targets = strategy.resolve_targets(instigator, input_target, context)

	# 4. 处理结果
	if found_targets.is_empty():
		# 清理黑板，避免残留旧数据
		_set_var(instance, write_to_key, []) 
		return Status.FAILURE if fail_if_empty else Status.SUCCESS
	
	# 5. 写入黑板
	_set_var(instance, write_to_key, found_targets)
	return Status.SUCCESS
