# 给事件明确接收者

受击、技能完成和状态移除不应该因为事件名相同，就触发场景中所有角色的 Buff。事件现在包含来源、目标和范围，状态默认只接收自己所属角色的局部事件。

## 常用入口

角色自己的局部事件，可以直接调用它的状态组件：

```gdscript
status_component.trigger_event(&"damage_received", {"damage_info": info}, attacker)
```

这条交付路径不发布到 `AbilityEventBus`，也能在节点尚未进入场景树时运行。也可以自己持有 `GameplayEventDispatcher`，连接它的 `event_delivered` 信号；派发器是普通 RefCounted，不依赖 Autoload。插件其余生命周期、技能和伤害事件仍保留项目总线入口，并非整个插件已取消 Autoload。

需要让项目中的观察者一起收到时，明确指定目标：

```gdscript
AbilityEventBus.trigger_local_event(&"damage_received", defender, {"damage_info": info}, attacker)
```

`source` 是制造事件的角色，`target` 是接收角色，两者可以不同。B 接收 A 制造的事件，并不代表 A 也接收同名事件。

世界级事件显式广播：

```gdscript
AbilityEventBus.trigger_global_event(&"round_ended", {"round": 3})
```

需要响应广播的状态配置开启 `GameplayStatusData.listen_to_global_events`；默认关闭。开启后仍能接收本角色的局部事件。事件名继续由 `FeatureEventListener.trigger_on_events` 匹配，不需要重写原来的效果配置。队伍或多个指定角色的通知，可由游戏逻辑明确选择目标后逐个发送局部事件；本次没有加入队伍系统。

`GameplayStatusComponent.receive_bus_events` 默认开启，进入场景树时连接总线。只想由自己转发事件的角色，可在进入树前关闭此配置，再调用 `trigger_event`；内置 HealthVital 的项目通知不会自动交付给关闭订阅的组件。

## 数据与处理时序

`GameplayEvent` 构造时保存字典及嵌套数组/字典快照，路由通过 getter 读取。`get_context()` 每次返回独立字典，自动加入 `source`、`target`、`scope`；局部事件中的兼容字段 `entity` 指向接收目标。不要修改事件的私有字段。

每个状态、Feature 和持续时间策略得到独立输入，不会把自己的 `stacks`、`source_id` 或嵌套字典修改写回给其他接收者。节点、Resource、RefCounted 对象载荷仍保留身份，不隐式复制游戏对象。特别是 `GameplayDamageInfo` 是一次伤害的运行对象，受击前效果仍可同步修改它的 `final_damage`。只读配置 Resource 的约定继续适用。

交付保持同步。`HealthVital.damage_received` 及对应状态事件处理完后才扣血；实际伤害完成后再发 `damage_applied`。伤害通知明确携带受击角色和施加者。若接收角色在受击前处理里退出，尚未提交的伤害停止；已经提交的伤害不会因后续通知而回滚。

同一容器接收事件前固定实例快照，新建状态从下一次事件开始接收。处理过程中移除或替换状态时，旧实例不会继续调用后面的 Feature，也不会误删同 ID 的新实例。

## 循环和诊断

所有同步嵌套交付共用当前链的预算，包括从局部入口转到总线、再转回其他局部入口的链。每条链最多接受 64 次派发，嵌套深度最多 16；新根事件重新计数。预算限制的是同步链，跨帧、延迟调用及线程调度不属于同一链。本接口用于 Godot 主线程。

循环或超预算时，后续派发返回 `false`，该链只报告一次 `chain_budget_exceeded`。`event_rejected` 的诊断包含 `chain_id`、`root_event`、当前 `event_id`、来源/目标实例 ID、深度和已交付数量。诊断回调不能再次制造事件，避免错误处理本身递归。预算终止不会撤销此前已经应用的效果。

`dispatch` / `send_event` / `trigger_event` 的 `true` 仅表示接受派发，不表示存在监听者，也不表示某个效果成功。效果结果仍按[效果结果契约](effect_results.md)读取。

## 旧接口迁移

`trigger_game_event(event_id, context)` 保留：默认局部，目标从 `target` 或旧字段 `entity` 取得；来源优先 `source`，其次 `instigator`，否则使用目标。`scope` 支持 `local/global` 字符串、StringName 或 `GameplayEvent.Scope`。非字典、未知范围或错误来源类型被拒绝；局部事件缺少有效目标也被拒绝，不再隐式广播。

旧的 `game_event_occurred(event_id, context)` 信号保留给项目级观察者。状态组件改用带类型的 `gameplay_event_occurred(event)`，每个接收者取自己的快照。旧字典信号的订阅者共用该次观察用字典，请按只读方式使用；需要独立数据时改用带类型接口。

原来用无目标事件触发所有角色状态的代码，改用 `trigger_global_event`，并在相应状态上开启广播监听。直接调用 `GameplayStatusComponent.handle_event` 仍表示向这个组件发送局部事件，内部也经过链预算。

## 验证

Godot `4.7.stable.mono.official.5b4e0cb0f`。旧版本复现了 A 的事件触发 B；新的 `issue_45` 覆盖局部/跨实体/显式全局路由、旧 scope 输入、快照与 Feature 隔离、同步伤害调整、事件中替换和释放角色、局部与总线混合循环及总数限制。

完整 32 个回归案例的行为断言通过，没有脚本/解析或信号发出者失效错误。退出仍有既有的 3 个 ObjectDB、2 个脚本资源保留提示，资源释放验收还未结束。
