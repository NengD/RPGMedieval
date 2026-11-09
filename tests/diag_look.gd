extends SceneTree
## Diagnostic : armes en main sous plusieurs angles. Images user://diag_<cas>_<vue>.png
func _initialize() -> void:
	_run()

var cam: Camera3D
var p: Player
var pos: Vector3
var fwd: Vector3
var side: Vector3

func _snap(case_name: String, view: String, _unused: Vector3, target_up := 1.2, size := Rect2i(300, 80, 360, 400), dist := 2.4) -> void:
	pos = p.global_position
	fwd = -p.global_basis.z
	side = p.global_basis.x
	var offset := Vector3.ZERO
	match view:
		"profil": offset = side * dist + Vector3(0, 1.2, 0)
		"face": offset = fwd * dist + side * 0.3 + Vector3(0, 1.2, 0)
		"dos": offset = -fwd * dist + side * 0.3 + Vector3(0, 1.2, 0)
		"dessus": offset = Vector3(0.01, dist + 1.0, 0.01) + fwd * 0.2
	cam.global_position = pos + offset
	cam.look_at(pos + Vector3(0, target_up, 0) + fwd * 0.2, Vector3.UP if absf(offset.normalized().y) < 0.9 else fwd)
	cam.current = true
	await process_frame
	await process_frame
	root.get_texture().get_image().get_region(size).save_png("user://diag_%s_%s.png" % [case_name, view])

func _views(case_name: String, dist := 2.4) -> void:
	await _snap(case_name, "profil", side * dist + Vector3(0, 1.2, 0))
	await _snap(case_name, "face", fwd * dist + side * 0.3 + Vector3(0, 1.2, 0))
	await _snap(case_name, "dos", -fwd * dist + side * 0.3 + Vector3(0, 1.2, 0))
	await _snap(case_name, "dessus", Vector3(0.01, dist + 1.0, 0.01) + fwd * 0.2)

func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40: await physics_frame
	p = main.player
	cam = Camera3D.new()
	main.add_child(cam)
	pos = p.global_position
	fwd = -p.global_basis.z
	side = p.global_basis.x
	p.combatant.equipment.equip_weapon(Registry.get_data(&"arme.hache_guerre"))
	for i in 30: await physics_frame
	for v in ["profil", "face"]:
		await _snap("hache2", v, Vector3.ZERO, 1.2, Rect2i(300, 80, 360, 400), 2.2)
	p.combatant.equipment.equip_weapon(Registry.get_data(&"arme.epee_longue"))
	p.switch_weapon(Player.Weapon.BOW)
	Input.action_press(&"guard")
	Input.action_press(&"attack")
	p.start_draw()
	for i in 90: await physics_frame
	for v in ["profil", "dessus", "dos"]:
		await _snap("arc2", v, Vector3.ZERO, 1.3, Rect2i(180, 60, 600, 420), 1.6)
	quit()
