# Godot Gameplay Ability System

**高内聚、低耦合的游戏技能系统插件**

[![Godot](https://img.shields.io/badge/Godot-4.5+-478CBF?logo=godot-engine)](https://godotengine.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📖 简介

Godot Gameplay Ability System 是一个功能完整、架构优雅的游戏技能系统插件，专为 Godot 4.5+ 设计。该系统采用**数据驱动**、**组件化**、**解耦合**、**可扩展**的设计理念，为游戏开发者提供了一个强大而灵活的技能系统框架。

本系统参考了 Unreal Engine 的 Gameplay Ability System (GAS) 设计思想，并结合 Godot 引擎的特性进行了优化和适配，适用于 ARPG、RTS、MOBA 等多种游戏类型。

## ✨ 核心特性

### 🎯 数据驱动设计
- 所有技能、状态、效果均通过资源文件配置
- 无需编写代码即可创建复杂的技能逻辑
- 支持运行时动态加载和修改

### 🧩 组件化架构
- **GameplayAbilityComponent**: 技能容器，管理技能的学习、激活、冷却
- **GameplayAttributeComponent**: 属性管理，支持属性修改器和计算
- **GameplayStatusComponent**: 状态管理，处理 Buff/Debuff 的叠加和持续时间
- **GameplayVitalAttributeComponent**: 资源管理（生命值、魔法值等）

### 🌳 行为树驱动的技能逻辑
- 使用行为树（Behavior Tree）描述技能执行流程
- 支持复杂的技能逻辑组合（连击、蓄力、切换等）
- 提供丰富的节点类型（等待、条件判断、并行执行等）

### 🔧 特性系统（Feature System）
- 通过组合不同的特性实现技能行为
- 内置特性：冷却、消耗、输入、切换、被动状态等
- 易于扩展，支持自定义特性

### 📊 属性系统
- 支持属性定义、属性集、属性实例
- 属性修改器系统（临时/永久、叠加/覆盖）
- 可扩展属性（ScalableValue）支持成长曲线

### 🎭 状态系统
- 完整的 Buff/Debuff 系统
- 支持状态叠加策略（刷新、叠加、累计持续时间等）
- 状态特性系统（周期性效果、事件监听等）

### 🎨 效果系统
- 丰富的游戏效果（伤害、治疗、属性修改、状态应用等）
- 效果可以应用到属性组件、资源组件或角色实体
- 支持效果链式组合

### 🏷️ 标签系统
- 基于标签的分类和过滤机制
- 支持技能、状态、效果的标签管理
- 用于实现技能互斥、状态免疫等功能

### 🎬 提示系统（Cue System）
- 逻辑与表现分离
- 支持粒子特效、音效、动画等视觉反馈
- 自动管理提示的生命周期

## 🚀 快速开始

### 安装

#### 方法一：Git 子模块（推荐）

```bash
git submodule add https://github.com/LiGameAcademy/godot_ability_system.git addons/godot_ability_system
```

#### 方法二：直接克隆

```bash
git clone https://github.com/LiGameAcademy/godot_ability_system.git addons/godot_ability_system
```

### 启用插件

1. 打开 Godot 编辑器
2. 进入 `项目 -> 项目设置 -> 插件`
3. 找到 `gameplay_abiltiy_system` 并启用

### 基本使用

#### 1. 创建角色并添加组件

```gdscript
extends CharacterBody2D
class_name Player

@onready var ability_component: GameplayAbilityComponent = $GameplayAbilityComponent
@onready var attribute_component: GameplayAttributeComponent = $GameplayAttributeComponent
@onready var status_component: GameplayStatusComponent = $GameplayStatusComponent

func _ready() -> void:
    # 初始化属性
    attribute_component.initialize_attribute_set(your_attribute_set)
    
    # 学习技能
    ability_component.learn_ability(your_ability_definition)
```

#### 2. 创建技能定义

在编辑器中创建 `GameplayAbilityDefinition` 资源：

1. 右键点击资源面板 -> `新建资源`
2. 选择 `GameplayAbilityDefinition`
3. 配置技能属性（ID、名称、图标等）
4. 添加特性（冷却、消耗等）
5. 创建行为树定义技能逻辑

#### 3. 激活技能

```gdscript
# 通过输入匹配
func _input(event: InputEvent) -> void:
    var ability_id = ability_component.match_input(event)
    if ability_id != "":
        ability_component.try_activate_ability(ability_id)

# 直接激活
ability_component.try_activate_ability(&"fireball")
```

## 📚 系统架构

### 核心概念

```
业务层 (player, enemy, npc)
    ↓ 通过组件
插件层
    ├── 组件层 (Components)
    │   ├── GameplayAbilityComponent
    │   ├── GameplayAttributeComponent
    │   ├── GameplayStatusComponent
    │   └── GameplayVitalAttributeComponent
    │
    ├── 实例层 (Instances)
    │   ├── GameplayAbilityInstance
    │   ├── GameplayAttributeInstance
    │   └── GameplayStatusInstance
    │
    ├── 资源层 (Resources)
    │   ├── GameplayAbilityDefinition
    │   ├── GameplayAttribute / AttributeSet
    │   ├── GameplayStatusData
    │   └── GameplayEffect
    │
    └── 系统层 (Systems)
        ├── GameplayAbilitySystem (单例)
        ├── DamageCalculator (单例)
        ├── TagManager (单例)
        ├── AbilityEventBus (单例)
        └── GameplayCueManager (单例)
```

### 数据流向

1. **资源定义** → **实例化** → **运行时实例** → **组件管理** → **挂载到角色**
2. **技能学习** → **技能激活** → **行为树执行** → **效果应用** → **状态/属性修改**

详细架构图请参考 [docs/gameplay_ability_system.png](docs/gameplay_ability_system.png)

## 🎮 功能模块

### 技能系统 (Ability System)

#### 技能特性 (Ability Feature)

- ✅ 技能冷却（Cooldown）
- ✅ 技能消耗（Cost）
- ✅ 技能输入（Input）
- ✅ 技能预览（Preview）

#### 技能配置模板 (Ability Template)

- ✅ 主动技能（Active Ability）
- ✅ 被动技能（Passive Ability）
- ✅ 切换技能（Toggle Ability）
- ✅ 连击技能（Combo Ability）
- ✅ 投射物技能（Projectile Ability）

### 属性系统 (Attribute System)

- ✅ 属性定义和配置
- ✅ 属性集（Attribute Set）
- ✅ 属性实例（Attribute Instance）
- ✅ 属性修改器（Attribute Modifier）
- ✅ 可扩展属性（ScalableValue）
- ✅ 属性变化通知

### 状态系统 (Status System)

- ✅ 状态数据定义
- ✅ 状态实例管理
- ✅ 状态叠加策略
- ✅ 持续时间策略
- ✅ 状态特性（周期性效果、事件监听）
- ✅ 状态优先级

### 效果系统 (Effect System)

- ✅ 伤害效果（Apply Damage）
- ✅ 治疗效果（Modify Vital）
- ✅ 属性修改效果（Attribute Modifier）
- ✅ 状态应用效果（Apply Status）
- ✅ 状态移除效果（Dispel Status）
- ✅ 状态转换效果（Status Transform）
- ✅ 魔法场生成（Spawn Magic Field）
- ✅ 投射物生成（Spawn Projectile）

### 行为树系统 (Behavior Tree)

- ✅ 组合节点（Sequence、Selector、Parallel）
- ✅ 装饰节点（Repeat、Wait、Condition）
- ✅ 动作节点（Play Animation、Apply Cost、Commit Cooldown）
- ✅ 等待信号节点（Wait Signal）
- ✅ 黑板系统（Blackboard）

### 其他系统

- ✅ 标签系统（Tag System）
- ✅ 提示系统（Cue System）
- ✅ 过滤器系统（Filter System）
- ✅ 伤害计算系统（Damage Calculator）
- ✅ 事件总线（Event Bus）

## 📖 文档

详细文档请参考 [docs/](docs/) 目录：

- [系统架构文档](docs/architecture.md) - 系统整体架构和设计理念
- [属性系统指南](docs/attribute_system.md) - 属性系统的配置和使用
- [效果系统指南](docs/effect_system.md) - 效果系统的创建和应用
- [状态系统指南](docs/status_system.md) - 状态系统的实现和使用
- [行为树指南](docs/behavior_tree.md) - 行为树的使用和节点说明
- [技能系统指南](docs/ability_system.md) - 技能系统的详细使用指南
- [API 参考](docs/api_reference.md) - 完整的 API 文档

## 🎯 设计原则

### 1. 数据驱动

所有游戏逻辑通过资源文件配置，减少代码编写，提高开发效率。

### 2. 组件化

采用组件模式，功能模块独立，易于组合和复用。

### 3. 解耦合

通过接口、信号、事件总线实现系统间的解耦，降低依赖关系。

### 4. 可扩展

提供丰富的扩展点，支持自定义特性、效果、节点等。

## 💡 使用示例

项目包含多个示例场景，位于 `examples/` 目录：

- `test_attribute.tscn` - 属性系统示例
- `test_vital_system.tscn` - 资源系统示例
- `test_status_component.tscn` - 状态系统示例
- `test_effect_basic.tscn` - 效果系统示例

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)。

## 👤 作者

**老李（玩物不丧志的老李）**

- 课程教程：[godot4架构实战：即时战斗与技能系统篇](https://www.bilibili.com/cheese/play/ss791568227)
- 知识星球：[老李游戏学院](https://wx.zsxq.com/group/28885154818841)

## 🙏 致谢

- 感谢 Unreal Engine 的 Gameplay Ability System 提供的设计灵感
- 感谢所有贡献者和使用者的反馈

---

**注意**: 本插件仍在积极开发中，API 可能会有变化。建议在生产环境使用前充分测试。
