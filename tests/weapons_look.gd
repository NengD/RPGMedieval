extends SceneTree
## Chaque arme en 3e personne (profil + face), avec et sans écu : user://arme_*.png
func _initialize() -> void:
	_run()
func _shot(cam: Camera3D, pos: Vector3, fwd: Vector3, side: Vector3, v: Array, name: String) -> void:
	cam.global_position = pos + v[1] + Vector3(0, 1.2, 0)
	cam.look_at(pos + Vector3(0, 1.1, 0) + fwd * 0.2, Vector3.UP)
	cam.current = true
	await process_frame
	await process_frame
	root.get_texture().get_image().get_region(Rect2i(300, 80, 360, 400)).save_png("user://arme_%s_%s.png" % [name, v[0]])
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40: await physics_frame
	var p: Player = main.player
	var cam := Camera3D.new()
	main.add_child(cam)
	var pos: Vector3 = p.global_position
	var fwd: Vector3 = -p.global_basis.z
	var side: Vector3 = p.global_basis.x
	var views := [["profil", side * 2.4], ["face", fwd * 2.6 + side * 0.4]]
	var ids := Player.melee_weapon_ids()
	print("armes de mêlée : ", ids)
	for id in ids:
		p.combatant.equipment.equip_weapon(Registry.get_data(id))
		for i in 25: await physics_frame
		for v in views:
			await _shot(cam, pos, fwd, side, v, str(id).replace("arme.", ""))
	p.combatant.equipment.equip_weapon(Registry.get_data(&"arme.epee_longue"))
	p.toggle_shield()
	for i in 25: await physics_frame
	for v in views:
		await _shot(cam, pos, fwd, side, v, "ecu")
	quit()
