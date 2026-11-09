extends SceneTree
## Gros plan de la tête (sans casque / avec capuchon / bassinet / heaume) : user://tete_<n>.png
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
	cam.fov = 28
	var eq := p.combatant.equipment
	var configs := [["nu", []], ["barbe", ["armure.barbe"]], ["capuchon", ["armure.capuchon_mailles"]], ["bassinet", ["armure.capuchon_mailles", "armure.bassinet"]], ["heaume", ["armure.heaume"]]]
	for cfg in configs:
		eq.clear_armor()
		eq.equip(Registry.get_data(&"armure.tete_homme"))
		eq.equip(Registry.get_data(&"armure.chemise"))
		for id in cfg[1]:
			eq.equip(Registry.get_data(StringName(id)))
		for i in 8: await physics_frame
		var hb: Vector3 = p.model._hand_world("mixamorig_Head")
		var pos := hb + Vector3(0, 0.1, 0)
		var fwd := -p.global_basis.z
		for v in [["face", fwd * 1.1], ["profil", p.global_basis.x * 1.1], ["dessus", Vector3(0.01, 1.2, 0.01)]]:
			cam.global_position = pos + v[1]
			cam.look_at(pos, Vector3.UP)
			cam.current = true
			await process_frame
			await process_frame
			root.get_texture().get_image().get_region(Rect2i(330, 120, 300, 300)).save_png("user://tete_%s_%s.png" % [cfg[0], v[0]])
	quit()
