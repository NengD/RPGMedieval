extends SceneTree
func _initialize() -> void:
	_run()
func _snap(p, name):
	for i in 30: await process_frame
	root.get_texture().get_image().save_png("C:/Users/bende/AppData/Local/Temp/claude/1737c38915366fd2/a0d4bad4-af99-45bc-bf90-d212f860c18b/scratchpad/shot_%s.png" % name)
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	var p: Player = main.player
	p.toggle_view()
	for i in 60: await physics_frame
	await _snap(p, "fps_a")
	# simule des mouvements de souris réels
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(300, -100); ev.screen_relative = Vector2(300, -100)
	print("mode souris: ", Input.mouse_mode, " yaw avant: ", p.rig.yaw)
	Input.parse_input_event(ev)
	for i in 10: await process_frame
	print("yaw apres: ", p.rig.yaw, " pitch: ", p.rig.pitch)
	await _snap(p, "fps_b")
	quit()
