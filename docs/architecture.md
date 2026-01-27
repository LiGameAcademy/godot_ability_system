# 系统架构文档

## 概述

Godot Gameplay Ability System 采用分层架构设计，实现了业务层与插件层的完全解耦。系统遵循**数据驱动**、**组件化**、**解耦合**、**可扩展**四大设计原则。

## 架构层次

### 1. 业务层（Business Layer）

业务层是游戏的具体实现，包括玩家、敌人、NPC 等游戏实体。这些实体通过组件与插件层交互，不直接依赖插件内部实现。

```
player, enemy, npc
    ↓ 通过组件
character (业务实体)
    ↓ 通过组件
component (组件)
ability_component, attribute_component, status_component, vital_component, etc.
    ↓ 通过接口
system (系统)
```

**特点：**
- 完全独立于插件实现
- 通过组件接口与系统交互
- 可以适配不同的游戏架构

### 2. 插件层（Plugin Layer）

插件层是系统的核心，包含所有功能模块。

#### 2.1 组件层（Component Layer）

组件是功能的容器和管理者，挂载在角色实体上。

- **GameplayAttributeComponent**: 属性管理，处理属性计算和修改
- **GameplayVitalAttributeComponent**: 资源管理（生命值、魔法值等）
- **GameplayStatusComponent**: 状态管理，处理 Buff/Debuff
- **GameplayAbilityComponent**: 技能容器，管理技能的学习、激活、冷却

#### 2.2 实例层（Instance Layer）

实例是运行时的动态对象，由资源定义创建。

- **GameplayAttributeInstance**: 属性实例，包含属性的当前值和修改器
- **GameplayStatusInstance**: 状态实例，包含状态的层数、剩余时间等信息
- **GameplayAbilityInstance**: 技能实例，包含技能的执行状态和黑板数据

#### 2.3 资源层（Resource Layer）

资源是静态配置数据，定义在编辑器中。

- **GameplayAbilityDefinition**: 技能定义，包含技能的所有配置
- **GameplayAttributeDefinition / AttributeSetDefinition**: 属性定义和属性集定义
- **GameplayStatusData**: 状态数据，定义 Buff/Debuff 的属性
- **GameplayEffect**: 效果资源，定义各种游戏效果

#### 2.4 系统层（System Layer）

系统层提供全局服务和单例。

- **GameplayAbilitySystem**: 系统管理器，提供组件查询接口
- **DamageCalculator**: 伤害计算器，计算伤害值
- **TagManager**: 标签管理器，管理游戏实体的标签
- **AbilityEventBus**: 能力系统事件总线
- **GameplayCueManager**: 提示管理器，管理游戏实体的提示

## 数据流向

### 属性系统数据流

```
attribute (资源定义)
    ↓ 配置
attribute_set (属性集)
    ↓ 实例化
attribute_instance (运行时实例)
    ↓ 管理
attribute_component (属性组件)
    ↓ 挂载
character (业务实体)
```

### 技能系统数据流

```
ability (技能资源)
    ↓ 学习
ability_component (技能组件)
    ↓ 释放
status_data (状态资源)
    ↓ 应用(实例化)
status_instance (状态实例)
    ↓ 触发
effect (效果资源)
    ↓ 应用
attribute_component / vital_component / character
```

## 核心设计模式

### 1. 组件模式（Component Pattern）

系统采用组件模式，将功能模块化：

- 每个组件负责特定功能
- 组件之间通过接口和信号通信
- 组件可以独立测试和复用

### 2. 工厂模式（Factory Pattern）

资源定义通过工厂方法创建实例：

```gdscript
# 技能定义创建技能实例
func create_instance(owner: Node) -> GameplayAbilityInstance

# 属性集创建属性实例
func create_instance() -> GameplayAttributeInstance
```

### 3. 策略模式（Strategy Pattern）

系统大量使用策略模式实现可配置行为：

- **TargetingStrategy**: 目标选择策略
- **StatusStackingPolicy**: 状态叠加策略
- **StatusDurationPolicy**: 持续时间策略
- **DamageLogicStrategy**: 伤害计算策略

### 4. 观察者模式（Observer Pattern）

通过信号系统实现观察者模式：

- 组件发出信号通知状态变化
- 业务层订阅信号响应事件
- 事件总线提供全局事件通知

### 5. 命令模式（Command Pattern）

技能激活通过命令模式实现：

- 技能激活封装为命令
- 支持技能取消和重做
- 行为树节点作为命令执行器

## 解耦机制

### 1. 接口抽象

系统通过接口而非具体类进行交互：

```gdscript
# 通过接口查询组件（鸭子类型）
func get_component_by_interface(entity: Node, component_name: String) -> Node
```

### 2. 信号通信

组件之间通过信号通信，避免直接引用：

```gdscript
signal ability_activated(ability: GameplayAbilityInstance)
signal attribute_changed(attribute_id: StringName, old_value: float, new_value: float)
```

### 3. 事件总线

全局事件通过事件总线传递：

```gdscript
# 使用统一游戏事件接口
AbilityEventBus.trigger_game_event(&"ability_activated", {
    "ability_instance": ability_instance,
    "entity": entity
})
```

### 4. 资源驱动

所有配置通过资源文件，代码不依赖具体数据：

```gdscript
@export var ability_definition: GameplayAbilityDefinition
```

## 扩展点

系统提供丰富的扩展点，支持自定义功能：

### 1. 自定义特性（Feature）

继承 `GameplayAbilityFeature` 创建自定义特性：

```gdscript
extends GameplayAbilityFeature
class_name CustomFeature

func can_activate(ability: GameplayAbilityInstance, context: Dictionary) -> bool:
    # 自定义激活条件
    return true
```

### 2. 自定义效果（Effect）

继承 `GameplayEffect` 创建自定义效果：

```gdscript
extends GameplayEffect
class_name CustomEffect

func apply_effect(target: Node, context: Dictionary) -> void:
    # 自定义效果逻辑
    pass
```

### 3. 自定义行为树节点

继承 `BTNode` 创建自定义节点：

```gdscript
extends BTNode
class_name CustomBTNode

func execute(blackboard: BTBlackboard) -> BTNode.Result:
    # 自定义节点逻辑
    return BTNode.Result.SUCCESS
```

### 4. 自定义目标选择策略

继承 `AbilityTargetingStrategy` 创建自定义策略：

```gdscript
extends AbilityTargetingStrategy
class_name CustomTargetingStrategy

func select_target(context: Dictionary) -> Node:
    # 自定义目标选择逻辑
    return null
```

## 性能优化

> **TODO**: 以下性能优化功能目前尚未实现，计划在后续版本中添加。

### 1. 对象池

频繁创建/销毁的对象使用对象池：

- 投射物对象池
- 特效对象池

### 2. 延迟计算

属性值采用延迟计算，只在需要时重新计算：

```gdscript
var _cached_value: float = 0.0
var _is_dirty: bool = true

func get_value() -> float:
    if _is_dirty:
        _cached_value = _calculate_value()
        _is_dirty = false
    return _cached_value
```

### 3. 信号优化

避免在 `_process` 中频繁发射信号，使用标志位控制：

```gdscript
var _needs_notification: bool = false

func _process(delta: float) -> void:
    if _needs_notification:
        attribute_changed.emit(...)
        _needs_notification = false
```

## 总结

Godot Gameplay Ability System 通过分层架构和设计模式，实现了高内聚、低耦合的系统设计。系统易于使用、易于扩展、易于维护，为游戏开发者提供了一个强大而灵活的技能系统框架。

