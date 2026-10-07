# 撤销本次应用，不再按配置 ID 猜来源

属性效果以前默认使用同一个 `effect.` 来源。两个独立效果应用后，移除其中一个可能把另一个一起删掉。
现在 `GameplayEffectResult.application` 保存本次可撤销应用的句柄，按实际安装的修改器撤销。

```gdscript
var result: GameplayEffectResult = effect.apply(target, instigator)
if is_instance_valid(result.application):
	result.application.revoke()
```

没有可撤销操作时 application 为 null，例如只有伤害、位移或生成魔法场的效果。
复合效果会组合已经创建的可撤销应用；一部分失败后仍能撤销已经安装的属性修正。
这不会恢复已扣生命、逆转位移或销毁生成对象，也不承诺整个复合操作回滚。

## ID 与所有权

- `application_id`：每次应用的只读运行编号，同一配置、同一目标、同一来源重复应用仍不同。
- `config_id`：GE_AttributeModifier 的旧 source_id 配置字段，保留序列化加载，仅用于识别配置。
- `source_group`：context 的 source_id 标签，供调用方分类；不会用它挑选要撤销的修改器。

属性修改器实际 source_id 为 application_id，句柄保存的是本次安装的修改器对象。
撤销 A 不影响 B；重复 revoke 不再修改数值或重复通知。目标/组件销毁后 revoke 安全完成。
句柄通过弱引用访问组件，不阻止目标释放。编号用于本次运行，不是存档或联网的永久 ID。

结果的 copy 和技能快照共享同一个 application：撤销任一副本里的句柄就是撤销同一次应用。
数值输出和结果树仍是独立快照。保存句柄后再调用 revoke 是显式游戏操作，不能把它当成只读查询。
单个属性应用保留自己的配置标识；包含多个应用的组合句柄不代表某一个配置。

## 状态如何管理

GameplayStatusInstance 保存初次、周期和事件批次返回的可撤销应用。
状态移除时撤销它拥有的句柄，不再重建配置并按来源批量清理。
叠层调用句柄 set_stacks，更新已创建的持续属性修正，不重放伤害、初次逻辑或 Cue。
失败/免疫而未创建句柄的子效果也不会在叠层时突然补执行。

同一状态实例重复 apply / remove 保持幂等，移除后不再接收新的效果批次。
应用或叠层回调中移除状态时，后续返回的可撤销应用会立即清理。
remove_effects 仍执行一次，它新产生的结果可通过 get_last_effect_results 读取，
这些移除时的新应用不属于正在结束的初次/周期应用，不会被一起误删。
瞬时状态仍按一次性效果处理，调用方需要自行保留其返回结果中的可撤销句柄。

状态创建/移除本身还不是可逆事务：GE_ApplyStatus 的 application 只覆盖其初次效果中可撤销的部分，
不会因此删除状态实例。移除状态仍调用组件 remove_status。

## 旧资源与调用迁移

已有 .tres 无须重存，GE_AttributeModifier.source_id 字段继续加载；它的语义改为配置标识。
不能再用空来源、配置 ID 或 context source_id 推定一次应用。
把旧的 `effect.remove(target, instigator)` 改为保留 apply 返回值并调用 application.revoke。
未提供句柄的属性效果 remove 会提示迁移并拒绝猜测，不删除任何修改器。
兼容入口 `effect.remove(target, instigator, {"application": result.application})` 也会精确撤销。

旧的批量查询/移除代码如需定位这次应用，使用 application.application_id。
组件 remove_modifiers_by_source 仍可用于明确的来源管理，但不再作为效果/状态撤销入口。
应用句柄是运行对象，不写回 Resource，也不自动序列化进旧存档。

自定义持续效果应在 _apply_result 中返回继承 GameplayEffectApplication 的运行对象，
实现 _revoke 和必要的 _set_stacks，持有自己的实际运行数据。
状态不再调用模板的 _remove / _update_stacks 去猜需要清理哪次应用；
原有自定义持续效果需要迁移到句柄。StatusFeature 的移除钩子与 remove_effects 配置保留。
不要在配置 Resource 中保存句柄，不要依赖句柄被垃圾回收时自动撤销；直接调用的效果由调用方保留和管理。

## 验证

`tests/run.ps1 -Godot <Godot 4.7 路径> -Cases issue_36,issue_33,issue_43,issue_42`
验证独立与重复应用、幂等撤销、目标销毁、资源隔离、嵌套效果、两个状态实例、
周期/事件批次归属、移除时的新效果，以及应用/叠层回调中撤销。
既有多修正叠层测试继续通过。自定义存档、联网身份与真实游戏的数值表现未测。
