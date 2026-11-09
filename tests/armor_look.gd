extends SceneTree
## Aperçu : corps + pièces sur le squelette de base. Arguments : ids de pièces séparés par des virgules (défaut : tout).
## Images user://armor_<vue>.png
func _initialize() -> void:
	_run()
func _run() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var rig := (load("res://assets/base/base_rig.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(rig)
	var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	var args := OS.get_cmdline_user_args()
	var hide_regions: Array = []
	var body_nodes := RigMesh.attach(sk, load("res://assets/base/body.glb"), sk)
	var ids: Array = []
	if args.size() > 0:
		ids = args[0].split(",")
	var names := []
	for id in ids:
		var scene := load("res://assets/armor/%s.glb" % str(id).replace(".", "_")) as PackedScene
		RigMesh.attach(sk, scene, sk)
		names.append(id)
	print("corps : ", body_nodes.size(), " régions ; pièces : ", names)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 38
	var poses: Array = ["rest"]
	if args.size() > 1:
		poses = args[1].split(",")   # ex. guard:0.5,run_f:0.2,attack_right:0.6
	var ap := AnimationPlayer.new()
	rig.add_child(ap)
	ap.add_animation_library("", load("res://assets/anims/hero_library.res"))
	ap.root_node = ap.get_path_to(rig)
	var sheet_cols := poses.size()
	var tiles: Array[Image] = []
	for pose in poses:
		if pose != "rest":
			var parts: PackedStringArray = str(pose).split(":")
			ap.play(StringName(parts[0]))
			ap.seek(float(parts[1]) * ap.get_animation(StringName(parts[0])).length, true)
		for i in 3: await process_frame
		cam.look_at_from_position(Vector3(3.2, 1.0, 0.8), Vector3(0, 0.92, 0))
		await process_frame
		await process_frame
		tiles.append(root.get_texture().get_image().get_region(Rect2i(100, 120, 500, 640)))
	var sheet := Image.create(500 * tiles.size(), 640, false, Image.FORMAT_RGBA8)
	for i in tiles.size():
		tiles[i].convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(tiles[i], Rect2i(0, 0, 500, 640), Vector2i(500 * i, 0))
	sheet.save_png("user://armor_poses.png")
	quit()
	return
	for i in 3: await process_frame
	for v in [["face", Vector3(0, 1.0, -3.4)], ["profil", Vector3(3.4, 1.0, 0)], ["dos", Vector3(0, 1.0, 3.4)]]:
		cam.look_at_from_position(v[1], Vector3(0, 0.92, 0))
		await process_frame
		await process_frame
		root.get_texture().get_image().get_region(Rect2i(150, 40, 400, 820)).save_png("user://armor_%s.png" % v[0])
	quit()
