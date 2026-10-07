@abstract
extends Resource
class_name AbilityCostBase

## 技能消耗器/限制器基类（抽象类）
## 用于定义技能施放时的资源消耗或限制条件
## 支持多种消耗类型：魔法值、怒气、能量、生命值等
## 也支持限制条件：如"生命值低于50%时无法使用"

## 检查是否可以支付消耗（不实际消耗）
## [param] ability_comp: GameplayAbilityComponent 能力组件
## [param] instigator: Node 施法者
## [return] bool 是否可以支付
func can_pay(ability_comp: Node, instigator: Node) -> bool:
	return _can_pay(ability_comp, instigator)

## 尝试支付消耗（实际消耗资源）
## [param] ability_comp: GameplayAbilityComponent 能力组件
## [param] instigator: Node 施法者
## [return] bool 是否成功支付
func try_pay(ability_comp: Node, instigator: Node) -> bool:
	if supports_prepared_payment() and (not is_instance_valid(ability_comp) or not is_instance_valid(instigator)):
		return false
	if not _can_pay(ability_comp, instigator):
		return false
	if supports_prepared_payment():
		var payment: AbilityCostPayment = prepare_payment(ability_comp, instigator, [])
		if not is_instance_valid(payment) or not payment.can_apply():
			return false
		payment.apply()
		payment.notify_changes()
		return true
	return _try_pay(ability_comp, instigator)
	
## 获取消耗描述（用于UI显示）
## [return] String 消耗描述文本
func get_cost_description() -> String:
	return _get_cost_description()

## 新自定义费用显式选择准备契约；旧费用默认保留原支付钩子。
func supports_prepared_payment() -> bool:
	return false

## 只读地构建本次付款计划。允许合并 pending 中同一运行余额的计划；不可改库存或发通知。
## 返回 null 表示无法准备；不是退回旧支付钩子的请求。
func prepare_payment(_ability_comp: Node, _instigator: Node, _pending: Array[AbilityCostPayment]) -> AbilityCostPayment:
	return null

@abstract func _can_pay(ability_comp: Node, instigator: Node) -> bool
@abstract func _try_pay(ability_comp: Node, instigator: Node) -> bool
func _get_cost_description() -> String:
	return "消耗: 未知"
