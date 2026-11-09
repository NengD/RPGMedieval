extends SceneTree
## Les trois tenues (face / profil / dos) avec la vraie scène : user://tenue_<n>_<vue>.png
func _initialize() -> void:
	_run()
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40: await physics_frame
	main.enemy.ai_enabled = false
	main.hud.visible = false
	var p: Player = main.player
	var cam := Camera3D.new()
	main.add_child(cam)
	for n in 3:
		if n > 0:
			p.cycle_outfit()
		for i in 25: await physics_frame
		var pos := p.global_position
		var fwd := -p.global_basis.z
		var side := p.global_basis.x
		for v in [["face", fwd * 2.2 + side * 0.3], ["profil", side * 2.2], ["dos", -fwd * 2.2 + side * 0.3]]:
			cam.global_position = pos + v[1] + Vector3(0, 1.3, 0)
			cam.look_at(pos + Vector3(0, 1.0, 0), Vector3.UP)
			cam.current = true
			await process_frame
			await process_frame
			root.get_texture().get_image().get_region(Rect2i(300, 40, 360, 460)).save_png("user://tenue_%d_%s.png" % [n, v[0]])
	quit()
