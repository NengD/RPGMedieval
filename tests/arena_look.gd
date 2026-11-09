extends SceneTree
## Vues de l'arène : user://arene_<n>.png (niveau de qualité en argument : 0 bas, 1 moyen, 2 élevé)
func _initialize() -> void:
	_run()
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40: await physics_frame
	var args := OS.get_cmdline_user_args()
	var lv := int(args[0]) if args.size() > 0 else 1
	QualitySettings.apply(lv, main.arena.environment, main.arena.sun, root)
	main.enemy.ai_enabled = false
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.current = true
	var views := [
		["haut", Vector3(0, 11, 18), Vector3(0, 0.5, -2)],
		["joueur", Vector3(-1.2, 2.0, 12.5), Vector3(0, 1.2, 0)],
		["coin", Vector3(-9, 2.2, 13), Vector3(-9, 1.0, 0)],
		["racteur", Vector3(0, 1.8, -2), Vector3(-12, 1.0, -1)],
	]
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		for i in 4: await process_frame
		root.get_texture().get_image().save_png("user://arene_%s.png" % v[0])
	quit()
