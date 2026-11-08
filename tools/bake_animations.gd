extends SceneTree
## Prépare la bibliothèque d'animations du personnage à partir du pack Mixamo (assets/anims/*.fbx).
## - donne des noms clairs aux animations ;
## - les rend "sur place" (retire le déplacement avant/côté de la racine) quand il le faut ;
## - règle les boucles ;
## - mesure l'instant où la main frappe (pour caler l'animation sur le coup).
## Résultat : res://assets/anims/hero_library.res
## Lancer : godot --headless --path . -s tools/bake_animations.gd

const HIPS_TRACK := "Skeleton3D:mixamorig_Hips"
const HAND := "mixamorig_RightHand"
const HIPS := "mixamorig_Hips"

# nom dans le jeu : [fichier du pack, sur place ?, boucle ?, mesurer le coup ?]
const MAP := {
	&"idle": ["sword_and_shield_idle", true, true, false],
	&"walk_f": ["sword_and_shield_walk", true, true, false],
	&"walk_b": ["sword_and_shield_walk_2", true, true, false],
	&"run_f": ["sword_and_shield_run", true, true, false],
	&"run_b": ["sword_and_shield_run_2", true, true, false],
	&"strafe_r": ["sword_and_shield_strafe", true, true, false],
	&"strafe_l": ["sword_and_shield_strafe_2", true, true, false],
	&"strafe_l_run": ["sword_and_shield_strafe_3", true, true, false],
	&"strafe_r_run": ["sword_and_shield_strafe_4", true, true, false],
	&"dodge_l": ["sword_and_shield_strafe_3", true, false, false],
	&"dodge_r": ["sword_and_shield_strafe_4", true, false, false],
	&"dodge_b": ["sword_and_shield_run_2", true, false, false],
	&"attack_up": ["axe_standing_melee_attack_downward", true, false, true, 0.1, 2.0],   # coup vertical de haut en bas
	&"attack_right": ["axe_standing_melee_attack_horizontal", true, false, true, 0.1, 2.2],   # balayage horizontal
	&"attack_estoc": ["axe_standing_melee_combo_attack_ver__3", true, false, true, 0.55, 1.6],   # fente avec poussée (fin du combo 3)
	&"attack_left": ["axe_standing_melee_attack_backhand", true, false, true, 0.1, 2.8],   # revers (de l'autre côté)
	&"guard": ["sword_and_shield_block_idle", true, true, false],
	&"hit_1": ["sword_and_shield_impact", true, false, false],
	&"hit_2": ["sword_and_shield_impact_2", true, false, false],
	&"hit_3": ["sword_and_shield_impact_3", true, false, false],
	&"death": ["sword_and_shield_death", false, false, false],
	&"jump": ["sword_and_shield_jump_2", true, false, false],
}


func _initialize() -> void:
	_run()


func _run() -> void:
	var lib := AnimationLibrary.new()
	for key in MAP:
		var spec: Array = MAP[key]
		var scene: PackedScene = load("res://assets/anims/%s.fbx" % spec[0])
		if scene == null:
			print("MANQUANT : ", spec[0])
			continue
		var inst := scene.instantiate()
		root.add_child(inst)
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		var anim: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate(true)
		if spec[1]:
			_make_in_place(anim)
		anim.loop_mode = Animation.LOOP_LINEAR if spec[2] else Animation.LOOP_NONE
		if spec[3]:
			var t_min: float = spec[4] if spec.size() > 4 else 0.0
			var t_max: float = spec[5] if spec.size() > 5 else anim.length
			var prof := await _profile(ap, sk, t_min, minf(t_max, anim.length))
			anim.set_meta(&"start_time", prof[0])
			anim.set_meta(&"peak_time", prof[1])
			anim.set_meta(&"end_time", prof[2])
		lib.add_animation(key, anim)
		print("%-14s %-30s %.2fs%s" % [key, spec[0], anim.length, ("  début %.2f  coup %.2f  fin %.2f" % [anim.get_meta(&"start_time"), anim.get_meta(&"peak_time"), anim.get_meta(&"end_time")]) if anim.has_meta(&"peak_time") else ""])
		inst.queue_free()
	var err := ResourceSaver.save(lib, "res://assets/anims/hero_library.res")
	print("SAUVEGARDE : ", "OK" if err == OK else "ERREUR %d" % err)
	quit(0 if err == OK else 1)


## La racine (hanches) ne doit plus avancer : on fige X et Z à la valeur de départ, on garde la hauteur.
func _make_in_place(anim: Animation) -> void:
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_POSITION_3D and str(anim.track_get_path(i)) == HIPS_TRACK:
			var first: Vector3 = anim.track_get_key_value(i, 0)
			for k in anim.track_get_key_count(i):
				var v: Vector3 = anim.track_get_key_value(i, k)
				anim.track_set_key_value(i, k, Vector3(first.x, v.y, first.z))


## Profil du geste : [début du mouvement, instant du coup (main la plus rapide), fin du geste] dans la fenêtre [t_min, t_max].
## Mesuré sur la main droite par rapport aux hanches.
func _profile(ap: AnimationPlayer, sk: Skeleton3D, t_min: float, t_max: float) -> Array:
	var hips := sk.find_bone(HIPS)
	var hand := sk.find_bone(HAND)
	ap.play(ap.get_animation_list()[0])
	var step := 0.03
	var times: Array = []
	var speeds: Array = []
	var prev := Vector3.ZERO
	var t := t_min
	var first := true
	while t <= t_max:
		ap.seek(t, true)
		await process_frame
		await process_frame
		var hp := sk.get_bone_global_pose(hips).origin
		var hd := sk.get_bone_global_pose(hand).origin - Vector3(hp.x, 0.0, hp.z)
		if not first:
			times.append(t)
			speeds.append((hd - prev).length() / step)
		prev = hd
		first = false
		t += step
	var best := 0.0
	var best_t := t_min
	for i in speeds.size():
		if speeds[i] > best:
			best = speeds[i]
			best_t = times[i]
	var start := t_min
	var end := t_max
	for i in speeds.size():
		if speeds[i] > best * 0.12:
			start = times[i]
			break
	for i in range(speeds.size() - 1, -1, -1):
		if speeds[i] > best * 0.12:
			end = minf(times[i] + 0.2, t_max)
			break
	return [start, best_t, end]
