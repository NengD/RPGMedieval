extends SceneTree
## Comme le joueur : arc / arbalète visés (clic droit) avec la vraie caméra. Images user://aim_*.png
func _initialize() -> void:
	_run()
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await physics_frame
	var p: Player = main.player
	for k in [[Player.Weapon.BOW, "bow"], [Player.Weapon.CROSSBOW, "xbow"]]:
		p.switch_weapon(k[0])
		for i in 20: await physics_frame
		Input.action_press(&"guard")
		if k[0] == Player.Weapon.BOW:
			Input.action_press(&"attack")
			p.start_draw()
		for i in 70: await physics_frame
		var m: HeroModel = p.model
		print(k[1], " gauche=", m._hand_world("mixamorig_LeftHand"), " droite=", m._hand_world("mixamorig_RightHand"), " arc=", m.bow_prop.global_position, " holder=", m.bow_holder.global_position, " tete=", m._hand_world("mixamorig_Head"), " joueur=", p.global_position, " fwd=", -m.global_transform.basis.z)
		root.get_texture().get_image().get_region(Rect2i(160, 100, 520, 440)).save_png("user://aim_%s.png" % k[1])
		Input.action_release(&"guard")
		Input.action_release(&"attack")
		p.cancel_draw()
		for i in 20: await physics_frame
	quit()
