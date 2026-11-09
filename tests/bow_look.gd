extends SceneTree
## Coup d'œil sur l'arc en 3e personne (fenêtre hors écran) : images dans user://bow_*.png
## godot --path . --resolution 960x540 --position 6000,3000 -s tests/bow_look.gd
func _initialize() -> void:
	_run()
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await physics_frame
	var p: Player = main.player
	p.switch_weapon(Player.Weapon.BOW)
	for i in 30: await physics_frame
	_shot("idle")
	Input.action_press(&"attack")
	p.start_draw()
	for step in 3:
		for i in 25: await physics_frame
		_shot("draw%d" % step)
	Input.action_release(&"attack")
	for i in 10: await physics_frame
	_shot("release")
	quit()
func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.get_region(Rect2i(280, 230, 400, 300)).save_png("user://bow_%s.png" % name)
