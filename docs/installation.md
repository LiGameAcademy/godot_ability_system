# 安装与独立示例

将插件完整放入项目的 `addons` 目录，随后在项目设置中启用插件。
目录可以自行命名；自动加载、UI 场景、材质和示例都按插件自身位置引用文件。
运行示例前先启用插件，让五个自动加载服务可用。

`examples` 中四个场景分别演示属性修改、Vital 消耗和上限变化、伤害与治疗、状态叠层。
它们使用插件内的配置 Resource，不需要课程项目的 PlayerData、天赋类或技能数据。
属性、Vital 和效果参数可以在场景检查器中替换。示例输出完成提示并执行断言，
属于规则演示，没有角色控制、美术演出或课程项目的体质换算、伤害公式。

默认主题使用引擎字体；技能和状态控件不再依赖宿主项目的 icon.svg。
自己的技能图标、字体和主题仍可通过原有资源和控件属性配置。

## 天赋效果修改器

EffectModifierFeature 不再直接引用业务类 TalentEffectModifier。
项目的修改器需要继承 `AbilityEffectModifier`，实现两个已有语义的钩子：

```gdscript
extends AbilityEffectModifier
class_name ExampleDamageModifier

@export var ability_id: StringName = &"fireball"
@export var multiplier: float = 1.5

func affects_ability(id: StringName) -> bool:
    return id == ability_id

func apply_to_context(context: Dictionary) -> void:
    context["damage_multiplier"] = multiplier
```

把修改器放入 Feature 的 `effect_modifiers`。配置保持只读，只修改当前激活的 context。
旧业务类若已有其他基类，可以在业务层用一个薄适配器实现这两个钩子。
原 `effect_modifer_feature.gd` 的文件名和 EffectModifierFeature 类名保留，避免破坏已有路径引用。

## 可选调试绘制

MeleeBoxHitDetector 不依赖 DebugDraw。启用 `debug_draw_enabled` 后，
它发出 `debug_box_requested(bounds, color, linger_frames)`；表现层按需订阅绘制。
未连接信号时只执行检测，既不查找第三方单例，也不阻塞目标查询。
迁移旧项目时，将这个信号连接到自己的绘制回调，再由回调调用所用插件的 API。

物理检测的施法者仍使用 Node3D，这是具体的 3D 策略。
Godot 4 的排除列表使用 RID；检测结果也会排除施法者的子碰撞对象，
同一实体的多个碰撞节点只返回一个目标。沿用现有约定：碰撞节点的父级是实体目标。

## 验证

在 PowerShell 运行 `tests/run.ps1 -Godot <Godot 4.7 可执行文件路径>`。
完整导入会把全部脚本、场景和资源复制到生成的独立安装工程，并启用真实插件；
`-Cases issue_1` 只运行独立导入相关案例，`-SkipImport` 复用已导入的类索引。
规则和资源加载验证通过不代表所有视口、字体语言覆盖或材质视觉效果都已验收。
