# 查询、输入与技能执行结果

以前 try_activate 返回 true，既可能是启动了技能，也可能只是收到了连击输入。
现在可以用 try_activate_result 区分两种情况。旧 bool 接口和 BT 的三态仍保留。

## 三类调用

| 调用 | 返回内容 | 是否执行 |
| --- | --- | --- |
| check_activation(context) | READY 或 REJECTED，附失败原因和阻止请求的 Feature 注册名 | 只读查询，不开始执行、不改提交记录 |
| try_activate_result(context) | STARTED、INPUT_RECEIVED 或 REJECTED | 接收输入；STARTED 表示启动新一轮，INPUT_RECEIVED 属于已有一轮 |
| get_execution_result() | 当前一轮的 RUNNING、FINISHING 或终结状态，以及提交记录 | 返回快照，不改变执行 |
| get_last_execution_result() | 最近结束的一轮快照；尚未执行过时为 IDLE | 新一轮激活不会清除旧快照 |

READY 不是成功施法，is_accepted() 仅对 STARTED、INPUT_RECEIVED 返回 true。
旧 try_activate() 继续按 is_accepted 返回 bool；can_activate() 继续按 READY 返回 bool。
正在执行时，即使 Feature 阻止再次激活，输入仍按原有连击/开关语义送到当前执行。
查询与执行都在初始化、提交和收尾期间返回 BUSY。

execution_id 在每次成功启动新一轮时递增；输入请求沿用当前编号，拒绝请求不会占用新编号。
STARTED 只说明启动发生了；on_activate 回调可能立即取消或结束，要查终结结果判断后续情况。

## 执行与终结

未执行是 IDLE，执行中是 RUNNING；取消等操作可能需要等 tick 或提交通知结束，期间为 FINISHING。
收尾后区分 COMPLETED、FAILED、CANCELLED、FORGOTTEN、OWNER_EXIT。
COMPLETED 目前仅表示流程正常结束，不能据此认定命中、造成伤害或突破免疫。

终结前会保存费用与冷却的阶段名称，之后 BT reset 不影响记录。
新一轮清空本轮记录，但 get_last_execution_result 仍能读取上一轮的独立快照。
免费或 skip_cost 阶段也会进入 costs；它不是金额清单，更不代表产生了效果。

ability_finished(result: AbilityResult) 是技能实例上的局部信号，携带已结束那一轮的快照。
它在旧 ability_completed(bool) 之后发出。旧回调可能已经开始新一轮，处理详细事件时请使用
result.execution_id 和 result 中的记录，不要从当前执行的 getter 推定事件属于哪一轮。
返回对象和信号载荷按只读约定使用；修改返回快照不影响实例的权威状态。

## 当前能解释的失败

DISABLED、DISPOSED、BUSY、INVALID_CONFIGURATION 用于实例状态和执行入口限制。
资格查询失败时，内置费用为 COST，冷却为 COOLDOWN；其他 Feature 为 FEATURE_BLOCKED，
feature_name 使用实际注册键。现有自定义 Feature 仍返回 bool，本阶段不会猜测它的业务原因。

提交失败会记录 COST、COOLDOWN 或 INVALID_CONFIGURATION，供执行终结时读取；
如前摇后魔力不足，最终是 FAILED / COST，费用和冷却记录都为空。
BT 只报告失败而没有已知业务原因时，返回 FAILED / EXECUTION_FAILED。
NOT_ACTIVE、DISPOSED、BUSY 等被拒绝的提交请求不会覆盖一轮执行的业务失败原因。

失败的提交尝试并不自动结束技能，BT 仍决定是否走 fallback。
下一次成功提交会清除这次提交的失败诊断；fallback 正常完成时也不把先前失败当作终结失败。
已提交的费用/冷却记录始终保留，取消或 fallback 不会自动退款、撤销冷却。

## 效果事实与流程结果

effects 保存本轮各目标的 GameplayEffectResult 快照，包含实际生效、免疫、过滤、
空目标、依赖或配置错误及数值输出。复合效果保留子结果，部分成功不自动回滚。
执行失败时 failure_reason 可为 NO_TARGET、IMMUNE、FILTERED、EFFECT_FAILED 或 UNVERIFIED_EFFECT。
正常完成仍为 COMPLETED / NONE；例如显式允许空目标的技能可以完成，但 effects 中保留 NO_TARGET。
BT 节点按声明的成功与停止策略消费这些结果，详见[效果结果说明](effect_results.md)。

组件转发、事件作用范围与分类在 #45 继续处理。

## 验证

使用 tests/run.ps1 -Godot <Godot 4.7 路径> -Cases issue_40。
案例覆盖只读资格、拒绝原因、新执行与已有输入、前摇后费用失败、恢复分支、BT reset、
提交快照、取消/遗忘/角色退出、完成回调重启、通知中重入和延迟收尾。
相关生命周期与费用案例继续验证原接口和模板语义；没有验证联网或实际游戏的命中表现。
