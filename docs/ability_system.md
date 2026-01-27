# 技能系统指南

## 概述

技能系统（Ability System）是 Godot Gameplay Ability System 的核心模块，负责管理游戏中所有技能的学习、激活、执行和冷却。

**核心设计：**
- 技能的执行序列基于**行为树（Behavior Tree）**，通过节点组合描述技能逻辑
- 行为树提供了灵活、可扩展的技能描述方式，支持复杂的技能流程控制
- 使用行为树的好处：
  - **可视化编辑**：可以在编辑器中直观地构建技能逻辑
  - **模块化设计**：通过组合节点实现复杂行为，易于维护和复用
  - **易于调试**：行为树执行历史清晰，便于问题定位
  - **支持中断**：行为树支持节点中断和优先级控制
  - **数据驱动**：技能逻辑通过资源文件配置，无需修改代码

## 核心概念

### 技能定义（Ability Definition）

技能定义是技能的静态配置，包含所有技能属性：

- **ability_id**: 技能唯一标识符
- **ability_name**: 技能名称
- **description**: 技能描述
- **icon**: 技能图标
- **tags**: 技能标签（用于分类和过滤）
- **preview_strategy**: 预览策略（用于技能释放前的视觉预览）
- **features**: 技能特性列表（冷却、消耗、输入等）
- **execution_tree**: 行为树（定义技能的执行逻辑）
- **blackboard_defaults**: 黑板默认数据（配置参数）

### 技能实例（Ability Instance）

技能实例是技能的运行时对象，由技能定义创建：

- 包含技能的执行状态
- 管理技能的黑板数据
- 处理技能的更新逻辑
- 提供技能激活接口

### 技能组件（Ability Component）

技能组件是技能的容器和管理者：

- 管理已学会的技能
- 处理技能的学习和遗忘
- 处理技能的激活和取消
- 更新技能状态（冷却时间等）

## 技能类型

> **说明**：以下技能类型是插件层提供的**配置模板**，用于快速创建常见类型的技能。用户可以在业务层继承 `GameplayAbilityDefinition` 创建自定义技能类型，实现更复杂的技能行为。

### 1. 主动技能（Active Ability）

最常见的技能类型，需要玩家主动释放。

**特性：**
- 有冷却时间
- 有资源消耗
- 有输入绑定
- 有执行逻辑

**示例：** 火球术、治疗术、冲锋

### 2. 被动技能（Passive Ability）

自动生效的技能，无需玩家操作。

**特性：**
- 学习后自动生效
- 无冷却时间
- 无资源消耗
- 持续生效

**示例：** 增加攻击力、减少伤害、自动回血

### 3. 切换技能（Toggle Ability）

可以开启/关闭的技能。

**特性：**
- 开启时持续消耗资源
- 可以随时关闭
- 关闭时停止消耗

**示例：** 护盾、光环、变身

### 4. 连击技能（Combo Ability）

需要连续输入才能释放的技能。

**特性：**
- 有连击窗口
- 需要按顺序输入
- 连击中断会重置

**示例：** 三段斩、连击拳

## 技能特性（Features）

技能特性是技能的模块化功能，通过组合不同的特性实现复杂的技能行为。

### 内置特性

#### 1. 冷却特性（Cooldown Feature）

控制技能的冷却时间。

**配置：**
- `cooldown_duration`: 冷却时间（秒）

**使用：**
```gdscript
# 在技能定义中添加冷却特性
var cooldown_feature = CooldownFeature.new()
cooldown_feature.cooldown_duration = 5.0
ability_definition.features.append(cooldown_feature)
```

#### 2. 消耗特性（Cost Feature）

控制技能的资源消耗。

**配置：**
- `cost_type`: 消耗类型（魔法值、生命值等）
- `cost_amount`: 消耗数量

**使用：**
```gdscript
var cost_feature = CostFeature.new()
cost_feature.cost_type = &"mana"
cost_feature.cost_amount = 50.0
ability_definition.features.append(cost_feature)
```

#### 3. 输入特性（Input Feature）

绑定技能的输入。

**配置：**
- `input_action`: 输入动作名称

**使用：**
```gdscript
var input_feature = AbilityInputFeature.new()
input_feature.input_action = &"ability_1"
ability_definition.features.append(input_feature)
```

#### 4. 切换特性（Toggle Feature）

使技能成为切换技能。

**配置：**
- `toggle_on_effect`: 开启时的效果
- `toggle_off_effect`: 关闭时的效果

#### 5. 被动状态特性（Passive Status Feature）

使技能成为被动技能，自动应用状态。

**配置：**
- `status_data`: 要应用的状态数据

## 创建技能

### 步骤 1: 创建技能定义资源

1. 在资源面板右键 -> `新建资源`
2. 选择 `GameplayAbilityDefinition`
3. 配置基本属性：
   - 设置 `ability_id`（如 `&"fireball"`）
   - 设置 `ability_name`（如 `"火球术"`）
   - 设置 `description`（技能描述）
   - 设置 `icon`（技能图标）

### 步骤 2: 添加技能特性

在技能定义中添加需要的特性：

```gdscript
# 添加冷却特性
var cooldown = CooldownFeature.new()
cooldown.cooldown_duration = 3.0
ability_definition.features.append(cooldown)

# 添加消耗特性
var cost = CostFeature.new()
cost.cost_type = &"mana"
cost.cost_amount = 20.0
ability_definition.features.append(cost)

# 添加输入特性
var input = AbilityInputFeature.new()
input.input_action = &"ability_fireball"
ability_definition.features.append(input)
```

### 步骤 3: 创建行为树

行为树定义技能的执行逻辑：

1. 创建 `BTNode` 资源
2. 构建行为树结构
3. 配置节点参数

**示例行为树结构：**
```
Sequence
├── ApplyCost (应用消耗)
├── PlayAnimation (播放动画)
├── WaitSignal (等待动画信号)
├── SpawnProjectile (生成投射物)
└── CommitCooldown (提交冷却)
```

### 步骤 4: 配置预览策略（可选）

如果需要技能预览，配置预览策略：

```gdscript
var preview = CircleAreaPreviewStrategy.new()
preview.radius = 5.0
ability_definition.preview_strategy = preview
```

**预览策略说明：**
- 预览策略（[`AbilityPreviewStrategy`](../scripts/abilities/targeting/ability_preview_strategy.gd)）用于技能释放前的视觉预览
- 与行为树中的 `TargetingStrategy`（目标选择策略）不同：
  - **预览策略**：预览阶段，显示指示器，获取鼠标位置
  - **目标选择策略**：执行阶段，在行为树中搜索目标单位

**预览策略工作流程：**
1. `create_indicator()`: 创建视觉指示器（如圆形贴花、箭头模型）
2. `update_indicator()`: 根据鼠标位置更新指示器
3. `get_targeting_context()`: 获取目标上下文数据，传递给行为树

**内置预览策略：**
- `CircleAreaPreviewStrategy`: 圆形区域预览
- `LineAreaPreviewStrategy`: 直线区域预览
- `ConeAreaPreviewStrategy`: 扇形区域预览

**自定义预览策略：**
```gdscript
extends AbilityPreviewStrategy
class_name CustomPreviewStrategy

@export var custom_parameter: float = 0.0

func create_indicator(parent: Node) -> Node3D:
    # 创建自定义指示器
    var indicator = preload("res://indicator.tscn").instantiate()
    parent.get_tree().current_scene.add_child(indicator)
    return indicator

func update_indicator(indicator: Node3D, caster: Node3D, mouse_position: Vector3) -> void:
    # 更新指示器位置和形状
    indicator.global_position = mouse_position

func get_targeting_context(caster: Node3D, mouse_position: Vector3) -> Dictionary:
    # 返回目标上下文数据
    return {
        "target_position": mouse_position,
        "target_type": "position"
    }
```

### 步骤 5: 配置黑板默认数据

在技能定义中配置黑板默认数据：

```gdscript
ability_definition.blackboard_defaults = {
    "projectile_speed": 10.0,
    "damage": 50.0,
    "range": 15.0
}
```

## 使用技能

### 学习技能

在角色初始化时学习技能：

```gdscript
@onready var ability_component: GameplayAbilityComponent = $GameplayAbilityComponent

func _ready() -> void:
    # 学习技能
    ability_component.learn_ability(fireball_ability_definition)
```

### 激活技能

#### 方法 1: 通过输入匹配

```gdscript
func _input(event: InputEvent) -> void:
    var ability_id = ability_component.match_input(event)
    if ability_id != "":
        ability_component.try_activate_ability(ability_id)
```

#### 方法 2: 直接激活

```gdscript
# 通过技能ID激活
ability_component.try_activate_ability(&"fireball")

# 通过技能实例激活
var ability = ability_component.get_ability(&"fireball")
if ability:
    ability.try_activate({})
```

### 检查技能状态

```gdscript
# 检查技能是否可用
var ability = ability_component.get_ability(&"fireball")
if ability and ability.can_activate({}):
    ability_component.try_activate_ability(&"fireball")

# 检查技能是否在冷却
if ability and ability.is_on_cooldown():
    var remaining = ability.get_cooldown_remaining()
    print("冷却剩余: ", remaining, " 秒")
```

### 取消技能

```gdscript
# 取消当前激活的技能
ability_component.cancel_current_ability()
```

## 技能信号

技能组件提供丰富的信号用于响应技能事件：

```gdscript
# 连接信号
ability_component.ability_learned.connect(_on_ability_learned)
ability_component.ability_activated.connect(_on_ability_activated)
ability_component.ability_completed.connect(_on_ability_completed)

func _on_ability_learned(ability: GameplayAbilityInstance) -> void:
    print("学会了技能: ", ability.get_definition().ability_name)

func _on_ability_activated(ability: GameplayAbilityInstance) -> void:
    print("激活了技能: ", ability.get_definition().ability_name)

func _on_ability_completed(ability: GameplayAbilityInstance) -> void:
    print("技能完成: ", ability.get_definition().ability_name)
```

## 高级功能

### 技能互斥

通过标签实现技能互斥：

```gdscript
# 在技能定义中设置互斥标签
ability_definition.tags = [&"exclusive_ability"]

# 在激活时检查互斥
if ability_component.has_active_ability_with_tag(&"exclusive_ability"):
    return  # 已有互斥技能激活，无法激活新技能
```

### 技能打断

技能可以被其他技能打断：

```gdscript
# 取消当前技能并激活新技能
ability_component.cancel_current_ability()
ability_component.try_activate_ability(&"new_ability")
```

### 技能连击

使用行为树实现技能连击：

```gdscript
# 行为树结构
Sequence
├── WaitSignal (等待输入信号)
├── CheckComboWindow (检查连击窗口)
├── PlayAnimation (播放连击动画)
└── ApplyEffect (应用效果)
```

## 技能预览系统

技能预览系统允许玩家在释放技能前看到技能的影响范围或目标位置。

### 预览策略配置

在技能定义中配置预览策略：

```gdscript
# 创建预览策略
var preview = CircleAreaPreviewStrategy.new()
preview.indicator_scene = preload("res://indicator_circle.tscn")
preview.max_range = 10.0
preview.snap_to_ground = true

# 配置到技能定义
ability_definition.preview_strategy = preview
ability_definition.smart_cast = false  # 是否开启智能施法（跳过预览）
```

### 预览流程

1. **开始预览**：玩家按下技能键时，如果技能配置了预览策略，进入预览模式
2. **更新预览**：鼠标移动时，更新指示器位置和形状
3. **确认释放**：玩家点击确认时，获取目标上下文并激活技能
4. **取消预览**：玩家按取消键时，退出预览模式

### 智能施法

如果技能配置了 `smart_cast = true`，则跳过预览阶段，直接向鼠标位置释放技能。

## 最佳实践

1. **使用资源文件配置技能**：所有技能配置通过资源文件，避免硬编码
2. **合理使用特性**：通过组合特性实现复杂行为，避免重复代码
3. **使用行为树描述逻辑**：复杂技能逻辑使用行为树，易于理解和修改
4. **利用黑板传递数据**：技能内部数据通过黑板传递，避免全局变量
5. **响应技能信号**：通过信号响应技能事件，实现UI更新和反馈
6. **合理使用预览策略**：需要精确瞄准的技能使用预览策略，瞬发技能可以跳过预览

## 总结

技能系统提供了完整的技能管理框架，支持多种技能类型和丰富的特性组合。通过数据驱动和组件化设计，可以轻松创建和管理复杂的技能系统。

