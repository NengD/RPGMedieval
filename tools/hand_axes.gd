extends SceneTree
## Donne la direction (par rapport au personnage) de chaque axe de l'os de la main, dans la pose "idle".
## Sert à orienter l'épée dans la main. godot --headless --path . -s tools/hand_axes.gd
func _initialize() -> void:
	_run()
func _run() -> void:
	var body := Node3D.new()
	root.add_child(body)
	var c := Combatant.new()
	c.body = body
	body.add_child(c)
	var m := HeroModel.new()
	body.add_child(m)
	await process_frame
	m.bind(c)
	for i in 20:
		await process_frame
	for bone in ["mixamorig_RightHand", "mixamorig_LeftForeArm"]:
		var idx := m.skeleton.find_bone(bone)
		var t := m.skeleton.global_transform * m.skeleton.get_bone_global_pose(idx)
		print(bone, " :")
		for axis_name in ["X", "Y", "Z"]:
			var axis: Vector3 = t.basis[["X", "Y", "Z"].find(axis_name)].normalized()
			# devant du personnage = -Z du monde ; droite = +X ; haut = +Y
			print("   axe %s -> avant %+.2f   droite %+.2f   haut %+.2f" % [axis_name, -axis.z, axis.x, axis.y])
	quit()
