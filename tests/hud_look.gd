extends SceneTree
## Capture du HUD (fenêtre hors écran) : user://hud.png
func _initialize() -> void:
	_run()
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await physics_frame
	root.get_texture().get_image().get_region(Rect2i(0, 0, 900, 330)).save_png("user://hud.png")
	quit()
