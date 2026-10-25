extends GameplayEffect

func _apply(target: Node, _instigator: Node, _context: Dictionary) -> void:
	target.set_meta("applied", int(target.get_meta("applied", 0)) + 1)

func _remove(target: Node, _instigator: Node, _context: Dictionary) -> void:
	target.set_meta("removed", int(target.get_meta("removed", 0)) + 1)
