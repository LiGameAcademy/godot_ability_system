extends AbilityNodeBase
class_name AbilityNodeApplyEffect

enum SuccessPolicy { ANY_APPLIED, ALL_APPLIED, ALLOW_NOT_APPLIED }
@export var effects: Array[GameplayEffect] = []
@export var effect_key: String = ""
@export var use_instigator_as_fallback: bool = false
## 部分生效默认继续；未生效可显式允许；配置/依赖错误不会被 ALLOW_NOT_APPLIED 吞掉。
@export var success_policy: SuccessPolicy = SuccessPolicy.ANY_APPLIED
@export var stop_on_failure: bool = true

func _tick(instance: GAS_BTInstance, _delta: float) -> int:
	var context: Dictionary = _get_context(instance)
	var source: Variant = context.get("instigator")
	var instigator: Node = source as Node if source is Node and is_instance_valid(source) else null
	var ability: GameplayAbilityInstance = _get_var(instance, "ability_instance") as GameplayAbilityInstance
	var targets: Array[Node] = _get_target_list(instance, use_instigator_as_fallback)
	var selected: Array[GameplayEffect] = _resolve_effects(instance)
	var results: Array[GameplayEffectResult] = []
	if targets.is_empty():
		results.append(GameplayEffectResult.new(GameplayEffectResult.Status.NOT_APPLIED, GameplayEffectResult.Reason.NO_TARGET))
	elif selected.is_empty():
		results.append(GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION))
	else:
		for target: Node in targets:
			for effect: GameplayEffect in selected:
				var result: GameplayEffectResult
				if not is_instance_valid(effect):
					result = GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_CONFIGURATION)
				elif not is_instance_valid(target):
					result = GameplayEffectResult.new(GameplayEffectResult.Status.FAILED, GameplayEffectResult.Reason.INVALID_TARGET)
				else:
					var runtime: GameplayEffect = effect.duplicate(false) as GameplayEffect
					result = runtime.apply(target, instigator if is_instance_valid(instigator) else null, context.duplicate(true))
				results.append(result)
				if is_instance_valid(ability):
					ability.record_effect_result(result)
					if not ability.is_active:
						return Status.FAILURE
				if stop_on_failure and result.has_failure():
					return _consume(GameplayEffectResult.aggregate(results), ability)
	if is_instance_valid(ability) and (targets.is_empty() or selected.is_empty()):
		ability.record_effect_result(results[0])
	return _consume(GameplayEffectResult.aggregate(results), ability)

func _consume(result: GameplayEffectResult, ability: GameplayAbilityInstance) -> int:
	if is_instance_valid(ability):
		ability.record_effect_outcome(result)
	if success_policy == SuccessPolicy.ALL_APPLIED:
		return Status.SUCCESS if result.status == GameplayEffectResult.Status.APPLIED else Status.FAILURE
	if result.did_apply():
		return Status.SUCCESS
	if success_policy == SuccessPolicy.ALLOW_NOT_APPLIED and result.status == GameplayEffectResult.Status.NOT_APPLIED:
		return Status.SUCCESS
	return Status.FAILURE

func _resolve_effects(instance: GAS_BTInstance) -> Array[GameplayEffect]:
	if effect_key.is_empty():
		return effects
	var raw: Variant = _get_var(instance, effect_key)
	if raw is GameplayEffect:
		return [raw as GameplayEffect]
	var selected: Array[GameplayEffect] = []
	if raw is Array:
		for item: Variant in raw:
			selected.append(item as GameplayEffect if item is GameplayEffect else null)
	return selected
