# 过滤器系统指南

## 概述

过滤器系统（Filter System）用于过滤效果的目标，确保效果只对符合条件的目标生效。过滤器系统提供了灵活的目标筛选机制，支持基于标签、距离、关系等多种筛选条件。

## 核心概念

### 过滤器（GameplayFilterData）

所有过滤器都继承自 [`GameplayFilterData`](../scripts/filters/gameplay_filter.gd)，这是一个抽象基类。

**核心方法：**
- `check(target, instigator, context)`: 检查目标是否通过过滤器
- `_check(target, instigator, context)`: 子类需要实现的检查逻辑

**工作原理：**
- 效果应用前，会依次检查所有过滤器
- 所有过滤器都通过时，效果才会应用
- 任意一个过滤器失败，效果不会应用

## 内置过滤器

### 1. 标签过滤器（FilterTargetByTags）

通过标签筛选目标，用于筛选敌我、阵营、类型等。

**属性：**
- `required_tags`: 目标必须拥有的标签（所有标签都必须拥有）
- `blocked_tags`: 目标不能拥有的标签（任意一个标签存在就会被过滤掉）
- `include_inherited`: 是否包含继承的标签（默认 true）

**使用示例：**
```gdscript
# 创建标签过滤器
var filter = FilterTargetByTags.new()
filter.required_tags = [&"enemy", &"living"]  # 必须是敌人且是活体
filter.blocked_tags = [&"boss", &"invulnerable"]  # 不能是Boss且不能无敌

# 在效果中使用
damage_effect.filters.append(filter)
```

**应用场景：**
- 只对敌人造成伤害
- 只对友军进行治疗
- 排除特定类型的目标（如Boss、无敌单位）

## 使用过滤器

### 在效果中配置过滤器

```gdscript
# 创建效果
var damage_effect = GEApplyDamage.new()
damage_effect.damage_amount = 100.0

# 添加过滤器
var enemy_filter = FilterTargetByTags.new()
enemy_filter.required_tags = [&"enemy"]
damage_effect.filters.append(enemy_filter)

# 效果只会对拥有 "enemy" 标签的目标生效
```

### 多个过滤器

效果可以配置多个过滤器，所有过滤器都通过时效果才会生效：

```gdscript
var heal_effect = GEModifyVital.new()
heal_effect.vital_id = &"health"
heal_effect.value = 50.0

# 添加多个过滤器
var ally_filter = FilterTargetByTags.new()
ally_filter.required_tags = [&"ally"]
heal_effect.filters.append(ally_filter)

var living_filter = FilterTargetByTags.new()
living_filter.required_tags = [&"living"]
heal_effect.filters.append(living_filter)

# 效果只会对既是友军又是活体的目标生效
```

### 过滤器与标签系统集成

过滤器系统与标签系统深度集成，可以充分利用标签系统的功能：

```gdscript
# 利用标签继承
var filter = FilterTargetByTags.new()
filter.required_tags = [&"enemy"]
filter.include_inherited = true  # 包含继承的标签

# 如果目标继承了 "enemy" 标签，也会通过过滤器
```

## 自定义过滤器

继承 `GameplayFilterData` 创建自定义过滤器：

```gdscript
extends GameplayFilterData
class_name FilterByDistance

## 最大距离
@export var max_distance: float = 10.0

## 最小距离
@export var min_distance: float = 0.0

func _check(target: Node, instigator: Node, context: Dictionary) -> bool:
    if not is_instance_valid(target) or not is_instance_valid(instigator):
        return false
    
    # 计算距离
    var distance = instigator.global_position.distance_to(target.global_position)
    
    # 检查距离范围
    return distance >= min_distance and distance <= max_distance
```

**使用自定义过滤器：**
```gdscript
var range_filter = FilterByDistance.new()
range_filter.max_distance = 5.0
range_filter.min_distance = 1.0

damage_effect.filters.append(range_filter)
```

### 更复杂的自定义过滤器示例

```gdscript
extends GameplayFilterData
class_name FilterByHealthPercentage

## 生命值百分比范围
@export var min_health_percentage: float = 0.0
@export var max_health_percentage: float = 1.0

func _check(target: Node, instigator: Node, context: Dictionary) -> bool:
    if not is_instance_valid(target):
        return false
    
    # 获取 Vital 组件
    var vital_comp = GameplayAbilitySystem.get_component_by_interface(
        target, 
        "GameplayVitalAttributeComponent"
    )
    
    if not is_instance_valid(vital_comp):
        return false
    
    # 获取生命值
    var health = vital_comp.get_vital(&"health")
    if not is_instance_valid(health):
        return false
    
    # 计算生命值百分比
    var health_percentage = health.current_value / health.max_value
    
    # 检查范围
    return health_percentage >= min_health_percentage and \
           health_percentage <= max_health_percentage
```

## 过滤器执行流程

当效果应用时，过滤器按以下流程执行：

```
1. 效果开始应用
   ↓
2. 检查所有过滤器（按顺序）
   ├─ 过滤器1.check() → 通过？
   ├─ 过滤器2.check() → 通过？
   └─ 过滤器3.check() → 通过？
   ↓
3. 所有过滤器都通过？
   ├─ 是 → 应用效果
   └─ 否 → 跳过效果
```

**注意事项：**
- 过滤器按配置顺序执行
- 任意一个过滤器失败，立即停止检查，效果不会应用
- 过滤器不会修改目标，只进行判断

## 过滤器与效果系统集成

过滤器在效果系统的 `apply()` 方法中被调用：

```gdscript
# 在 GameplayEffect.apply() 中
func apply(target: Node, instigator: Node, context: Dictionary = {}) -> void:
    # 1. 检查过滤器（如果被过滤，直接返回）
    if not _check_filters(target, instigator, context):
        return
    
    # 2. 执行具体逻辑（子类实现）
    _apply(target, instigator, context)
    
    # ...
```

## 最佳实践

1. **合理使用过滤器**：通过过滤器控制效果目标，避免在效果逻辑中硬编码判断
2. **利用标签系统**：优先使用标签过滤器，充分利用标签系统的功能
3. **组合多个过滤器**：通过组合多个简单过滤器实现复杂筛选逻辑
4. **自定义过滤器**：对于复杂的筛选逻辑，创建自定义过滤器
5. **性能考虑**：过滤器会在每帧被调用，避免在过滤器中执行耗时操作

## 总结

过滤器系统提供了灵活的目标筛选机制，通过组合不同的过滤器，可以实现各种复杂的目标筛选需求。过滤器系统与标签系统深度集成，可以充分利用标签系统的功能。

