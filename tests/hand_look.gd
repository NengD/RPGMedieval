extends SceneTree
## Gros plan de la main droite avec l'épée, pour différents axes / courbures. user://main_<n>.png
## godot --path . --resolution 800x600 --position 6000,3000 -s tests/hand_look.gd -- ax ay az curl
func _initialize() -> void:
	_run()
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() >= 3:
		FingerGripModifier.FLEX_AXIS = Vector3(float(a[0]), float(a[1]), float(a[2]))
	if a.size() >= 10:
		FingerGripModifier.THUMB_AXIS = Vector3(float(a[7]), float(a[8]), float(a[9]))
	var curl := float(a[3]) if a.size() > 3 else 1.0
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.56, 0.62)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.85, 0.85)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -20, 0)
	root.add_child(sun)
	var holder := Node3D.new()
	root.add_child(holder)
	var rig := (load("res://assets/base/base_rig.tscn") as PackedScene).instantiate() as Node3D
	holder.add_child(rig)
	var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	for part in RigMesh.attach(sk, load("res://assets/base/body.glb"), sk):
		if not String(part.name).contains("hand") and not String(part.name).contains("forearm"):
			part.visible = false
	var hand := BoneAttachment3D.new()
	hand.bone_name = "mixamorig_RightHand"
	sk.add_child(hand)
	var holder2 := Node3D.new()
	hand.add_child(holder2)
	holder2.rotation_degrees = Vector3(0, 0, -90)
	holder2.position = GameConfig.MELEE_GRIP_OFFSET
	if a.size() >= 7:
		holder2.position = Vector3(float(a[4]), float(a[5]), float(a[6]))
	holder2.add_child((load("res://assets/weapons/arme_epee_longue.glb") as PackedScene).instantiate())
	var grip := FingerGripModifier.new()
	grip.side = "Right"
	sk.add_child(grip)
	grip.curl = curl
	var ap := AnimationPlayer.new()
	rig.add_child(ap)
	ap.add_animation_library("", load("res://assets/anims/hero_library.res"))
	ap.root_node = ap.get_path_to(rig)
	ap.play(&"idle")
	ap.seek(0.5, true)
	for i in 4: await process_frame
	var wp := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_RightHand")).origin
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 25
	cam.look_at_from_position(wp + Vector3(0.0, 0.1, 0.55) , wp)
	for i in 3: await process_frame
	root.get_texture().get_image().save_png("user://main_%s.png" % (a[0] + "_" + a[1] + "_" + a[2] + ("_" + a[4] + "_" + a[5] + "_" + a[6] + ("_" + a[7] + "_" + a[8] + "_" + a[9] if a.size() >= 10 else "") if a.size() >= 7 else "") if a.size() >= 3 else "defaut"))
	quit()
