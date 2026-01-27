# 快速开始指南

本指南将帮助你快速上手 Godot Gameplay Ability System。

## 前置要求

- Godot 4.5 或更高版本
- 基本的 GDScript 知识
- 了解 Godot 的场景和节点系统

## 安装步骤

### 1. 添加子模块

```bash
git submodule add https://github.com/LiGameAcademy/godot_ability_system.git addons/godot_ability_system
```

### 2. 启用插件

1. 打开 Godot 编辑器
2. 进入 `项目 -> 项目设置 -> 插件`
3. 找到 `gameplay_abiltiy_system` 并启用

### 3. 验证安装

启用插件后，你应该能在资源创建菜单中看到以下资源类型：

- `GameplayAbilityDefinition`
- `GameplayAttribute`
- `GameplayAttributeSet`
- `GameplayStatusData`
- `GameplayEffect`
- 等等...

## 第一个技能：火球术

让我们创建一个简单的火球术技能。

### 步骤 1: 创建角色场景

1. 创建新场景，添加 `CharacterBody2D` 节点
2. 添加以下子节点：
   - `GameplayAbilityComponent` (命名为 `AbilityComponent`)
   - `GameplayAttributeComponent` (命名为 `AttributeComponent`)
   - `GameplayVitalAttributeComponent` (命名为 `VitalComponent`)

### 步骤 2: 创建属性

1. 创建 `GameplayAttribute` 资源，命名为 `attack.tres`
   - `attribute_id`: `attack`
   - `attribute_display_name`: `攻击力`

2. 创建 `GameplayAttributeSet` 资源，命名为 `player_attributes.tres`
   - 添加 `attack` 属性

3. 创建 `GameplayVital` 资源，命名为 `mana.tres`
   - `vital_id`: `mana`
   - `vital_display_name`: `魔法值`

### 步骤 3: 创建技能定义

1. 创建 `GameplayAbilityDefinition` 资源，命名为 `fireball.tres`
   - `ability_id`: `fireball`
   - `ability_name`: `火球术`
   - `description`: `发射一个火球，造成火焰伤害`

2. 添加冷却特性：
   - 创建 `CooldownFeature` 资源
   - `cooldown_duration`: `3.0`
   - 添加到 `features` 数组

3. 添加消耗特性：
   - 创建 `CostFeature` 资源
   - `cost_type`: `mana`
   - `cost_amount`: `20.0`
   - 添加到 `features` 数组

4. 添加输入特性：
   - 创建 `AbilityInputFeature` 资源
   - `input_action`: `ability_fireball`
   - 添加到 `features` 数组

### 步骤 4: 创建行为树

1. 创建 `BTNode` 资源，选择 `BTSequence`
2. 添加子节点：
   - `AbilityNodeApplyCost` - 应用消耗
   - `AbilityNodePlayAnimation` - 播放动画（可选）
   - `AbilityNodeSpawnProjectile` - 生成投射物
   - `AbilityNodeCommitCooldown` - 提交冷却

3. 配置节点参数（根据你的项目需求）

4. 将行为树赋值给技能定义的 `execution_tree`

### 步骤 5: 创建投射物数据

1. 创建 `ProjectileData` 资源
2. 配置投射物属性（速度、伤害等）

### 步骤 6: 配置技能脚本

在角色脚本中：

```gdscript
extends CharacterBody2D

@onready var ability_component: GameplayAbilityComponent = $AbilityComponent
@onready var attribute_component: GameplayAttributeComponent = $AttributeComponent
@onready var vital_component: GameplayVitalAttributeComponent = $VitalComponent

@export var fireball_ability: GameplayAbilityDefinition
@export var player_attributes: GameplayAttributeSet
@export var mana_vital: GameplayVital

func _ready() -> void:
    # 初始化属性
    attribute_component.initialize_attribute_set(player_attributes)
    attribute_component.set_base_value(&"attack", 100.0)
    
    # 初始化资源
    vital_component.initialize_vital(&"mana", 100.0, 100.0)
    
    # 学习技能
    if fireball_ability:
        ability_component.learn_ability(fireball_ability)

func _input(event: InputEvent) -> void:
    # 匹配输入并激活技能
    var ability_id = ability_component.match_input(event)
    if ability_id != "":
        ability_component.try_activate_ability(ability_id)
```

### 步骤 7: 配置输入映射

在项目设置中添加输入动作：

1. 进入 `项目 -> 项目设置 -> 输入映射`
2. 添加新动作：`ability_fireball`
3. 绑定按键（如 `Q` 键）

### 步骤 8: 测试

运行场景，按 `Q` 键应该能释放火球术！

## 第一个状态：燃烧

让我们创建一个燃烧状态（Debuff）。

### 步骤 1: 创建状态数据

1. 创建 `GameplayStatusData` 资源，命名为 `burn.tres`
   - `status_id`: `burn`
   - `status_display_name`: `燃烧`
   - `duration`: `10.0` (持续 10 秒)

2. 添加叠加策略：
   - 创建 `StackingRefreshDuration` 资源
   - 赋值给 `stacking_policy`

### 步骤 2: 创建伤害效果

1. 创建 `GEApplyDamage` 资源
   - `damage_amount`: `10.0`
   - `damage_type`: `fire`

2. 添加到状态的 `apply_effects` 数组

### 步骤 3: 添加周期性效果

1. 创建 `FeaturePeriodicEffects` 资源
   - `interval`: `1.0` (每秒触发一次)
   - `effects`: 添加伤害效果

2. 添加到状态的 `features` 数组

### 步骤 4: 应用状态

在技能效果中应用状态：

```gdscript
# 在技能定义中创建效果
var apply_status_effect = GEApplyStatus.new()
apply_status_effect.status_data = burn_status_data
apply_status_effect.duration = 10.0

# 添加到技能效果列表
ability_definition.effects.append(apply_status_effect)
```

## 下一步

现在你已经掌握了基本用法，可以：

1. 阅读详细文档：
   - [系统架构](architecture.md)
   - [技能系统指南](ability_system.md)
   - [属性系统指南](attribute_system.md)
   - [状态系统指南](status_system.md)
   - [效果系统指南](effect_system.md)
   - [行为树指南](behavior_tree.md)

2. 查看示例场景：
   - `examples/test_attribute.tscn`
   - `examples/test_vital_system.tscn`
   - `examples/test_status_component.tscn`
   - `examples/test_effect_basic.tscn`

3. 探索更多功能：
   - 创建更复杂的技能
   - 实现技能连击
   - 创建切换技能
   - 实现被动技能

## 常见问题

### Q: 技能无法激活？

A: 检查以下几点：
- 技能是否已学习
- 冷却时间是否结束
- 资源是否足够
- 输入是否正确绑定

### Q: 效果没有生效？

A: 检查以下几点：
- 效果是否正确添加到技能/状态
- 目标是否正确
- 效果过滤器是否阻止了效果

### Q: 属性值不正确？

A: 检查以下几点：
- 属性是否正确初始化
- 修改器是否正确添加
- 属性计算顺序是否正确

## 获取帮助

- 查看 [API 参考](api_reference.md)
- 提交 Issue 到 GitHub
- 参考示例场景

祝开发愉快！

