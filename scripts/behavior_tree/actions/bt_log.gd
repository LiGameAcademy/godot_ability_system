extends GAS_BTAction
class_name GAS_BTLog

enum LogLevel {
	INFO,
	WARNING,
	ERROR
}

## [配置] 要打印的文本消息
@export_multiline var message: String = "Marker Reached"
## [配置] (可选) 同时打印黑板中这个 Key 的值
## 例如填 "target"，日志会显示 "Marker Reached | target: Object#123"
@export var blackboard_key: String = ""
## [配置] 日志级别
@export var level: LogLevel = LogLevel.INFO

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	# 1. 组装基础消息：[谁] 说了什么
	var final_msg = "[%s] %s" % [instance.agent.name, message]
	# 2. 如果配置了 Key，尝试从黑板获取值并追加到消息后
	if not blackboard_key.is_empty():
		var value = _get_var(instance, blackboard_key, "<null>")
		final_msg += " | %s: %s" % [blackboard_key, str(value)]
	# 3. 根据级别打印
	match level:
		LogLevel.INFO:
			print(final_msg)
		LogLevel.WARNING:
			# 会在编辑器底部的 Debugger 面板显示为黄色
			push_warning(final_msg)
		LogLevel.ERROR:
			# 会在编辑器底部的 Debugger 面板显示为红色，并可能暂停游戏(取决于设置)
			push_error(final_msg)
	# 日志节点通常是瞬间完成的，所以总是返回 SUCCESS
	return Status.SUCCESS
