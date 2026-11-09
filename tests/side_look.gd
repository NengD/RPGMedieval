extends SceneTree
## Vue de profil du héros avec arc / arbalète (fenêtre hors écran) : user://side_*.png
func _initialize() -> void:
	_run()
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await physics_frame
	var p: Player = main.player
	var cam := Camera3D.new()
	main.add_child(cam)
	var pos: Vector3 = p.global_position
	var fwd: Vector3 = -p.global_basis.z
	var side: Vector3 = p.global_basis.x
	var kinds := [[Player.Weapon.BOW, "bow"], [Player.Weapon.CROSSBOW, "xbow"]]
	for k in kinds:
		p.switch_weapon(k[0])
		for i in 30: await physics_frame
		if k[0] == Player.Weapon.BOW:
			Input.action_press(&"attack")
			p.start_draw()
		else:
			Input.action_press(&"guard")
		for i in 90: await physics_frame
		for v in [["side", side * 2.0 + fwd * 0.4], ["back", -fwd * 2.2 + side * 0.5], ["front", fwd * 2.4 + side * 0.3]]:
			cam.global_position = pos + v[1] + Vector3(0, 1.3, 0)
			cam.look_at(pos + Vector3(0, 1.3, 0) + fwd * 0.4, Vector3.UP)
			cam.current = true
			await process_frame
			await process_frame
			root.get_texture().get_image().get_region(Rect2i(240, 90, 480, 360)).save_png("user://%s_%s.png" % [v[0], k[1]])
		Input.action_release(&"attack")
		Input.action_release(&"guard")
		cam.current = false
		for i in 30: await physics_frame
	quit()
