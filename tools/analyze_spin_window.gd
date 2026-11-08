extends SceneTree
## Rotation du corps (hanches) pendant un PASSAGE précis d'un clip.
## godot --headless --path . -s tools/analyze_spin_window.gd
const WINDOWS := [
	["sword_and_shield_attack_2", 0.03, 1.1], ["sword_and_shield_attack_2", 0.03, 0.7],
	["axe_standing_melee_attack_backhand", 0.95, 1.85], ["axe_standing_melee_attack_backhand", 0.1, 1.2],
	["sword_and_shield_slash_3", 0.0, 1.5], ["sword_and_shield_attack_4", 0.0, 0.9],
	["axe_standing_melee_attack_horizontal", 0.13, 2.1], ["axe_standing_melee_attack_downward", 0.13, 1.9],
	["axe_standing_melee_combo_attack_ver__3", 0.64, 1.6], ["sword_and_shield_slash", 0.0, 1.4],
	["axe_standing_melee_combo_attack_ver__1", 0.0, 1.6], ["axe_standing_melee_combo_attack_ver__2", 1.05, 2.25],
]
func _initialize() -> void:
	_run()
func _run() -> void:
	for w in WINDOWS:
		var inst: Node = (load("res://assets/anims/%s.fbx" % w[0]) as PackedScene).instantiate()
		root.add_child(inst)
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		var hips := sk.find_bone("mixamorig_Hips")
		ap.play(ap.get_animation_list()[0])
		var n := 30
		var prev := 0.0
		var total := 0.0
		var lo := 0.0
		var hi := 0.0
		for i in n + 1:
			ap.seek(lerpf(w[1], w[2], float(i) / n), true)
			await process_frame
			await process_frame
			var b := sk.get_bone_global_pose(hips).basis
			var yaw := atan2(b.z.x, b.z.z)
			if i > 0:
				total += angle_difference(prev, yaw)
			prev = yaw
			lo = minf(lo, total)
			hi = maxf(hi, total)
		print("WIN %-44s [%.2f-%.2f]  rotation %+4.0f° à %+4.0f°  (amplitude %3.0f°)" % [w[0], w[1], w[2], rad_to_deg(lo), rad_to_deg(hi), rad_to_deg(hi - lo)])
		inst.queue_free()
	quit()
