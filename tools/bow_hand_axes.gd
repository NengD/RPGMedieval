extends SceneTree
## Mesure, à pleine tension, l'orientation de la main gauche (celle qui tient l'arc) et la position de la main droite
## (celle qui tire la corde), dans le repère du personnage. Sert à fixer l'arc dans la main.
## godot --headless --path . -s tools/bow_hand_axes.gd
func _initialize() -> void:
	_run()
func _run() -> void:
	var m := HeroModel.new()
	root.add_child(m)
	await process_frame
	m.tree.active = false
	m.anim_player.play(&"bow_draw")
	var len: float = m.anim_player.get_animation(&"bow_draw").length
	for t in [len * 0.5, len * 0.999]:
		m.anim_player.seek(t, true)
		await process_frame
		await process_frame
		var inv := m.global_transform.affine_inverse()
		var left := inv * (m.skeleton.global_transform * m.skeleton.get_bone_global_pose(m.skeleton.find_bone("mixamorig_LeftHand")))
		var right := inv * (m.skeleton.global_transform * m.skeleton.get_bone_global_pose(m.skeleton.find_bone("mixamorig_RightHand")))
		print("t=%.2f  main gauche en (%.2f, %.2f, %.2f)  main droite en (%.2f, %.2f, %.2f)" % [t, left.origin.x, left.origin.y, left.origin.z, right.origin.x, right.origin.y, right.origin.z])
		var rel := left.basis.inverse()   # base de l'arc (= repère du personnage) exprimée dans la main
		var e := rel.get_euler(EULER_ORDER_YXZ)
		print("   BOW_HAND_EULER_DEG = Vector3(%.1f, %.1f, %.1f)" % [rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z)])
	quit()
