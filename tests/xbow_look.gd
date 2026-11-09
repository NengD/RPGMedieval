extends SceneTree
## Coup d'œil sur l'arbalète en 3e personne (fenêtre hors écran) : user://xbow_*.png
func _initialize() -> void:
	_run()
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await physics_frame
	var p: Player = main.player
	p.switch_weapon(Player.Weapon.CROSSBOW)
	for i in 40: await physics_frame
	_shot("idle")
	Input.action_press(&"guard")
	for i in 40: await physics_frame
	_shot("aim")
	quit()
func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.get_region(Rect2i(0, 120, 640, 420)).save_png("user://xbow_%s.png" % name)
