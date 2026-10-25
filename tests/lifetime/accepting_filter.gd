extends GameplayFilterData

@export var allowed: bool = true

func _check(_target: Node, _instigator: Node, _context: Dictionary) -> bool:
	return allowed
