extends SceneTree
## Capture du HUD (fenêtre hors écran) : user://hud.png
func _initialize() -> void:
	_run()
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await physics_frame
	await process_frame
	root.get_texture().get_image().save_png("user://hud_sobre.png")
	main.hud._help_panel.visible = true
	main.hud._debug_panel.visible = true
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("user://hud_complet.png")
	quit()
