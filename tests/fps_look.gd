extends SceneTree
## Armes en 1re personne : user://fps_*.png
func _initialize() -> void:
	_run()
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await physics_frame
	var p: Player = main.player
	p.toggle_view()
	for i in 40: await physics_frame
	root.get_texture().get_image().save_png("user://fps_epee.png")
	p.switch_weapon(Player.Weapon.BOW)
	Input.action_press(&"attack")
	p.start_draw()
	for i in 60: await physics_frame
	root.get_texture().get_image().save_png("user://fps_arc.png")
	Input.action_release(&"attack")
	p.cancel_draw()
	p.switch_weapon(Player.Weapon.CROSSBOW)
	for i in 30: await physics_frame
	root.get_texture().get_image().save_png("user://fps_arbalete.png")
	quit()
