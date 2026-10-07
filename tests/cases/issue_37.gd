extends RegressionCase

func run() -> void:
	var cold: GameplayTag = GameplayTag.new()
	cold.id = &"issue_37.cold"
	var hot: GameplayTag = GameplayTag.new()
	hot.id = &"issue_37.hot"
	hot.mutually_exclusive_tags = [cold.id]
	var tags: Array[GameplayTag] = [cold, hot]
	TagManager.initialize(tags)
	var actor: Node = Node.new()
	var removed: Array[StringName] = []
	var on_removed: Callable = func(_target: Node, id: StringName) -> void:
		removed.append(id)
	TagManager.tag_removed.connect(on_removed)
	var success: bool = TagManager.remove_tag(actor, cold.id)
	expect(not success and removed.is_empty(), "Removing an absent tag must not claim success or emit a fake removal")
	TagManager.add_tag(actor, cold.id)
	TagManager.add_tag(actor, cold.id)
	TagManager.remove_tag(actor, cold.id)
	expect(TagManager.get_tag_count(actor, cold.id) == 1, "Removing one acquisition must preserve another")
	success = TagManager.add_tag(actor, hot.id)
	expect(not success and TagManager.has_tag(actor, cold.id) and not TagManager.has_tag(actor, hot.id), "Mutual exclusion must not erase a valid source behind the caller's back")
	TagManager.clear_all_tags(actor)
	TagManager.add_tag(actor, cold.id)
	var component: GameplayStatusComponent = GameplayStatusComponent.new()
	actor.add_child(component)
	var prior: GameplayStatusData = GameplayStatusData.new()
	prior.status_id = &"issue_37.prior"
	prior.tags = [cold.id]
	component.apply_status(prior, actor)
	var next: GameplayStatusData = GameplayStatusData.new()
	next.status_id = &"issue_37.next"
	next.tags = [hot.id]
	component.apply_status(next, actor)
	expect(component.has_status(prior.status_id) and not component.has_status(next.status_id), "Unowned conflicting source must block replacement before removing the current status")
	expect(TagManager.has_tag(actor, cold.id), "An unowned tag source must remain represented after a rejected status")
	TagManager.tag_removed.disconnect(on_removed)
	_test_sources_and_reset(actor, cold.id)
	_test_status_replacement(actor, component, cold.id, hot.id)
	_test_relations_and_identity()
	_test_batch_and_release_queue()
	_test_notifications_and_component_exit(cold.id)
	actor.free()

func _test_sources_and_reset(actor: Node, tag_id: StringName) -> void:
	TagManager.clear_all_tags(actor)
	TagManager.add_tag(actor, tag_id, &"source.a")
	TagManager.add_tag(actor, tag_id, &"source.a")
	TagManager.add_tag(actor, tag_id, &"source.b")
	expect(TagManager.get_tag_count(actor, tag_id) == 3 and TagManager.get_tag_source_count(actor, tag_id, &"source.a") == 2, "Counts must preserve acquisition multiplicity per source")
	expect(not TagManager.remove_tag(actor, tag_id), "Anonymous release must not decrement a named source")
	TagManager.remove_tag(actor, tag_id, &"source.a")
	expect(TagManager.get_tag_count(actor, tag_id) == 2, "Release must decrement only its own source")
	TagManager.remove_source(actor, &"source.a")
	expect(TagManager.get_tag_count(actor, tag_id) == 1 and TagManager.has_tag(actor, tag_id), "Removing source A must preserve B")
	TagManager.force_remove_tag(actor, tag_id)
	TagManager.add_tag(actor, tag_id, &"source.new")
	expect(not TagManager.remove_source(actor, &"source.b") and TagManager.get_tag_count(actor, tag_id) == 1, "Late release of an old source after reset must not steal a new acquisition")
	TagManager.clear_all_tags(actor)

func _test_status_replacement(actor: Node, component: GameplayStatusComponent, cold: StringName, hot: StringName) -> void:
	component.remove_status(&"issue_37.prior")
	var a: GameplayStatusData = _status(&"issue_37.a", cold, 1)
	var b: GameplayStatusData = _status(&"issue_37.b", cold, 1)
	component.apply_status(a, actor)
	component.apply_status(b, actor)
	expect(TagManager.get_tag_count(actor, cold) == 2, "Two status instances must grant the same tag from distinct sources")
	component.remove_status(a.status_id)
	expect(TagManager.get_tag_count(actor, cold) == 1 and component.has_status(b.status_id), "Removing status A must preserve status B's tag")
	component.apply_status(a, actor)
	var replacement: GameplayStatusData = _status(&"issue_37.replace", hot, 10)
	component.apply_status(replacement, actor)
	expect(not component.has_status(a.status_id) and not component.has_status(b.status_id) and component.has_status(replacement.status_id), "Mutual exclusion must remove the actual old statuses")
	expect(not TagManager.has_tag(actor, cold) and TagManager.get_tag_count(actor, hot) == 1, "Status and tag membership must agree after replacement")
	component.apply_status(a, actor)
	expect(component.has_status(replacement.status_id) and not component.has_status(a.status_id), "Lower-priority conflicting status must not evict the higher-priority status")
	a.priority = 20
	component.apply_status(a, actor)
	expect(component.has_status(a.status_id) and not component.has_status(replacement.status_id) and not TagManager.has_tag(actor, hot), "Exclusions must work in both directions even if only one resource declares them")
	component.remove_status(a.status_id)
	var other: GameplayStatusComponent = GameplayStatusComponent.new()
	actor.add_child(other)
	other.apply_status(b, actor)
	component.apply_status(replacement, actor)
	expect(other.has_status(b.status_id) and not component.has_status(replacement.status_id), "A container must not remove a status owned by another container")
	other.remove_status(b.status_id)
	other.free()

func _test_relations_and_identity() -> void:
	var parent: GameplayTag = _tag(&"issue_37.parent")
	var child: GameplayTag = _tag(&"issue_37.child")
	child.parent_tag_id = parent.id
	TagManager.register_tags([parent, child, _tag(&"issue_37.child_direct"), _tag(&"issue_37_child")])
	var actor: Node = Node.new()
	TagManager.add_tag(actor, child.id, &"child")
	TagManager.add_tag(actor, &"issue_37_child", &"underscore")
	expect(TagManager.has_tag(actor, parent.id) and not TagManager.has_tag(actor, parent.id, false), "Inherited and direct queries must have separate cache entries")
	TagManager.has_tag(actor, child.id, false)
	expect(not TagManager.has_tag(actor, &"issue_37.child_direct"), "A direct-query cache suffix must not collide with another real tag ID")
	TagManager.remove_source(actor, &"child")
	expect(TagManager.get_tag_count(actor, &"issue_37_child") == 1, "Dot and underscore tag IDs must not share metadata counters")
	TagManager.add_tag(actor, child.id, &"child")
	TagManager.unregister_tag(parent.id)
	expect(not TagManager.has_tag(actor, parent.id), "Registry changes must invalidate inherited query caches")
	TagManager.register_tag(parent)
	expect(TagManager.has_tag(actor, parent.id), "Re-registering a parent must rebuild inheritance and cached queries")
	var loop_a: GameplayTag = _tag(&"issue_37.loop_a")
	var loop_b: GameplayTag = _tag(&"issue_37.loop_b")
	loop_a.parent_tag_id = loop_b.id
	loop_b.parent_tag_id = loop_a.id
	TagManager.register_tags([loop_a, loop_b])
	expect(not TagManager.validate_tag(loop_a.id), "Cyclic parent configuration must fail validation without hanging")
	actor.free()

func _test_notifications_and_component_exit(tag_id: StringName) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var actor: Node = Node.new()
	var component: GameplayStatusComponent = GameplayStatusComponent.new()
	actor.add_child(component)
	tree.root.add_child(actor)
	var data: GameplayStatusData = _status(&"issue_37.exit", tag_id, 0)
	var on_added: Callable = func(target: Node, id: StringName) -> void:
		if target == actor and id == tag_id:
			component.remove_status(data.status_id)
	TagManager.tag_added.connect(on_added)
	component.apply_status(data, actor)
	expect(not component.has_status(data.status_id) and not TagManager.has_tag(actor, tag_id), "Removing a status in tag-added notification must release its source before returning")
	TagManager.tag_added.disconnect(on_added)
	component.apply_status(data, actor)
	component.free()
	expect(not TagManager.has_tag(actor, tag_id), "Leaving the scene tree must release the component's status tag sources")
	actor.free()
	actor = Node.new()
	component = GameplayStatusComponent.new()
	actor.add_child(component)
	tree.root.add_child(actor)
	var on_free: Callable = func(target: Node, id: StringName) -> void:
		if id == tag_id:
			target.free()
	TagManager.tag_added.connect(on_free)
	component.apply_status(data, actor)
	expect(not is_instance_valid(actor), "Target exit from a tag notification must complete without invalid object access")
	TagManager.tag_added.disconnect(on_free)
	actor = Node.new()
	component = GameplayStatusComponent.new()
	actor.add_child(component)
	tree.root.add_child(actor)
	component.apply_status(data, actor)
	TagManager.tag_removed.connect(on_free)
	component.remove_status(data.status_id)
	expect(not is_instance_valid(actor), "Target exit from tag removal must not emit through a freed status component")
	TagManager.tag_removed.disconnect(on_free)

func _test_batch_and_release_queue() -> void:
	var first: GameplayTag = _tag(&"issue_37.batch.first")
	var second: GameplayTag = _tag(&"issue_37.batch.second")
	var next: GameplayTag = _tag(&"issue_37.batch.next")
	var last: GameplayTag = _tag(&"issue_37.batch.last")
	TagManager.register_tags([first, second, next, last])
	var actor: Node = Node.new()
	expect(not TagManager.can_add_tags(actor, [&"issue_37.unknown"]) and not actor.has_meta(&"gas_tag_state"), "A failed read-only check must not create runtime state")
	expect(not TagManager.add_tags(actor, [first.id, &"issue_37.unknown"]) and not TagManager.has_tag(actor, first.id), "An invalid batch must not apply its valid prefix")
	var on_added: Callable = func(target: Node, id: StringName) -> void:
		if target == actor and id == first.id:
			expect(TagManager.has_tag(actor, second.id), "Batch membership must be committed before its first notification")
	TagManager.tag_added.connect(on_added)
	TagManager.add_tags(actor, [first.id, second.id], &"batch")
	TagManager.tag_added.disconnect(on_added)
	TagManager.add_tag(actor, next.id, &"next")
	TagManager.add_tag(actor, last.id, &"last")
	var removed: Array[StringName] = []
	var on_removed: Callable = func(target: Node, id: StringName) -> void:
		if target != actor:
			return
		removed.append(id)
		if id == first.id:
			TagManager.remove_source(actor, &"next")
		elif id == next.id:
			TagManager.remove_source(actor, &"last")
	TagManager.tag_removed.connect(on_removed)
	TagManager.remove_source(actor, &"batch")
	expect(TagManager.get_all_tags(actor).is_empty() and removed.size() == 4, "Cascading source releases must drain within the outer call without fake events")
	TagManager.tag_removed.disconnect(on_removed)
	actor.free()

func _tag(id: StringName) -> GameplayTag:
	var tag: GameplayTag = GameplayTag.new()
	tag.id = id
	return tag

func _status(id: StringName, tag_id: StringName, priority: int) -> GameplayStatusData:
	var data: GameplayStatusData = GameplayStatusData.new()
	data.status_id = id
	data.tags = [tag_id]
	data.priority = priority
	return data
