extends Resource
class_name GameplayStatusData

## 状态数据（Buff/Debuff定义）
## 定义状态的所有属性，包括效果、持续时间、叠加策略等

# --- 基础信息 ---
@export var status_id: StringName						## 状态的唯一标识符（如 `&"burn"`、`&"poison"`）
@export var status_display_name: String = ""			## 状态的显示名称（如 "燃烧"、"中毒"）
@export var status_description: String = ""				## 状态的描述文本
## 状态的持续时间
## -1 为永久/切换, 0 为瞬时, >0 为持续时间（单位：秒S）
@export var duration: float = -1.0
## 持续时间策略
@export var duration_policy: StatusDurationPolicy = DurationNaturalTime.new()  
@export var icon: Texture2D								## 状态的图标（用于 UI 显示）
@export var tags: Array[StringName] = []				## 状态的标签列表（用于分类和查询，如 `status.debuff`、`element.fire`）

# --- 效果配置 ---
@export_group("Effects")
## 状态应用时触发的效果（一次性效果）
## 这些效果只在状态被应用时触发一次，不会在层数叠加时重新触发
## 例如：初始伤害、治疗、一次性视觉效果
@export var apply_effects: Array[GameplayEffect] = []
## 状态移除时触发的效果
## 这些效果在状态被移除时触发，用于清理或触发移除时的效果
## 例如：移除属性修改器、移除时的视觉效果
@export var remove_effects: Array[GameplayEffect] = []

@export_group("Features")
## 状态特性列表
## 通过组合不同的 Feature 实现复杂的状态行为
@export var features: Array[StatusFeature] = []
## 默认只响应本角色的事件；需要世界/队伍级广播的状态显式开启。
@export var listen_to_global_events: bool = false

# --- 叠加策略 ---
@export_group("Stacking")
@export var stacking_policy: StatusStackingPolicy = StackingRefreshDuration.new()
@export var max_stacks: int = 1

# --- 状态关系 ---
@export_group("Status Relations")
## 状态优先级（数字越大优先级越高）
## 当新状态与旧状态冲突时，优先级高的状态会替换优先级低的状态
@export var priority: int = 0

# --- 视觉反馈 ---
@export_group("Visual Feedback")
## 游戏提示（Cue），用于逻辑与表现分离
## 当状态应用时，会执行此 Cue 来播放表现（特效、音效等）
## 状态移除时，会自动停止持续 Cue（如附加粒子特效）
@export var cue: GameplayCue = null

## 检查此状态是否可以被指定事件触发
func can_trigger_on_event(event_type: StringName) -> bool:
	for feature: StatusFeature in features:
		if is_instance_valid(feature) and feature.can_trigger_on_event(event_type):
			return true
	return false

func has_event_listening() -> bool:
	for feature: StatusFeature in features:
		if is_instance_valid(feature) and feature.has_event_listening():
			return true
	return false
