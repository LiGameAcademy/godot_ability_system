@abstract
extends Resource
class_name DamageLogicStrategy

## 伤害计算策略基类
## 业务层继承此类并重写 calculate 方法来自定义伤害公式

## 核心计算接口
## [param] damage_info: GameplayDamageInfo 伤害信息（包含基础伤害、攻击者等）
## [param] target_attributes: GameplayAttributeComponent 防御者的属性组件
## [return] float 最终伤害值
@abstract func calculate(target: Node, instigator: Node, context: Dictionary) -> float
