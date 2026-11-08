extends SceneTree
# Test en fenêtre réelle (pas --headless) : le regard à la souris en 1re personne
func _initialize() -> void:
	_run()
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	var p: Player = main.player
	p.toggle_view()
	for i in 60: await physics_frame
	var center := Vector2(root.size) / 2.0
	var ev := InputEventMouseMotion.new()
	ev.position = center; ev.global_position = center
	ev.relative = Vector2(100, -40); ev.screen_relative = Vector2(100, -40)
	var yaw0 := p.rig.yaw
	root.push_input(ev)   # passe par l'interface (comme une vraie souris)
	for i in 5: await process_frame
	print("RESULTAT regard 1re personne: ", "OK" if not is_equal_approx(p.rig.yaw, yaw0) else "BLOQUÉ")
	quit()
