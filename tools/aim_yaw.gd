extends SceneTree
## Mesure de combien le corps est tourné dans les postures d'arc et d'arbalète : angle entre l'avant du héros
## et la ligne main arrière -> main avant. Donne AIM_YAW_BOW / AIM_YAW_XBOW (radians, signe : rotation à appliquer).
## godot --headless --path . -s tools/aim_yaw.gd
func _initialize() -> void:
	_run()
func _measure(m: HeroModel, anim: StringName, t_frac: float) -> float:
	m.tree.active = false
	m.anim_player.play(anim)
	m.anim_player.seek(m.anim_player.get_animation(anim).length * t_frac, true)
	await process_frame
	await process_frame
	var line := m._hand_world("mixamorig_LeftHand") - m._hand_world("mixamorig_RightHand")
	line.y = 0.0
	var fwd := -m.global_transform.basis.z
	return -fwd.signed_angle_to(line.normalized(), Vector3.UP)
func _run() -> void:
	var m := HeroModel.new()
	root.add_child(m)
	await process_frame
	print("AIM_YAW_BOW  = ", snappedf(await _measure(m, &"bow_draw", 0.999), 0.001))
	print("AIM_YAW_BOW_MID = ", snappedf(await _measure(m, &"bow_draw", 0.5), 0.001))
	print("AIM_YAW_XBOW = ", snappedf(await _measure(m, &"xbow_aim", 0.3), 0.001))
	quit()
