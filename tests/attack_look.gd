extends SceneTree
## Les trois coups en jeu (animations Quaternius) : user://coup_<n>.png (4 images par coup, de profil)
func _initialize() -> void:
	_run()
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40: await physics_frame
	main.enemy.ai_enabled = false
	main.hud.visible = false
	main.enemy.global_position = Vector3(30, 0, 30)
	var p: Player = main.player
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.current = true
	var sheet := Image.create(360 * 4, 300 * 3, false, Image.FORMAT_RGBA8)
	for n in 3:
		p.combatant.reset()
		p.combatant.stamina = 100.0
		p.combatant.combo_index = n   # combo : droite, gauche, haut
		for i in 60: await physics_frame
		p.try_attack()
		var total := p.combatant.state_duration
		for k in 4:
			for i in 30: await physics_frame
			var pos := p.global_position + Vector3(0, 1.1, 0)
			cam.global_position = pos + p.global_basis.x * 2.6 + Vector3(0, 0.4, 0.2)
			cam.look_at(pos, Vector3.UP)
			await process_frame
			await process_frame
			var im := root.get_texture().get_image().get_region(Rect2i(300, 80, 360, 300))
			im.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(im, Rect2i(0, 0, 360, 300), Vector2i(360 * k, 300 * n))
	sheet.resize(1080, 675)
	sheet.save_png("E:/_jeu perso/rpgmedieval/docs/apercu_coups_en_jeu.png")
	quit()
