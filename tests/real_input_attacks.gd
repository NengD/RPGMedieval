extends SceneTree
## Test visuel "comme un joueur" : choisit chaque direction avec la souris, clique, et enregistre une planche d'images (user://reel.png).
## godot --path . --resolution 1280x720 --position 6000,3000 -s tests/real_input_attacks.gd
## Test "comme un joueur" : mouvements de souris pour choisir la direction, puis clic gauche, via le même chemin que la vraie souris.
const OUT := "user://"   # la planche est enregistrée dans le dossier utilisateur de Godot
var p: Player
var e: Enemy
func _initialize() -> void:
	_run()
func _frames(n: int) -> void:
	for i in n: await physics_frame
func _mouse(dx: float, dy: float) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = Vector2(root.size) / 2.0
	ev.relative = Vector2(dx, dy)
	ev.screen_relative = Vector2(dx, dy)
	root.push_input(ev)
func _click(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = Vector2(root.size) / 2.0
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(ev)
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	# Isolation : aucune commande réelle (stick, souris, clavier) ne doit perturber le test
	for action in [&"look_left", &"look_right", &"look_up", &"look_down", &"move_forward", &"move_back", &"move_left", &"move_right", &"guard", &"dodge", &"jump", &"sprint"]:
		InputMap.action_erase_events(action)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	p = main.player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # on ne capture PAS la vraie souris : elle ne doit pas perturber le test
	p.accept_input_without_capture = true
	e = main.enemy
	e.ai_enabled = false
	p.combatant.invincible = true
	var dirs := [["haut", 0, -90.0], ["droite", 1, 90.0], ["estoc", 2, 0.0], ["gauche", 3, -90.0]]
	var sheet := Image.create(420 * 6, 440 * 4, false, Image.FORMAT_RGB8)
	var row := 0
	for d in dirs:
		p.reset_to(Vector3(0.0, 0.05, -1.0), 0.0)
		e.reset_to(Vector3(0, 0, -4.5))
		p.rig.pitch = -0.15
		await _frames(60)
		# choisir la direction avec la souris
		match d[0]:
			"haut": _mouse(0, -120)
			"estoc": _mouse(0, 120)
			"droite": _mouse(120, 0)
			"gauche": _mouse(-120, 0)
		await _frames(3)
		p.rig.yaw = 0.0
		p.rig.pitch = -0.15
		var picked := p.aim_dir
		_click(true)
		_click(false)
		var marks := [0.0, 0.25, 0.5, 0.7, 0.85, 1.2]
		var gi := 0
		var t := 0.0
		var states := []
		while gi < marks.size() and t < 3.0:
			await physics_frame
			t += 1.0 / 120.0
			if states.is_empty() or states[-1] != p.combatant.state:
				states.append(p.combatant.state)
			if t >= marks[gi]:
				await process_frame
				var img := root.get_texture().get_image()
				sheet.blit_rect(img.get_region(Rect2i(430, 200, 420, 440)), Rect2i(0, 0, 420, 440), Vector2i(gi * 420, row * 440))
				gi += 1
		print("direction voulue=%s  choisie=%s  attaque lancée=%s  états=%s" % [d[0], GameConfig.DIR_NAMES[picked], "oui" if states.has(1) else "NON", str(states)])
		row += 1
		await _frames(150)
	sheet.save_png(OUT + "reel.png")
	quit()
