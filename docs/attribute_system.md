# 属性系统指南

## 概述

属性系统（Attribute System）负责管理游戏中的各种属性，如攻击力、防御力、生命值、魔法值等。系统支持属性的定义、计算、修改和通知。

## 核心概念

### 属性（Attribute）

属性是游戏中的基本数值，如攻击力、防御力等。

**属性定义包含：**
- `attribute_id`: 属性唯一标识符
- `attribute_display_name`: 显示名称
- `attribute_description`: 描述
- `min_value`: 最小值
- `max_value`: 最大值
- `is_percentage`: 是否百分比显示
- `scalable_value`: 可扩展属性（支持成长曲线）

### 属性集（Attribute Set）

属性集是一组相关属性的集合，通常代表一个角色的所有属性。

**用途：**
- 组织相关属性
- 批量创建属性实例
- 管理属性依赖关系

**属性集配置：**
- `attributes`: 固定值属性字典（`Dictionary[GameplayAttribute, float]`）
- `scalable_attributes`: 可扩展属性字典（`Dictionary[GameplayAttribute, ScalableValue]`）
- 如果属性同时在两个字典中，优先使用 `scalable_attributes` 中的值

**钩子函数：**
- `resolve_dependencies(comp)`: 当组件初始化完毕，所有属性都创建好之后调用，用于计算初始的衍生属性
- `on_attribute_changed(comp, attr_id, new_val)`: 当任何属性值发生变化时调用，用于实时更新衍生属性

### 属性实例（Attribute Instance）

属性实例是属性的运行时对象，包含属性的当前值和修改器。

**包含：**
- 基础值（Base Value）
- 修改器列表（Modifiers）
- 最终值（Final Value）

### 属性修改器（Attribute Modifier）

属性修改器用于临时或永久修改属性值。

**修改器类型：**
- **Add**: 加法修改（+10）
- **Multiply**: 乘法修改（×1.5）
- **Override**: 覆盖修改（=100）

**修改器来源：**
- 装备
- 状态效果
- 技能效果
- 临时增益

## 属性计算流程

```
基础值 (Base Value)
    ↓
应用加法修改器 (Add Modifiers)
    ↓
应用乘法修改器 (Multiply Modifiers)
    ↓
应用覆盖修改器 (Override Modifiers)
    ↓
最终值 (Final Value)
```

## 创建属性系统

### 步骤 1: 创建属性定义

1. 创建 `GameplayAttribute` 资源
2. 配置属性：
   ```gdscript
   var attack_attribute = GameplayAttribute.new()
   attack_attribute.attribute_id = &"attack"
   attack_attribute.attribute_display_name = "攻击力"
   attack_attribute.min_value = 0.0
   attack_attribute.max_value = 9999.0
   ```

### 步骤 2: 创建属性集

1. 创建 `GameplayAttributeSet` 资源
2. 添加属性到属性集：
   ```gdscript
   var attribute_set = GameplayAttributeSet.new()
   # 方式1：使用固定值
   attribute_set.attributes[attack_attribute] = 100.0
   attribute_set.attributes[defense_attribute] = 50.0
   
   # 方式2：使用可扩展值（支持成长曲线）
   var scalable_attack = ScalableValue.new()
   scalable_attack.base_value = 100.0
   scalable_attack.growth_per_level = 10.0
   attribute_set.scalable_attributes[attack_attribute] = scalable_attack
   ```

**属性集实例化：**
```gdscript
# 属性集会自动实例化所有属性
var instances = attribute_set.instantiate_attributes()
# 返回 Dictionary[StringName, GameplayAttributeInstance]
```

### 步骤 3: 初始化属性组件

在角色节点上添加 `GameplayAttributeComponent`：

```gdscript
@onready var attribute_component: GameplayAttributeComponent = $GameplayAttributeComponent

func _ready() -> void:
    # 初始化属性集
    attribute_component.initialize_attribute_set(your_attribute_set)
    
    # 设置基础值
    attribute_component.set_base_value(&"attack", 100.0)
    attribute_component.set_base_value(&"defense", 50.0)
```

## 使用属性

### 获取属性值

```gdscript
# 获取最终值（包含所有修改器）
var attack = attribute_component.get_value(&"attack")

# 获取基础值
var base_attack = attribute_component.get_base_value(&"attack")

# 检查属性是否存在
if attribute_component.has_attribute(&"attack"):
    print("攻击力: ", attribute_component.get_value(&"attack"))
```

### 修改属性值

```gdscript
# 设置基础值
attribute_component.set_base_value(&"attack", 150.0)

# 添加属性修改器
var modifier = GameplayAttributeModifier.new()
modifier.attribute_id = &"attack"
modifier.modifier_type = GameplayAttributeModifier.ModifierType.ADD
modifier.value = 20.0
modifier.source = "equipment_sword"

attribute_component.add_modifier(modifier)

# 移除属性修改器
attribute_component.remove_modifier(&"attack", "equipment_sword")
```

### 属性修改器示例

#### 加法修改器（增加固定值）

```gdscript
var modifier = GameplayAttributeModifier.new()
modifier.attribute_id = &"attack"
modifier.modifier_type = GameplayAttributeModifier.ModifierType.ADD
modifier.value = 10.0
modifier.source = "buff_strength"
attribute_component.add_modifier(modifier)
```

#### 乘法修改器（百分比增加）

```gdscript
var modifier = GameplayAttributeModifier.new()
modifier.attribute_id = &"attack"
modifier.modifier_type = GameplayAttributeModifier.ModifierType.MULTIPLY
modifier.value = 1.2  # 增加 20%
modifier.source = "buff_rage"
attribute_component.add_modifier(modifier)
```

#### 覆盖修改器（设置固定值）

```gdscript
var modifier = GameplayAttributeModifier.new()
modifier.attribute_id = &"attack"
modifier.modifier_type = GameplayAttributeModifier.ModifierType.OVERRIDE
modifier.value = 200.0
modifier.source = "skill_berserker"
attribute_component.add_modifier(modifier)
```

## 属性信号

属性组件提供信号用于响应属性变化：

```gdscript
# 连接信号
attribute_component.attribute_changed.connect(_on_attribute_changed)
attribute_component.base_value_changed.connect(_on_base_value_changed)

func _on_attribute_changed(attribute_id: StringName, old_value: float, new_value: float) -> void:
    print("属性变化: ", attribute_id, " ", old_value, " -> ", new_value)

func _on_base_value_changed(attribute_id: StringName, old_value: float, new_value: float) -> void:
    print("基础值变化: ", attribute_id, " ", old_value, " -> ", new_value)
```

## 可扩展属性（ScalableValue）

可扩展属性支持属性的成长曲线，常用于角色升级系统。

### 创建可扩展属性

```gdscript
var scalable_value = ScalableValue.new()
scalable_value.base_value = 100.0
scalable_value.growth_per_level = 10.0
scalable_value.growth_type = ScalableValue.GrowthType.LINEAR

# 在属性中使用
attack_attribute.scalable_value = scalable_value
```

### 使用可扩展属性

```gdscript
# 设置等级
scalable_value.level = 10

# 获取当前等级的值
var value = scalable_value.get_value_at_level(10)
```

## 资源属性（Vital Attributes）

资源属性是特殊的属性，用于表示生命值、魔法值等资源。

### 使用资源属性组件

```gdscript
@onready var vital_component: GameplayVitalAttributeComponent = $GameplayVitalAttributeComponent

func _ready() -> void:
    # 初始化资源属性
    vital_component.initialize_vital(&"health", 100.0, 100.0)  # 当前值, 最大值
    vital_component.initialize_vital(&"mana", 50.0, 50.0)
    
    # 监听资源变化
    vital_component.vital_changed.connect(_on_vital_changed)
```

### 修改资源值

```gdscript
# 增加资源
vital_component.modify_vital(&"health", 20.0)  # 增加 20

# 减少资源
vital_component.modify_vital(&"health", -10.0)  # 减少 10

# 设置资源值
vital_component.set_vital(&"health", 80.0)  # 设置为 80

# 设置最大值
vital_component.set_max_vital(&"health", 150.0)
```

## 属性与效果系统集成

属性修改器可以通过效果系统自动应用：

```gdscript
# 创建属性修改效果
var effect = GEAttributeModifier.new()
effect.attribute_id = &"attack"
effect.modifier_type = GameplayAttributeModifier.ModifierType.ADD
effect.value = 15.0
effect.duration = 10.0  # 持续 10 秒

# 应用到目标
effect.apply_effect(target, {})
```

## 最佳实践

1. **使用属性集组织属性**：相关属性放在同一个属性集中
2. **合理使用修改器类型**：加法用于固定值，乘法用于百分比
3. **及时清理修改器**：状态效果移除时记得移除对应的修改器
4. **使用信号更新UI**：属性变化时通过信号通知UI更新
5. **缓存属性值**：频繁访问的属性值可以缓存，避免重复计算

## 总结

属性系统提供了完整的属性管理框架，支持属性的定义、计算、修改和通知。通过属性修改器系统，可以灵活地实现各种属性变化效果。

