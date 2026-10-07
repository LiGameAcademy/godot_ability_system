# 标签来源与状态互斥

两个 Buff 都给角色提供 `state.shielded` 时，移除其中一个，另一个提供的标签应该继续存在。标签现在按实体、标签 ID、来源 ID 保存计数，普通移除只释放自己的来源。

```gdscript
var tag_id: StringName = &"state.shielded"
var source_a: StringName = &"shield.a"
var source_b: StringName = &"shield.b"
TagManager.add_tag(actor, tag_id, source_a)
TagManager.add_tag(actor, tag_id, source_b)
TagManager.remove_source(actor, source_a)
assert(TagManager.has_tag(actor, tag_id))
TagManager.remove_source(actor, source_b)
assert(not TagManager.has_tag(actor, tag_id))
```

标签 Resource 需要先注册，例如 `TagManager.initialize(tags)`。相同来源重复添加会累加计数；`remove_tag(actor, id, source)` 减少一次，`remove_source(actor, source)` 释放该来源的全部标签与计数。来源 ID 由调用方保证不与其他拥有者重复。状态实例会自动使用自己的唯一 ID。

不传来源的旧调用仍使用匿名计数。匿名移除不能减少具名来源的计数。移除不存在的标签或来源返回 `false`，也不发送虚假的 `tag_removed`。`tag_added` 和 `tag_removed` 只在实体的实际持有数发生 `0 -> 1` 或 `1 -> 0` 时发送。

## 互斥由谁处理

`TagManager.add_tag/add_tags` 遇到互斥来源会返回 `false`，保留原有标签。互斥关系双向生效，也会考虑父标签的关系；不用两边重复填写排斥配置。缺失父标签、循环父链、未知或与自身祖先冲突的排斥配置不能用于新增标签。

`GameplayStatusComponent` 可以替换**本容器管理的实际状态**。它先检查优先级，再做只读的标签检查；检查时只忽略它准备移除的状态来源。外部手动添加的标签，或另一个状态容器提供的标签，仍然会阻止新增状态。检查通过后，才移除旧状态并创建新实例。较低优先级的互斥状态不能替换较高优先级状态。

状态标签在初次效果之前取得；未能取得时，不执行初次效果。容器退出场景树会移除自己管理的状态，并释放其标签与持续效果应用。直接创建实例或使用空 `status_id` 的持续状态时，调用方仍需负责其生命周期；容器只记录非空 ID 的持续状态。

移除旧状态时，外部回调可能修改其他来源，所以新增前会再检查一次。这不是任意游戏逻辑的回滚事务：第二次检查失败时，已经移除的旧状态不会自动恢复。

## 查询、批量操作和通知

`can_add_tags(actor, ids)` 只读检查，不创建实体运行状态，也不移除互斥标签。`add_tags` 整批校验，再提交计数与组，最后通知；一个无效标签不会导致前面的标签被部分应用。

在标签通知回调中，普通新增、移除或强制清空会被拒绝，请用延迟调用处理。这能避免当前批次发出尚未提交完成或已失效的通知。状态在通知中结束需要释放来源时，`remove_source` 会排队，在当前调用返回前迭代清理；其返回 `true` 表示接受了清理请求，不保证该来源原来存在。

`force_remove_tag` 和 `clear_all_tags` 保留为显式管理操作，会清空指定范围的**所有来源**。调用方负责同步自己的业务状态，不要用它们代替普通 Buff 移除。重置后，旧来源的迟到释放不会扣掉新来源的计数。

## 升级注意事项

- 查询使用实体自身的 `gas_tag_state`，标签组只是供 Godot 组查询使用的镜像。不要直接写组或旧的 `tag_ref_*` metadata 来赋予标签。
- 升级后重新启动运行场景。旧运行实例的 metadata 不会自动迁移。
- 过去依赖“新增互斥标签直接清掉其他来源”的代码，需要检查返回值，或交给状态容器明确移除旧状态。
- 持续状态配置中的标签必须已注册。`GE_ApplyStatus` 会将无效标签配置报告为 `INVALID_CONFIGURATION`；零持续时间的瞬时状态不授予标签。
- `GameplayTagRegistry` 保存只读定义和关系索引，`GameplayTagState` 保存实体运行计数，`TagManager` 提供公共入口。修改定义时先注销再注册，不原地修改已登记的共享 Resource。

## 验证记录

Godot `4.7.stable.mono.official.5b4e0cb0f`，`tests/cases/issue_37.gd` 覆盖具名来源、匿名计数、互斥优先级、跨容器阻挡、批量校验、查询缓存、循环父链、通知中的级联释放以及目标退出清理。旧实现复现了四个失败断言。

完整 31 个回归案例的行为断言通过。退出时仍有基线已有的 3 个 ObjectDB 对象、2 个脚本资源保留提示。按另一种顺序加载这组测试类型时，旧版本和新版本都出现 18 个对象、14 个脚本资源保留；verbose 日志中保留项是 GDScript/GDScriptNativeClass，未看到新增的状态实例或节点保留。该提示仍需在发布验收中继续核对，不代表退出资源检查已全部通过。
