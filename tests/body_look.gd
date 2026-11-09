extends SceneTree
## Aperçu du corps de base : user://body_*.png ; affiche sa taille
func _initialize() -> void:
	_run()
func _run() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var scene: PackedScene = load("res://assets/base/base_body.fbx")
	var body := scene.instantiate() as Node3D
	root.add_child(body)
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = body.find_children("*", "MeshInstance3D", true, false)[0]
	var aabb := mi.get_aabb()
	print("AABB maillage : ", aabb, " | échelle racine=", body.scale, " échelle squelette=", sk.scale, " échelle mesh=", mi.scale)
	print("surfaces=", mi.mesh.get_surface_count(), " sommets=", mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
	var hips := sk.find_bone("mixamorig1_Hips")
	print("hanches (repos, local squelette) = ", sk.get_bone_global_rest(hips).origin)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	for v in [["face", Vector3(0, 1.0, 3.2)], ["profil", Vector3(3.2, 1.0, 0)], ["dos", Vector3(0, 1.0, -3.2)]]:
		cam.global_position = v[1]
		cam.look_at(Vector3(0, 0.9, 0), Vector3.UP)
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("user://body_%s.png" % v[0])
	quit()
