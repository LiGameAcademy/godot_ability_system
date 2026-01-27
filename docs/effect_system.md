# 效果系统指南

## 概述

效果系统（Effect System）是游戏逻辑的执行单元，负责实现各种游戏效果，如伤害、治疗、属性修改、状态应用等。

## 核心概念

### 游戏效果（Gameplay Effect）

游戏效果是效果系统的基本单元，所有效果都继承自 `GameplayEffect`。

**效果类型：**
- [伤害效果（GEApplyDamage）](../scripts/effects/ge_apply_damage.gd)
- [治疗效果（GEModifyVital）](../scripts/effects/ge_modify_vital.gd)
- [属性修改效果（GEAttributeModifier）](../scripts/effects/ge_attribute_modifier.gd)
- [状态应用效果（GEApplyStatus）](../scripts/effects/ge_apply_status.gd)
- [状态移除效果（GEDispelStatus）](../scripts/effects/ge_dispel_status.gd)
- [状态转换效果（GEStatusTransform）](../scripts/effects/ge_status_transform.gd)
- [魔法场生成（GESpawnMagicField）](../scripts/effects/ge_spawn_magic_field.gd)
- [投射物生成（GESpawnProjectile）](../scripts/effects/ge_spawn_projectile.gd)
- [单帧位移（GESingleFrameMotion）](../scripts/effects/ge_single_frame_motion.gd)
- [修改受击伤害（GEModifyIncomingDamage）](../scripts/effects/ge_modify_incoming_damage.gd)

## 内置效果

### 1. 伤害效果（GEApplyDamage）

对目标造成伤害。

**属性：**
- `damage_amount`: 伤害数值
- `damage_type`: 伤害类型
- `can_crit`: 是否可以暴击
- `crit_multiplier`: 暴击倍率

**使用：**
```gdscript
var damage_effect = GEApplyDamage.new()
damage_effect.damage_amount = 100.0
damage_effect.damage_type = &"physical"
damage_effect.can_crit = true
damage_effect.crit_multiplier = 2.0
```

### 2. 治疗效果（GEModifyVital）

修改目标的资源值（生命值、魔法值等）。

**属性：**
- `vital_id`: 资源ID
- `modify_type`: 修改类型（ADD、SET、PERCENTAGE）
- `value`: 修改数值

**使用：**
```gdscript
var heal_effect = GEModifyVital.new()
heal_effect.vital_id = &"health"
heal_effect.modify_type = GEModifyVital.ModifyType.ADD
heal_effect.value = 50.0  # 恢复 50 点生命值
```

### 3. 属性修改效果（GEAttributeModifier）

修改目标的属性值。

**属性：**
- `attribute_id`: 属性ID
- `modifier_type`: 修改器类型（ADD、MULTIPLY、OVERRIDE）
- `value`: 修改数值
- `duration`: 持续时间（-1 为永久）

**使用：**
```gdscript
var attribute_effect = GEAttributeModifier.new()
attribute_effect.attribute_id = &"attack"
attribute_effect.modifier_type = GameplayAttributeModifier.ModifierType.ADD
attribute_effect.value = 20.0
attribute_effect.duration = 10.0  # 持续 10 秒
```

### 4. 状态应用效果（GEApplyStatus）

对目标应用状态（Buff/Debuff）。

**属性：**
- `status_data`: 状态数据
- `duration`: 持续时间（覆盖状态数据的默认持续时间）
- `stacks`: 叠加层数

**使用：**
```gdscript
var status_effect = GEApplyStatus.new()
status_effect.status_data = burn_status_data
status_effect.duration = 15.0  # 覆盖默认持续时间
status_effect.stacks = 1
```

### 5. 状态移除效果（GEDispelStatus）

移除目标的状态。

**属性：**
- `status_id`: 要移除的状态ID（为空则移除所有状态）
- `tags`: 要移除的状态标签
- `remove_all`: 是否移除所有状态

**使用：**
```gdscript
var dispel_effect = GEDispelStatus.new()
dispel_effect.status_id = &"burn"  # 移除燃烧状态

# 或移除特定标签的状态
dispel_effect.tags = [&"debuff"]  # 移除所有 Debuff
```

### 6. 状态转换效果（GEStatusTransform）

将一个状态转换为另一个状态。

**属性：**
- `from_status_id`: 源状态ID
- `to_status_data`: 目标状态数据
- `preserve_duration`: 是否保留持续时间
- `preserve_stacks`: 是否保留层数

**使用：**
```gdscript
var transform_effect = GEStatusTransform.new()
transform_effect.from_status_id = &"wet"
transform_effect.to_status_data = freeze_status_data
transform_effect.preserve_duration = true
```

### 7. 魔法场生成效果（GESpawnMagicField）

在指定位置生成魔法场。

**属性：**
- `magic_field_data`: 魔法场数据
- `spawn_position`: 生成位置
- `duration`: 持续时间

**使用：**
```gdscript
var field_effect = GESpawnMagicField.new()
field_effect.magic_field_data = fire_field_data
field_effect.spawn_position = Vector3(0, 0, 0)
field_effect.duration = 30.0
```

### 8. 投射物生成效果（GESpawnProjectile）

生成投射物。

**属性：**
- `projectile_data`: 投射物数据
- `spawn_position`: 生成位置
- `direction`: 发射方向
- `speed`: 发射速度

**使用：**
```gdscript
var projectile_effect = GESpawnProjectile.new()
projectile_effect.projectile_data = fireball_projectile_data
projectile_effect.spawn_position = spawn_point.global_position
projectile_effect.direction = (target_position - spawn_point.global_position).normalized()
projectile_effect.speed = 10.0
```

### 9. 单帧位移效果（GESingleFrameMotion）

瞬间移动目标到指定位置。

**属性：**
- `target_position`: 目标位置
- `relative`: 是否相对位置

**使用：**
```gdscript
var motion_effect = GESingleFrameMotion.new()
motion_effect.target_position = Vector3(10, 0, 0)
motion_effect.relative = false
```

## 应用效果

### 在技能中应用效果

效果可以通过技能的行为树节点应用：

```gdscript
# 在行为树中使用 ApplyEffect 节点
var apply_effect_node = AbilityNodeApplyEffect.new()
apply_effect_node.effects = [damage_effect]
```

### 在状态中应用效果

状态可以包含应用时和移除时的效果：

```gdscript
# 状态应用时的效果
status_data.apply_effects.append(damage_effect)

# 状态移除时的效果
status_data.remove_effects.append(heal_effect)
```

### 直接应用效果

效果可以直接应用到目标：

```gdscript
# 应用效果
damage_effect.apply_effect(target, {
    "source": self,
    "damage_multiplier": 1.5
})

# 应用效果列表
for effect in effects:
    effect.apply_effect(target, context)
```

## 效果上下文（Context）

效果可以接收上下文数据，用于传递额外信息：

```gdscript
var context = {
    "source": caster,  # 施法者
    "target": target,  # 目标
    "damage_multiplier": 1.5,  # 伤害倍率
    "position": Vector3(0, 0, 0),  # 位置
    "direction": Vector3(1, 0, 0)  # 方向
}

effect.apply_effect(target, context)
```

## 自定义效果

### 创建自定义效果

继承 `GameplayEffect` 创建自定义效果：

```gdscript
extends GameplayEffect
class_name CustomEffect

@export var custom_value: float = 0.0

func apply_effect(target: Node, context: Dictionary) -> void:
    # 自定义效果逻辑
    if target.has_method("custom_effect_handler"):
        target.custom_effect_handler(custom_value, context)
```

### 效果链

效果可以组合成效果链：

```gdscript
# 创建效果链
var effect_chain = [
    damage_effect,
    status_effect,
    attribute_effect
]

# 依次应用
for effect in effect_chain:
    effect.apply_effect(target, context)
```

## 效果过滤

效果可以应用`过滤器`，只对符合条件的目标生效：

```gdscript
# 创建过滤器
var filter = FilterTargetByTags.new()
filter.required_tags = [&"enemy"]
filter.blocked_tags = [&"boss"]

# 在效果中使用（支持多个过滤器）
effect.filters.append(filter)
```

**过滤器系统：**
- 所有过滤器继承自 [`GameplayFilterData`](../scripts/filters/gameplay_filter.gd)
- 效果可以配置多个过滤器，所有过滤器都通过时效果才会生效
- 过滤器在效果应用前进行检查，如果过滤失败，效果不会应用

> **注意**：过滤器系统的详细文档请参考 [过滤器系统文档](filter_system.md)

## 效果与伤害系统集成

伤害效果使用伤害计算器进行计算：

```gdscript
# 伤害计算
var damage_info = DamageInfo.new()
damage_info.base_damage = 100.0
damage_info.damage_type = &"physical"
damage_info.source = caster
damage_info.target = target

var final_damage = DamageCalculator.calculate_damage(damage_info)
```

## 最佳实践

1. **使用效果组合**：通过组合多个效果实现复杂逻辑
2. **利用效果上下文**：通过上下文传递额外信息
3. **使用效果过滤器**：通过过滤器控制效果目标
4. **效果与状态分离**：效果负责逻辑，状态负责管理
5. **缓存效果实例**：频繁使用的效果可以缓存

## 总结

效果系统提供了丰富的游戏效果实现，支持伤害、治疗、属性修改、状态应用等功能。通过组合不同的效果，可以实现复杂的游戏逻辑。
