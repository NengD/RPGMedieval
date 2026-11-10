extends SceneTree
## Transfère des animations de la Universal Animation Library (Quaternius, CC0) sur NOTRE squelette Mixamo.
## Méthode : pour chaque image (30/s) on lit la pose du squelette source (repère du squelette), on calcule la rotation globale de chaque os
##   Gt = (Gs · Rs⁻¹) · Rt      (Gs = pose source, Rs = repos source, Rt = repos cible ; les deux T-pose regardent dans le même sens)
## puis on la convertit en rotation locale du squelette cible. Hanches : déplacement mis à l'échelle de la taille, x/z figés (« sur place »).
## Résultat : assets/anims/ual_library.res  (noms « ual_* »)
## godot --headless --path . -s tools/retarget_ual.gd

const SOURCES := {
	"ual1": "res://tmp_ual/ual1.glb",
	"ual2": "res://tmp_ual/ual2.glb",
}
# source -> [nom dans le jeu, en place ?, boucle ?]
const PICK := {
	"ual1": {
		"Sword_Attack": ["ual_sword_attack", true, false], "Sword_Idle": ["ual_sword_idle", true, true],
		"Hit_Chest": ["ual_hit_chest", true, false], "Hit_Head": ["ual_hit_head", true, false], "Death01": ["ual_death", false, false],
		"Roll": ["ual_roll", true, false], "Walk": ["ual_walk", true, true], "Jog_Fwd": ["ual_jog", true, true], "Sprint": ["ual_sprint", true, true],
	},
	"ual2": {
		"Sword_Block": ["ual_sword_block", true, false], "Sword_Regular_A": ["ual_slash_a", true, false], "Sword_Regular_A_Rec": ["ual_slash_a_rec", true, false],
		"Sword_Regular_B": ["ual_slash_b", true, false], "Sword_Regular_B_Rec": ["ual_slash_b_rec", true, false], "Sword_Regular_Combo": ["ual_combo", true, false], "Idle_Shield": ["ual_shield_idle", true, true], "Idle_Shield_Break": ["ual_shield_break", true, false],
		"Shield_OneShot": ["ual_shield_bash", true, false], "Melee_Hook": ["ual_hook", true, false], "Hit_Knockback": ["ual_hit_knockback", true, false],
		"Sword_Dash_RM": ["ual_sword_dash", true, false],
	},
}
# os cible (sans « mixamorig_ ») -> os source par jeu
const MAP := {
	"ual1": {"Hips": "DEF-hips", "Spine": "DEF-spine.001", "Spine1": "DEF-spine.002", "Spine2": "DEF-spine.003", "Neck": "DEF-neck", "Head": "DEF-head"},
	"ual2": {"Hips": "pelvis", "Spine": "spine_01", "Spine1": "spine_02", "Spine2": "spine_03", "Neck": "neck_01", "Head": "Head"},
}
const FPS := 30.0

var _src_names := {}


func _initialize() -> void:
	_run()


func _build_map(set_key: String) -> Dictionary:
	var m: Dictionary = (MAP[set_key] as Dictionary).duplicate()
	for side in ["Left", "Right"]:
		var l := "L" if side == "Left" else "R"
		var lo := "l" if side == "Left" else "r"
		if set_key == "ual1":
			m[side + "Shoulder"] = "DEF-shoulder." + l
			m[side + "Arm"] = "DEF-upper_arm." + l
			m[side + "ForeArm"] = "DEF-forearm." + l
			m[side + "Hand"] = "DEF-hand." + l
			m[side + "UpLeg"] = "DEF-thigh." + l
			m[side + "Leg"] = "DEF-shin." + l
			m[side + "Foot"] = "DEF-foot." + l
			m[side + "ToeBase"] = "DEF-toe." + l
			for f in [["Index", "index"], ["Middle", "middle"], ["Ring", "ring"], ["Pinky", "pinky"]]:
				for k in [1, 2, 3]:
					m["%sHand%s%d" % [side, f[0], k]] = "DEF-f_%s.%02d.%s" % [f[1], k, l]
			for k in [1, 2, 3]:
				m["%sHandThumb%d" % [side, k]] = "DEF-thumb.%02d.%s" % [k, l]
		else:
			m[side + "Shoulder"] = "clavicle_" + lo
			m[side + "Arm"] = "upperarm_" + lo
			m[side + "ForeArm"] = "lowerarm_" + lo
			m[side + "Hand"] = "hand_" + lo
			m[side + "UpLeg"] = "thigh_" + lo
			m[side + "Leg"] = "calf_" + lo
			m[side + "Foot"] = "foot_" + lo
			m[side + "ToeBase"] = "ball_" + lo
			for f in [["Index", "index"], ["Middle", "middle"], ["Ring", "ring"], ["Pinky", "pinky"]]:
				for k in [1, 2, 3]:
					m["%sHand%s%d" % [side, f[0], k]] = "%s_%02d_%s" % [f[1], k, lo]
			for k in [1, 2, 3]:
				m["%sHandThumb%d" % [side, k]] = "thumb_%02d_%s" % [k, lo]
	return m


func _run() -> void:
	var tgt_scene := (load("res://assets/base/base_rig.tscn") as PackedScene).instantiate()
	root.add_child(tgt_scene)
	var tsk: Skeleton3D = tgt_scene.find_children("*", "Skeleton3D", true, false)[0]
	var lib := AnimationLibrary.new()
	for set_key in SOURCES:
		var src_inst := (load(SOURCES[set_key]) as PackedScene).instantiate()
		root.add_child(src_inst)
		var ssk: Skeleton3D = src_inst.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = src_inst.find_children("*", "AnimationPlayer", true, false)[0]
		var map := _build_map(set_key)
		var tgt_bones: Array[int] = []   # os cible dans l'ordre hiérarchique
		for i in tsk.get_bone_count():
			tgt_bones.append(i)
		var hips_src := ssk.find_bone(map["Hips"])
		var hips_tgt := tsk.find_bone("mixamorig_Hips")
		var src_h := ssk.get_bone_global_rest(hips_src).origin.y
		var tgt_h := tsk.get_bone_global_rest(hips_tgt).origin.y
		var scale := tgt_h / maxf(src_h, 0.01)
		print("== ", set_key, " échelle hanches ", snappedf(scale, 0.001), " (", snappedf(src_h, 0.001), " → ", snappedf(tgt_h, 0.001), ")")
		for src_name in PICK[set_key]:
			var spec: Array = PICK[set_key][src_name]
			var sanim := ap.get_animation(src_name)
			var frames := int(ceil(sanim.length * FPS)) + 1
			var out := Animation.new()
			out.length = sanim.length
			out.step = 1.0 / FPS
			out.loop_mode = Animation.LOOP_LINEAR if spec[2] else Animation.LOOP_NONE
			var rot_tracks := {}
			var pos_track := -1
			for i in tsk.get_bone_count():
				var bn := tsk.get_bone_name(i)
				var t := out.add_track(Animation.TYPE_ROTATION_3D)
				out.track_set_path(t, NodePath("Skeleton3D:" + bn))
				rot_tracks[i] = t
			pos_track = out.add_track(Animation.TYPE_POSITION_3D)
			out.track_set_path(pos_track, NodePath("Skeleton3D:mixamorig_Hips"))
			ap.play(src_name)
			var first_hips := Vector3.ZERO
			var hand_idx := ssk.find_bone(map["RightHand"])
			var hand_pts: Array[Vector3] = []
			for f in frames:
				var time := minf(f / FPS, sanim.length)
				ap.seek(time, true)
				await process_frame
				await process_frame
				var global_rot := {}
				for i in tsk.get_bone_count():
					var bn := tsk.get_bone_name(i).trim_prefix("mixamorig_")
					var parent := tsk.get_bone_parent(i)
					var rest_global_t := tsk.get_bone_global_rest(i).basis
					var gt: Basis
					if map.has(bn) and ssk.find_bone(map[bn]) >= 0:
						var si := ssk.find_bone(map[bn])
						var gs := ssk.get_bone_global_pose(si).basis.orthonormalized()
						var rs := ssk.get_bone_global_rest(si).basis.orthonormalized()
						gt = (gs * rs.inverse()) * rest_global_t.orthonormalized()
					else:
						# os sans équivalent : garde sa rotation locale de repos par rapport à son parent
						var pg: Basis = global_rot[parent] if parent >= 0 else Basis.IDENTITY
						gt = pg * tsk.get_bone_rest(i).basis.orthonormalized()
					global_rot[i] = gt
					var local: Basis = (global_rot[parent] as Basis).inverse() * gt if parent >= 0 else gt
					out.rotation_track_insert_key(rot_tracks[i], time, local.get_rotation_quaternion().normalized())
				var hp := ssk.get_bone_global_pose(hips_src).origin
				var hpt := ssk.get_bone_global_pose(hand_idx).origin
				hand_pts.append(hpt - Vector3(hp.x, 0.0, hp.z))
				var rp := ssk.get_bone_global_rest(hips_src).origin
				var pos := tsk.get_bone_rest(hips_tgt).origin + (hp - rp) * scale
				if f == 0:
					first_hips = pos
				if spec[1]:
					pos = Vector3(first_hips.x, pos.y, first_hips.z)   # sur place
				out.position_track_insert_key(pos_track, time, pos)
			ap.stop()
			# instants du geste (comme tools/bake_animations.gd) : début, coup = main la plus rapide, fin
			var speeds: Array[float] = []
			var best := 0.0
			var best_i := 1
			for i in range(1, hand_pts.size()):
				var sp := (hand_pts[i] - hand_pts[i - 1]).length() * FPS
				speeds.append(sp)
				if sp > best:
					best = sp
					best_i = i
			var start_i := 1
			for i in speeds.size():
				if speeds[i] > best * 0.12:
					start_i = i + 1
					break
			var end_i := hand_pts.size() - 1
			for i in range(speeds.size() - 1, -1, -1):
				if speeds[i] > best * 0.12:
					end_i = mini(i + 1 + 6, hand_pts.size() - 1)
					break
			out.set_meta(&"start_time", start_i / FPS)
			out.set_meta(&"peak_time", best_i / FPS)
			out.set_meta(&"end_time", minf(end_i / FPS, sanim.length))
			lib.add_animation(spec[0], out)
			print("  ", src_name, " -> ", spec[0], " ", snappedf(sanim.length, 0.01), "s ", frames, " images")
		src_inst.queue_free()
	var err := ResourceSaver.save(lib, "res://assets/anims/ual_library.res")
	print("SAUVEGARDE ual_library.res : ", "OK" if err == OK else "ERREUR %d" % err)
	quit()
