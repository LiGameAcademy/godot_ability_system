extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# 首帧初始化后再测试，使模拟输入使用正常的帧编号。
	await process_frame
	var cases: PackedStringArray = OS.get_cmdline_user_args()
	if cases.is_empty():
		for entry: String in DirAccess.get_files_at("res://tests/cases"):
			if entry.ends_with(".gd"):
				cases.append(entry.trim_suffix(".gd"))
	var failed: bool = false
	for case_name: String in cases:
		var script: Script = load("res://tests/cases/%s.gd" % case_name)
		if not is_instance_valid(script) or not script.can_instantiate():
			printerr("Cannot instantiate regression case: ", case_name)
			failed = true
			continue
		var test: RegressionCase = script.new()
		await test.run()
		if test.failures.is_empty():
			print("PASS: ", case_name)
		else:
			failed = true
			for message: String in test.failures:
				printerr("FAIL: %s: %s" % [case_name, message])
	quit(1 if failed else 0)
