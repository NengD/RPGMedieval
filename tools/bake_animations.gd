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
	&"attack_up": ["sword_and_shield_slash_4", true, false, true],
	&"attack_right": ["sword_and_shield_slash_5", true, false, true],
	&"attack_estoc": ["sword_and_shield_attack_4", true, false, true],
	&"attack_left": ["sword_and_shield_slash_3", true, false, true],
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
			var peak := await _peak_time(ap, sk)
			anim.set_meta(&"peak_time", peak)
		lib.add_animation(key, anim)
		print("%-14s %-30s %.2fs%s" % [key, spec[0], anim.length, ("  coup@%.2fs" % anim.get_meta(&"peak_time")) if anim.has_meta(&"peak_time") else ""])
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


## Instant où la main droite va le plus vite (= le coup), mesuré par rapport aux hanches.
func _peak_time(ap: AnimationPlayer, sk: Skeleton3D) -> float:
	var anim := ap.get_animation(ap.get_animation_list()[0])
	var hips := sk.find_bone(HIPS)
	var hand := sk.find_bone(HAND)
	ap.play(ap.get_animation_list()[0])
	var steps := 40
	var prev := Vector3.ZERO
	var best_speed := 0.0
	var best_t := 0.0
	for i in steps + 1:
		var t := anim.length * i / steps
		ap.seek(t, true)
		await process_frame
		await process_frame
		var hp := sk.get_bone_global_pose(hips).origin
		var hd := sk.get_bone_global_pose(hand).origin - Vector3(hp.x, 0.0, hp.z)
		if i > 0:
			var speed: float = (hd - prev).length()
			if speed > best_speed:
				best_speed = speed
				best_t = t
		prev = hd
	return best_t
