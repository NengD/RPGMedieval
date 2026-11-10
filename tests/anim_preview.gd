extends SceneTree
## Aperçu d'animations : image par image, de face et de profil, côte à côte -> user://prev/<nom>/f0000.png
## godot --path . --resolution 900x520 --position 6000,3000 -s tests/anim_preview.gd -- ual_slash_a ual_combo ...  [fps=15]
func _initialize() -> void:
	_run()
func _run() -> void:
	var names: Array = []
	var fps := 15.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("fps="):
			fps = float(a.substr(4))
		else:
			names.append(a)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.56, 0.62)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.35, 0.36, 0.38)
	pm.material = fm
	floor_mi.mesh = pm
	root.add_child(floor_mi)
	# personnage : corps + tenue de chevalier + épée
	var holder := Node3D.new()
	root.add_child(holder)
	var rig := (load("res://assets/base/base_rig.tscn") as PackedScene).instantiate() as Node3D
	holder.add_child(rig)
	var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	Registry.scan()
	var outfit := Registry.get_data(&"tenue.chevalier_plates") as OutfitData
	for body_part in RigMesh.attach(sk, load("res://assets/base/body.glb"), sk):
		body_part.visible = false
	for pid in outfit.pieces:
		var piece := Registry.get_data(pid) as ArmorData
		var meshes := RigMesh.attach(sk, piece.model, sk)
		for mi in meshes:
			for s in mi.mesh.get_surface_count():
				var base := mi.mesh.surface_get_material(s)
				var n := String(base.resource_name) if base != null else ""
				if ArmorMaterials.is_known(n):
					var mat: StandardMaterial3D = ArmorMaterials.get_material(n)
					if ArmorMaterials.is_tinted(n):
						mat = mat.duplicate()
						mat.albedo_color = Color(0.4, 0.5, 0.9)
					if n in ["acier_plaques", "mailles"]:
						var m2 := mat.duplicate() as StandardMaterial3D
						m2.metallic = 0.15
						m2.albedo_color = Color(0.62, 0.64, 0.68)
						m2.rim_enabled = false
						mat = m2
					mi.set_surface_override_material(s, mat)
	var hand := BoneAttachment3D.new()
	hand.bone_name = "mixamorig_RightHand"
	sk.add_child(hand)
	var sword_holder := Node3D.new()
	hand.add_child(sword_holder)
	sword_holder.rotation_degrees = Vector3(0, 0, -90)
	sword_holder.position = GameConfig.MELEE_GRIP_OFFSET
	sword_holder.add_child((load("res://assets/weapons/arme_epee_longue.glb") as PackedScene).instantiate())
	# mains fermées comme en jeu : droite sur l'épée, gauche sur la poignée (écu / deux mains)
	for side in ["Right", "Left"]:
		var grip := FingerGripModifier.new()
		grip.side = side
		sk.add_child(grip)
		grip.curl = 1.0
	var ap := AnimationPlayer.new()
	rig.add_child(ap)
	ap.add_animation_library("", load("res://assets/anims/hero_library.res"))
	ap.add_animation_library("u", load("res://assets/anims/ual_library.res"))
	ap.root_node = ap.get_path_to(rig)
	holder.rotation.y = PI   # le modèle regarde vers +Z ; on le montre de face / profil depuis la caméra
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 32
	var w := 450
	var h := 520
	for nm in names:
		var key: StringName = StringName(nm) if ap.has_animation(StringName(nm)) else StringName("u/" + str(nm))
		if not ap.has_animation(key):
			print("ANIMATION INCONNUE ", nm)
			continue
		var anim := ap.get_animation(key)
		var dir: String = "user://prev/" + str(nm)
		DirAccess.make_dir_recursive_absolute(dir)
		var frames := int(ceil(anim.length * fps)) + 1
		ap.play(key)
		for f in frames:
			ap.seek(minf(f / fps, anim.length), true)
			var hips := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("mixamorig_Hips")).origin
			for i in 2: await process_frame
			var combined := Image.create(w * 2, h, false, Image.FORMAT_RGBA8)
			for v in 2:
				var target := Vector3(hips.x, 0.95, hips.z)
				var offset := Vector3(0, 0.5, 4.0) if v == 0 else Vector3(4.0, 0.5, 0)   # face (le héros regarde -Z après rotation) puis profil
				cam.global_position = target + offset
				cam.look_at(target, Vector3.UP)
				for i in 2: await process_frame
				var img := root.get_texture().get_image().get_region(Rect2i(225, 0, w, h)) if v >= 0 else null
				img.convert(Image.FORMAT_RGBA8)
				combined.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(w * v, 0))
			combined.save_png("%s/f%04d.png" % [dir, f])
		print("APERCU ", nm, " ", frames, " images")
	quit()
