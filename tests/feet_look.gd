extends SceneTree
## Pieds : hauteur des os par rapport au sol (marche et repos) + gros plan. user://pieds_*.png
func _initialize() -> void:
	_run()
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 60: await physics_frame
	main.enemy.ai_enabled = false
	main.hud.visible = false
	var p: Player = main.player
	var cam := Camera3D.new()
	main.add_child(cam)
	for state in ["repos", "marche"]:
		if state == "marche":
			Input.action_press(&"move_forward")
			for i in 70: await physics_frame
		var m: HeroModel = p.model
		print("PIEDS ", state, " origine y=", snappedf(p.global_position.y, 0.001), " pied G y=", snappedf(m._hand_world("mixamorig_LeftFoot").y, 0.001), " pied D y=", snappedf(m._hand_world("mixamorig_RightFoot").y, 0.001), " orteils G y=", snappedf(m._hand_world("mixamorig_LeftToeBase").y, 0.001), " bassin décalage=", snappedf(m.foot_ik.pelvis, 0.001), " model_root y=", snappedf(m.model_root.position.y, 0.001), " reste_orteil=", snappedf(m.foot_ik._rest_toe_y, 0.001), " lift=", snappedf(m.foot_ik.lift, 0.001))
		cam.global_position = p.global_position + p.global_basis.x * 1.5 + Vector3(0, 0.35, 0.3)
		cam.look_at(p.global_position + Vector3(0, 0.15, 0), Vector3.UP)
		cam.current = true
		await process_frame
		await process_frame
		root.get_texture().get_image().get_region(Rect2i(280, 150, 400, 300)).save_png("user://pieds_%s.png" % state)
	Input.action_release(&"move_forward")
	quit()
