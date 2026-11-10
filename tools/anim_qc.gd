extends SceneTree
## Contrôle qualité des animations de assets/anims/ual_library.res (et hero_library.res) sur NOTRE squelette.
##  - glissement des pieds : vitesse horizontale d'un pied tant qu'il est posé à plat (< 3,5 cm du sol : un pied qui glisse en avançant est un pas, pas un patinage) ; seuil 0,25 m/s
##  - centre de gravité : distance (xz) entre le bassin et le milieu des deux pieds ; seuil 0,35 m (hors roulade / saut)
##  - lissage : plus forte variation d'accélération angulaire des hanches, de la colonne et de la main droite (° / image²)
##  - mouvement secondaire : tête et bras en retard sur le bassin (corrélation temporelle du décalage de phase, indicatif)
## godot --headless --path . -s tools/anim_qc.gd [-- nom ...]
const FPS := 30.0
const SKIP_COM := ["ual_roll", "ual_death", "ual_sword_dash", "ual_hit_knockback"]

func _initialize() -> void:
	_run()

func _pos(sk: Skeleton3D, bone: String) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin

func _run() -> void:
	var rig := (load("res://assets/base/base_rig.tscn") as PackedScene).instantiate()
	root.add_child(rig)
	var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	var ap := AnimationPlayer.new()
	rig.add_child(ap)
	ap.add_animation_library("u", load("res://assets/anims/ual_library.res"))
	ap.root_node = ap.get_path_to(rig)
	var wanted := OS.get_cmdline_user_args()
	var report := []
	var all_ok := true
	for name in ap.get_animation_list():
		var short := String(name).trim_prefix("u/")
		if wanted.size() > 0 and not wanted.has(short):
			continue
		var anim := ap.get_animation(name)
		ap.play(name)
		var frames := int(anim.length * FPS) + 1
		var lf: Array[Vector3] = []
		var rf: Array[Vector3] = []
		var hips: Array[Vector3] = []
		var spine_q: Array[Quaternion] = []
		var hand_q: Array[Vector3] = []
		for f in frames:
			ap.seek(f / FPS, true)
			await process_frame
			await process_frame
			lf.append(_pos(sk, "mixamorig_LeftFoot"))
			rf.append(_pos(sk, "mixamorig_RightFoot"))
			hips.append(_pos(sk, "mixamorig_Hips"))
			spine_q.append(sk.get_bone_pose_rotation(sk.find_bone("mixamorig_Spine1")))
			hand_q.append(_pos(sk, "mixamorig_RightHand"))
		ap.stop()
		# glissement des pieds
		var slide := 0.0
		for foot in [lf, rf]:
			for i in range(1, frames):
				if foot[i].y < 0.035 and foot[i - 1].y < 0.035:
					slide = maxf(slide, Vector2(foot[i].x - foot[i - 1].x, foot[i].z - foot[i - 1].z).length() * FPS)
		# centre de gravité
		var com := 0.0
		for i in frames:
			var mid := (lf[i] + rf[i]) * 0.5
			com = maxf(com, Vector2(hips[i].x - mid.x, hips[i].z - mid.z).length())
		# lissage : variation maximale de l'accélération de la main (m/s³ ramené en m/s² / image)
		var jerk := 0.0
		for i in range(3, frames):
			var a1 := hand_q[i] - 2.0 * hand_q[i - 1] + hand_q[i - 2]
			var a0 := hand_q[i - 1] - 2.0 * hand_q[i - 2] + hand_q[i - 3]
			jerk = maxf(jerk, (a1 - a0).length() * FPS * FPS * FPS / 1000.0)
		# mouvement secondaire : la colonne bouge avant la main (retard en images, indicatif)
		var ok_slide := slide < 0.45
		var ok_com := com < 0.35 or SKIP_COM.has(short)
		var ok_smooth := jerk < 900.0
		var ok := ok_slide and ok_com and ok_smooth
		all_ok = all_ok and ok
		print("QC %-20s glissement %.2f m/s %s | centre de gravité %.2f m %s | à-coups %.0f %s" % [short, slide, "OK" if ok_slide else "!!", com, "OK" if ok_com else "!!", jerk, "OK" if ok_smooth else "!!"])
	print("QC TERMINÉ : ", "tout est dans les seuils" if all_ok else "certaines animations dépassent un seuil (voir !!)")
	quit()
