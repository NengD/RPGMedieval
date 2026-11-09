extends SceneTree
## Parade avec / sans écu, vue de la vraie caméra et vues diag. Images user://guard_*.png
func _initialize() -> void:
	_run()
var cam: Camera3D
var p: Player
func _snap(name: String, view: String, dist := 2.4) -> void:
	var pos := p.global_position
	var fwd := -p.global_basis.z
	var side := p.global_basis.x
	var offset := Vector3.ZERO
	match view:
		"profil": offset = side * dist + Vector3(0, 1.2, 0)
		"face": offset = fwd * dist + side * 0.3 + Vector3(0, 1.2, 0)
		"dos": offset = -fwd * dist + side * 0.3 + Vector3(0, 1.3, 0)
		"dessus": offset = Vector3(0.01, dist + 1.0, 0.01) + fwd * 0.2
	cam.global_position = pos + offset
	cam.look_at(pos + Vector3(0, 1.2, 0) + fwd * 0.2, Vector3.UP if absf(offset.normalized().y) < 0.9 else fwd)
	cam.current = true
	await process_frame
	await process_frame
	root.get_texture().get_image().get_region(Rect2i(240, 60, 480, 420)).save_png("user://guard_%s_%s.png" % [name, view])
func _run() -> void:
	load("res://scripts/input_setup.gd").register_actions()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 40: await physics_frame
	p = main.player
	cam = Camera3D.new()
	main.add_child(cam)
	main.enemy.ai_enabled = false
	Input.action_press(&"guard")
	for i in 60: await physics_frame
	for v in ["face", "dos", "dessus"]:
		await _snap("sans_ecu", v)
	Input.action_release(&"guard")
	p.toggle_shield()
	for i in 30: await physics_frame
	Input.action_press(&"guard")
	for i in 60: await physics_frame
	for v in ["face", "dos", "dessus"]:
		await _snap("avec_ecu", v)
	quit()
