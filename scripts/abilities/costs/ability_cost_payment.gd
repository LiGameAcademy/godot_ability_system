@abstract
extends RefCounted
class_name AbilityCostPayment

## 一次付款的运行计划，不存到共享费用配置上。
## 准备与复核只读；apply 必须同步、无失败地写入，不能发信号或调用外部回调。
## 同一余额的多笔费用应在准备阶段合并为同一个计划，再检查合计。
@abstract func can_apply() -> bool
@abstract func apply() -> void

## 所有费用、冷却和提交记录写好后才调用。通知可携带本次付款的快照。
func notify_changes() -> void:
	pass
