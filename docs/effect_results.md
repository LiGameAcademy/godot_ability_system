# 效果是否生效，从返回结果读取

`GameplayEffect.apply(target, instigator, context)` 现在返回 `GameplayEffectResult`。
调用方可以区分实际生效、免疫或过滤、缺组件、配置错误，以及旧效果暂时无法确认的结果。
结果与 BT 三态无关；直接调用效果也能使用。

## 返回内容

| 状态 | 含义 |
| --- | --- |
| APPLIED | 当前操作及其子操作都报告生效 |
| NOT_APPLIED | 没有发生操作，例如免疫、过滤、满血治疗、没有可驱散的状态 |
| FAILED | 没有报告生效，且发生目标、依赖或配置错误 |
| PARTIAL | 一部分已经生效，其余未生效、失败或无法确认 |
| UNVERIFIED | 没有已确认的生效结果，存在只返回 void 的旧效果 |

`reason` 解释原因；`children` 保留复合操作的各项结果。
`did_apply()` 对 APPLIED / PARTIAL 返回 true；`has_failure()` 同时检查子结果中的错误。
PARTIAL 不等于没有错误，UNVERIFIED 不等于没有副作用。

`target_id` 是应用前取得的实例编号，目标销毁后仍能用于诊断；不能把它当成永久角色 ID。
`effect_path` 优先使用资源路径，运行副本没有资源路径时使用脚本路径。
`outputs` 由效果定义，例如伤害的 `final_damage`、Vital 的实际 `delta` / `remaining`、
驱散的 `removed_count`、属性修正的 `modifier_count`、状态的 `status_id` / `stacks`、
魔法场的 `spawned_node_id` / `position` 和位移的实际 `delta`。

输出描述本次调用，不保证对象在下一帧仍存在。保存对象 ID 后，使用前仍要检查实例有效性。
返回结果按只读约定使用；`copy()` 复制结果树和数值容器，但不会复制容器里引用的任意 Object。

## 主效果、Cue 与子效果

先检查目标、Filter 和标签要求，再执行主效果。
主效果报告 APPLIED / PARTIAL 时播放它自己的 Cue，然后按资源顺序执行子效果。
主效果未生效、失败或无法确认时，不播放成功 Cue，也不执行子效果。
子效果失败不会否定已经发生的主效果，也不会自动撤销已经播放的 Cue。

`child_failure_policy` 默认 STOP_ON_FAILURE：遇到目标、配置或依赖错误后停止后续子效果。
CONTINUE 会继续后续操作并保留错误；免疫、过滤和 NO_CHANGE 属于未生效，不触发停止。
配置循环和超过 64 层的应用链会返回配置错误，避免无限递归；这项限制只约束 apply。

每个子效果接收独立字典，以及主效果的输出。兄弟子效果之间不隐式传递字典修改。
`GameplayDamageInfo` 等显式运行对象仍按引用传递，便于伤害管线修改同一份运行数据。
配置 Resource 保持只读；不可把临时次数、方向或上一次结果写回配置。

## BT 节点如何决定继续

`AbilityNodeApplyEffect.success_policy` 可以选择：

| 策略 | 返回 BT SUCCESS 的条件 |
| --- | --- |
| ANY_APPLIED（默认） | 至少一个操作确认生效，允许部分成功 |
| ALL_APPLIED | 所有目标及效果都报告 APPLIED |
| ALLOW_NOT_APPLIED | APPLIED / PARTIAL / NOT_APPLIED 均可继续；FAILED / UNVERIFIED 失败 |

`stop_on_failure` 默认 true，遇到硬错误停止剩余目标/效果；设为 false 会继续收集结果。
已经生效后再失败，ANY_APPLIED 可以让流程完成，但错误仍保存在执行结果中。
如果游戏要求每项都成功，使用 ALL_APPLIED。
空目标返回 NO_TARGET；空效果配置或错误的黑板效果值返回 INVALID_CONFIGURATION。

目标以黑板中 `target_key` 的最新值为准；键不存在才读取 context。
列表会去重、跳过无效或非 Node 元素，不修改传入数组。
只有显式打开 `use_instigator_as_fallback` 才在空目标时改为自施法。

`AbilityResult.effects` 按实际调用保存各目标的结果快照，BT reset 或下一轮激活不清除上一轮记录。
执行失败时可以区分 NO_TARGET、IMMUNE、FILTERED、EFFECT_FAILED 和 UNVERIFIED_EFFECT。
流程完成时 `failure_reason` 为 NONE，效果事实仍保留；COMPLETED 不代表命中。

## 自定义效果迁移

旧的 `_apply(...) -> void` 仍会执行，但返回 UNVERIFIED / LEGACY_UNVERIFIED，
默认 BT 策略不会据此认定成功，基类也不会继续 Cue / 子效果。
已有自定义效果需要实现 `_apply_result`，明确返回实际结果。可以只实现这个新钩子：

```gdscript
extends GameplayEffect
class_name RestoreHealthEffect

@export var amount: float = 20.0

func _apply_result(target: Node, instigator: Node, context: Dictionary) -> GameplayEffectResult:
	var effect: GE_ModifyVital = GE_ModifyVital.new()
	effect.vital_id = &"health"
	effect.amount = amount
	return effect.apply(target, instigator, context)
```

调用方可以忽略新增返回值，但不能继续依赖“void 返回即成功”的判断。
新代码从结果读取输出；已发布的单目标 `context["final_damage"]` 输出由内置伤害效果继续提供。
其他字典修改不会写回调用方。旧自定义效果如需输出 final_damage，应放入返回结果的 outputs。
多目标请读取各目标结果，避免共用一个 final_damage 覆盖前一个目标。
自定义过滤扩展使用 filters 中的 GameplayFilterData；旧 `_check_filters` 覆盖不再控制 apply。
旧 `_apply_sub_effects` / `_remove_sub_effects` 内部钩子已移除，组合配置使用 sub_effects。

`GameplayStatusInstance.apply_effects()` 返回本批次结果快照，`get_last_effect_results()` 读取最近批次。
GE_ApplyStatus 同时报告状态创建和初次效果的结果；创建了状态但其效果失败时返回 PARTIAL。
重复状态被优先级拒绝是 FILTERED，堆叠/刷新没有实际变化是 NO_CHANGE。
堆叠撤销与重建的应用归属继续在 #36 处理，本次不改变旧 source_id 批量移除规则。

位移效果每次从目标和 context 计算方向，不在共享 Resource 中缓存上一次方向。
需要锁定方向时，在技能实例的 context 中保存固定 `direction`（CUSTOM）或 `facing_angle`（FORWARD）。
生成魔法场可显式传 `spawn_parent`；未传时仍尝试施法者当前场景。

本次结果契约不承诺复合效果的整体回滚。独立的持续效果应用句柄和只撤销本次应用的能力由 #36 实现。

## 验证

`tests/run.ps1 -Godot <Godot 4.7 路径> -Cases issue_43` 覆盖失败时 Cue/子效果不执行、
免疫与过滤、顺序和停止策略、循环配置、多目标去重、空目标、部分成功、执行快照隔离、
目标销毁、九种内置效果的成功或失败输出，以及 A/B 位移方向隔离。
未验证联网同步、真实游戏的命中表现或复杂碰撞场景。
