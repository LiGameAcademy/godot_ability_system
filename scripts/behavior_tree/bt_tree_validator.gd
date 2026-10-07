extends RefCounted
class_name GAS_BTTreeValidator

## 只读遍历资源图，不执行节点，不改变节点或黑板。
static func get_warnings(root: GAS_BTNode) -> PackedStringArray:
	var warnings: PackedStringArray = []
	_visit(root, "root", false, {}, warnings)
	return warnings

static func _visit(node: GAS_BTNode, path: String, reactive: bool, ancestors: Dictionary[int, bool], warnings: PackedStringArray) -> void:
	if not is_instance_valid(node):
		warnings.append("%s: missing node" % path)
		return
	var identity: int = node.get_instance_id()
	if ancestors.has(identity):
		warnings.append("%s: cyclic node reference" % path)
		return
	var label: String = String(node.node_id)
	if label.is_empty():
		var script: Script = node.get_script() as Script
		label = script.resource_path.get_file().get_basename() if is_instance_valid(script) else node.get_class()
	path += "/" + label
	ancestors[identity] = true
	reactive = reactive or node is GAS_BTDynamicSequence or node is GAS_BTDynamicSelector
	if node is GAS_BTComposite:
		var composite: GAS_BTComposite = node as GAS_BTComposite
		for index: int in range(composite.children.size()):
			_visit(composite.children[index], "%s.children[%d]" % [path, index], reactive, ancestors, warnings)
	elif node is GAS_BTDecorator:
		_visit((node as GAS_BTDecorator).child, path + ".child", reactive, ancestors, warnings)
	elif reactive:
		match node.get_reevaluation_safety():
			GAS_BTNode.ReevaluationSafety.SIDE_EFFECTS:
				warnings.append("%s: dynamic reevaluation can repeat side effects; move the action into a memory Sequence or an explicit periodic flow" % path)
			GAS_BTNode.ReevaluationSafety.UNKNOWN:
				warnings.append("%s: dynamic reevaluation safety is unknown; declare get_reevaluation_safety() before using this action here" % path)
	ancestors.erase(identity)
