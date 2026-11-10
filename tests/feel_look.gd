extends SceneTree
## Étincelles, traînée d'arme et poussière en jeu : user://feel_*.png
func _initialize() -> void:
	_run()
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40: await physics_frame
	main.hud.visible = false
	main.enemy.ai_enabled = false
	var p: Player = main.player
	var e: Enemy = main.enemy
	e.global_position = p.global_position + Vector3(0, 0, -1.6)
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.current = true
	p.combatant.reset()
	p.combatant.stamina = 100.0
	p.try_attack()
	var shots := 0
	for k in 40:
		await physics_frame
		if k in [20, 24, 27, 30]:
			var pos := p.global_position + Vector3(0, 1.2, 0)
			cam.global_position = pos + p.global_basis.x * 2.4 + Vector3(0, 0.5, 0.3)
			cam.look_at(pos + Vector3(0, -0.1, -0.6), Vector3.UP)
			await process_frame
			await process_frame
			root.get_texture().get_image().get_region(Rect2i(200, 60, 560, 400)).save_png("user://feel_%d.png" % shots)
			shots += 1
	quit()
