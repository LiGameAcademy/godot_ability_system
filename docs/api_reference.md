# API 参考

本文档提供 Godot Gameplay Ability System 的完整 API 参考。

## 单例

### GameplayAbilitySystem

系统管理器，提供组件查询接口。

#### 方法

##### `get_component_by_interface(entity: Node, component_name: String) -> Node`

通过接口查询组件（鸭子类型）。

**参数：**
- `entity`: 实体节点
- `component_name`: 组件名称（如 "GameplayAttributeComponent"）

**返回：** 组件节点，如果不存在则返回 `null`

---

## 组件

### GameplayAbilityComponent

技能组件，管理技能的学习、激活、冷却。

#### 信号

- `ability_learned(ability: GameplayAbilityInstance)` - 技能学会
- `ability_forgotten(ability_id: StringName)` - 技能遗忘
- `ability_activated(ability: GameplayAbilityInstance)` - 技能激活
- `ability_completed(ability: GameplayAbilityInstance)` - 技能完成

#### 方法

##### `initialize(initial_abilities: Array[GameplayAbilityDefinition] = []) -> void`

初始化技能组件。

##### `learn_ability(ability_data: GameplayAbilityDefinition) -> void`

学习技能。

##### `forget_ability(ability_id: StringName) -> void`

遗忘技能。

##### `try_activate_ability(ability_id: StringName, context: Dictionary = {}) -> bool`

尝试激活技能。

**返回：** 是否成功激活

##### `cancel_current_ability() -> void`

取消当前激活的技能。

##### `get_ability(ability_id: StringName) -> GameplayAbilityInstance`

获取技能实例。

##### `match_input(event: InputEvent) -> StringName`

匹配输入事件，返回对应的技能ID。

---

### GameplayAttributeComponent

属性组件，管理属性的计算和修改。

#### 信号

- `attribute_changed(attribute_id: StringName, old_value: float, new_value: float)` - 属性变化
- `base_value_changed(attribute_id: StringName, old_value: float, new_value: float)` - 基础值变化

#### 方法

##### `initialize_attribute_set(attribute_set: GameplayAttributeSet) -> void`

初始化属性集。

##### `get_value(attribute_id: StringName) -> float`

获取属性的最终值。

##### `get_base_value(attribute_id: StringName) -> float`

获取属性的基础值。

##### `set_base_value(attribute_id: StringName, value: float) -> void`

设置属性的基础值。

##### `add_modifier(modifier: GameplayAttributeModifier) -> void`

添加属性修改器。

##### `remove_modifier(attribute_id: StringName, source: String) -> void`

移除属性修改器。

##### `has_attribute(attribute_id: StringName) -> bool`

检查是否有该属性。

---

### GameplayStatusComponent

状态组件，管理 Buff/Debuff。

#### 信号

- `status_applied(status_instance: GameplayStatusInstance)` - 状态应用
- `status_removed(status_id: StringName)` - 状态移除
- `status_stacks_changed(status_instance: GameplayStatusInstance, old_stacks: int, new_stacks: int)` - 层数变化

#### 方法

##### `apply_status(status_data: GameplayStatusData, source: String = "") -> void`

应用状态。

##### `remove_status(status_id: StringName) -> void`

移除状态。

##### `has_status(status_id: StringName) -> bool`

检查是否有该状态。

##### `get_status(status_id: StringName) -> GameplayStatusInstance`

获取状态实例。

##### `get_all_statuses() -> Array[GameplayStatusInstance]`

获取所有状态。

##### `get_statuses_by_tag(tag: StringName) -> Array[GameplayStatusInstance]`

获取特定标签的状态。

---

### GameplayVitalAttributeComponent

资源属性组件，管理生命值、魔法值等资源。

#### 信号

- `vital_changed(vital_id: StringName, old_value: float, new_value: float, old_max: float, new_max: float)` - 资源变化

#### 方法

##### `initialize_vital(vital_id: StringName, current: float, max_value: float) -> void`

初始化资源。

##### `get_vital(vital_id: StringName) -> float`

获取资源当前值。

##### `get_max_vital(vital_id: StringName) -> float`

获取资源最大值。

##### `set_vital(vital_id: StringName, value: float) -> void`

设置资源值。

##### `set_max_vital(vital_id: StringName, value: float) -> void`

设置资源最大值。

##### `modify_vital(vital_id: StringName, amount: float) -> void`

修改资源值。

---

## 资源

### GameplayAbilityDefinition

技能定义资源。

#### 属性

- `ability_id: StringName` - 技能ID
- `ability_name: String` - 技能名称
- `description: String` - 技能描述
- `icon: Texture` - 技能图标
- `tags: Array[StringName]` - 技能标签
- `preview_strategy: AbilityPreviewStrategy` - 预览策略
- `features: Array[GameplayAbilityFeature]` - 特性列表
- `execution_tree: BTNode` - 行为树
- `blackboard_defaults: Dictionary` - 黑板默认数据

#### 方法

##### `create_instance(owner: Node) -> GameplayAbilityInstance`

创建技能实例。

---

### GameplayAttribute

属性定义资源。

#### 属性

- `attribute_id: StringName` - 属性ID
- `attribute_display_name: String` - 显示名称
- `min_value: float` - 最小值
- `max_value: float` - 最大值
- `is_percentage: bool` - 是否百分比
- `scalable_value: ScalableValue` - 可扩展属性

---

### GameplayStatusData

状态数据资源。

#### 属性

- `status_id: StringName` - 状态ID
- `status_display_name: String` - 显示名称
- `duration: float` - 持续时间
- `duration_policy: StatusDurationPolicy` - 持续时间策略
- `stacking_policy: StatusStackingPolicy` - 叠加策略
- `max_stacks: int` - 最大层数
- `priority: int` - 优先级
- `tags: Array[StringName]` - 状态标签
- `apply_effects: Array[GameplayEffect]` - 应用时效果
- `remove_effects: Array[GameplayEffect]` - 移除时效果
- `features: Array[StatusFeature]` - 状态特性

---

### GameplayEffect

游戏效果基类。

#### 方法

##### `apply_effect(target: Node, context: Dictionary) -> void`

应用效果。

---

## 实例

### GameplayAbilityInstance

技能实例。

#### 方法

##### `try_activate(context: Dictionary = {}) -> bool`

尝试激活技能。

##### `can_activate(context: Dictionary = {}) -> bool`

检查是否可以激活。

##### `cancel() -> void`

取消技能。

##### `update(delta: float) -> void`

更新技能状态。

##### `get_blackboard_var(key: String, default: Variant = null) -> Variant`

获取黑板变量。

##### `set_blackboard_var(key: String, value: Variant) -> void`

设置黑板变量。

---

### GameplayAttributeInstance

属性实例。

#### 方法

##### `get_value() -> float`

获取最终值。

##### `get_base_value() -> float`

获取基础值。

##### `add_modifier(modifier: GameplayAttributeModifier) -> void`

添加修改器。

##### `remove_modifier(source: String) -> void`

移除修改器。

---

### GameplayStatusInstance

状态实例。

#### 方法

##### `get_remaining_time() -> float`

获取剩余时间。

##### `get_stacks() -> int`

获取层数。

##### `add_stack() -> void`

增加层数。

##### `remove_stack() -> void`

减少层数。

---

## 效果

### GEApplyDamage

伤害效果。

#### 属性

- `damage_amount: float` - 伤害数值
- `damage_type: StringName` - 伤害类型
- `can_crit: bool` - 是否可以暴击
- `crit_multiplier: float` - 暴击倍率

---

### GEModifyVital

治疗效果。

#### 属性

- `vital_id: StringName` - 资源ID
- `modify_type: ModifyType` - 修改类型
- `value: float` - 修改数值

---

### GEAttributeModifier

属性修改效果。

#### 属性

- `attribute_id: StringName` - 属性ID
- `modifier_type: ModifierType` - 修改器类型
- `value: float` - 修改数值
- `duration: float` - 持续时间

---

### GEApplyStatus

状态应用效果。

#### 属性

- `status_data: GameplayStatusData` - 状态数据
- `duration: float` - 持续时间
- `stacks: int` - 叠加层数

---

## 行为树节点

### BTNode

行为树节点基类。

#### 枚举

- `Result.SUCCESS` - 成功
- `Result.FAILURE` - 失败
- `Result.RUNNING` - 运行中

#### 方法

##### `execute(blackboard: BTBlackboard) -> Result`

执行节点。

---

### BTSequence

顺序节点。

---

### BTSelector

选择节点。

---

### BTParallel

并行节点。

---

### AbilityNodeApplyCost

应用消耗节点。检查并应用技能的资源消耗。

**参考：** [`ability_node_apply_cost.gd`](../scripts/abilities/ability_nodes/ability_node_apply_cost.gd)

---

### AbilityNodeCommitCost

提交消耗节点。提交技能的资源消耗（在技能确认释放时）。

**参考：** [`ability_node_commit_cost.gd`](../scripts/abilities/ability_nodes/ability_node_commit_cost.gd)

---

### AbilityNodeCommitCooldown

提交冷却节点。提交技能的冷却时间。

**参考：** [`ability_node_commit_cooldown.gd`](../scripts/abilities/ability_nodes/ability_node_commit_cooldown.gd)

---

### AbilityNodeSpawnProjectile

生成投射物节点。生成投射物。

**参考：** [`ability_node_spawn_projectile.gd`](../scripts/abilities/ability_nodes/ability_node_spawn_projectile.gd)

---

### AbilityNodePlayAnimation

播放动画节点。播放动画。

**参考：** [`ability_node_play_animation.gd`](../scripts/abilities/ability_nodes/ability_node_play_animation.gd)

---

### BTWaitSignal

等待信号节点。

---

## 工具类

### DamageCalculator

伤害计算器（单例）。

#### 方法

##### `calculate_damage(damage_info: DamageInfo) -> float`

计算伤害。

---

### TagManager

标签管理器（单例）。

#### 方法

##### `has_tag(entity: Node, tag: StringName) -> bool`

检查实体是否有标签。

##### `add_tag(entity: Node, tag: StringName) -> void`

添加标签。

##### `remove_tag(entity: Node, tag: StringName) -> void`

移除标签。

---

### AbilityEventBus

事件总线（单例）。

#### 信号

- `ability_activated(ability: GameplayAbilityInstance)` - 技能激活
- `ability_completed(ability: GameplayAbilityInstance)` - 技能完成
- `status_applied(status: GameplayStatusInstance)` - 状态应用
- `status_removed(status_id: StringName)` - 状态移除

---

### GameplayCueManager

提示管理器（单例）。

#### 方法

##### `execute_cue(cue: GameplayCue, target: Node, context: Dictionary) -> void`

执行提示。

##### `stop_cue(cue: GameplayCue, target: Node) -> void`

停止提示。

---

## 总结

本文档提供了系统的主要 API 参考。更多详细信息请参考各模块的详细文档。

