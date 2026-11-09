extends SceneTree
## Mesure de fluidité : l'arène avec N personnages entièrement équipés, pour chaque niveau de qualité.
## godot --path . --resolution 1280x720 --position 6000,3000 -s tests/perf_look.gd -- 6
func _initialize() -> void:
	_run()
func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40: await physics_frame
	main.enemy.ai_enabled = false
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 6
	var extras: Array[Node3D] = []
	for i in n:
		var holder := Node3D.new()
		holder.position = Vector3(-6.0 + 2.4 * i, 0, 4.0)
		main.add_child(holder)
		var m := HeroModel.new()
		holder.add_child(m)
		var c := Combatant.new()
		c.body = holder
		holder.add_child(c)
		m.bind(c)
		c.equipment.equip_outfit(Registry.get_data(&"tenue.chevalier_plates"))
		c.equipment.equip_weapon(Registry.get_data(&"arme.epee_longue"))
		c.equipment.equip_weapon(Registry.get_data(&"arme.ecu"))
		m.apply_equipment(c.equipment)
		extras.append(holder)
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0, 2.2, 11)
	cam.look_at(Vector3(0, 1.0, 2), Vector3.UP)
	for lv in 3:
		QualitySettings.apply(lv, main.arena.environment, main.arena.sun, root)
		for i in 60: await process_frame
		var t0 := Time.get_ticks_usec()
		var frames := 0
		while Time.get_ticks_usec() - t0 < 3_000_000:
			await process_frame
			frames += 1
		var secs := (Time.get_ticks_usec() - t0) / 1e6
		print("QUALITE %s : %.0f images/s (%.1f ms/image), %d appels de dessin, %d objets, %d sommets" % [["Bas", "Moyen", "Élevé"][lv], frames / secs, 1000.0 * secs / frames,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
	quit()
