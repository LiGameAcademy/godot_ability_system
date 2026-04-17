@abstract
extends Resource
class_name TargetingStrategy

## 目标获取策略基类（抽象类）
## 使用策略模式，将目标获取逻辑从技能数据中解耦
##
## 核心思想：
## - 框架层只定义接口，不限制具体实现
## - 业务层可以实现任意复杂的目标获取策略
## - 支持组合和扩展，符合"开闭原则"

## 目标筛选器列表
## 如果配置了筛选器，只有通过所有筛选器的目标才会被返回
## 例如：可以筛选出只有"敌人"标签的目标，或只有"友军"标签的目标
@export var filters: Array[GameplayFilterData] = []

## 目标排序器 (可选)
## 如果配置了排序器，将在所有筛选器通过后，对剩余的目标进行排序
@export var sorter: TargetSorter = null

## 目标选取器 (可选)
## 用于对排序后的目标进行最终裁切 (如取前 N 个、随机取 N 个等)
## 如果未配置，则保留所有目标
@export var picker: TargetPicker = null

## 解析目标（带筛选）
## [param] instigator: Node 施法者
## [param] input_target: Node 输入目标（可能为 null，由策略决定是否使用）
## [param] context: Dictionary 上下文信息，可能包含：
##   - "target_position": Vector3 目标位置（用于地面目标）
##   - "target_unit": Node 锁定目标（用于单位目标）
##   - "facing_angle": float 面朝角度（弧度）
##   - "facing_direction": Vector3 面朝方向向量
##   - "hit_detector": HitDetectorBase 命中检测器（如果技能配置了）
## [return] Array[Node] 解析出的目标列表（已通过筛选器过滤）
func resolve_targets(instigator: Node, input_target: Node, context: Dictionary = {}) -> Array[Node]:
	# 1. 获取原始目标列表
	var raw_targets = _resolve_targets(instigator, input_target, context)

	# 2. 应用筛选器
	var filtered_targets: Array[Node] = []
	if filters.is_empty():
		filtered_targets = raw_targets
	else:
		for target in raw_targets:
			if not is_instance_valid(target):
				continue

			# 检查是否通过所有筛选器
			var passed = true
			for filter in filters:
				if not is_instance_valid(filter):
					continue
				if not filter.check(target, instigator, context):
					passed = false
					break

			if passed:
				filtered_targets.append(target)
	
	# 3. 应用排序器
	if sorter and not filtered_targets.is_empty():
		# 先预处理
		sorter.prepare(filtered_targets, context)
		# 再执行排序
		filtered_targets.sort_custom(func(a, b): return sorter.compare(a, b, context))
		
	# 4. 应用选取器
	if picker and not filtered_targets.is_empty():
		filtered_targets = picker.pick(filtered_targets, context)
		
	return filtered_targets
	
## [子类必须重写] 解析目标的具体实现
@abstract func _resolve_targets(instigator: Node, input_target: Node, context: Dictionary) -> Array[Node]
