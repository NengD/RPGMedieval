extends SceneTree
## Mesure la posture de visée au fusil : orientation à donner à l'arbalète dans la main droite
## (axe avant = de la main droite vers la main gauche). godot --headless --path . -s tools/xbow_hand_axes.gd
func _initialize() -> void:
	_run()
func _run() -> void:
	var m := HeroModel.new()
	root.add_child(m)
	await process_frame
	m.tree.active = false
	m.anim_player.play(&"xbow_aim")
	m.anim_player.seek(0.6, true)
	await process_frame
	await process_frame
	var inv := m.global_transform.affine_inverse()
	var left := inv * (m.skeleton.global_transform * m.skeleton.get_bone_global_pose(m.skeleton.find_bone("mixamorig_LeftHand")))
	var right := inv * (m.skeleton.global_transform * m.skeleton.get_bone_global_pose(m.skeleton.find_bone("mixamorig_RightHand")))
	var fwd := (left.origin - right.origin).normalized()
	var up := Vector3.UP
	var b := Basis.looking_at(fwd, up)   # -Z = vers l'avant de l'arme
	var rel := right.basis.inverse() * b
	print("avant arme: ", fwd, "  XBOW_HAND_ROTATION = Vector3", rel.get_euler(EULER_ORDER_YXZ))
	quit()
