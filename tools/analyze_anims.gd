extends SceneTree
## Analyse toutes les animations de assets/anims/ : durée, déplacement de la racine,
## trajectoire de la main droite (pour reconnaître haut / côté / estoc) et instant de l'impact.
## godot --headless --path . -s tests/analyze_anims.gd

func _initialize() -> void:
	_run()


func _run() -> void:
	var dir := DirAccess.open("res://assets/anims")
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".fbx"):
			files.append(f)
	files.sort()
	for f in files:
		await _analyze("res://assets/anims/" + f, f.get_basename())
	quit()


func _analyze(path: String, label: String) -> void:
	var scene: PackedScene = load(path)
	if scene == null:
		print(label, " : IMPOSSIBLE À CHARGER")
		return
	var inst := scene.instantiate()
	root.add_child(inst)
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var anim_name := ap.get_animation_list()[0]
	var anim := ap.get_animation(anim_name)
	var hips := sk.find_bone("mixamorig_Hips")
	var hand := sk.find_bone("mixamorig_RightHand")
	var steps := 24
	ap.play(anim_name)
	var hips0 := Vector3.ZERO
	var prev := Vector3.ZERO
	var best_speed := 0.0
	var best_t := 0.0
	var hand_min := Vector3(1e9, 1e9, 1e9)
	var hand_max := Vector3(-1e9, -1e9, -1e9)
	var hips_end := Vector3.ZERO
	var first_hand := Vector3.ZERO
	var last_hand := Vector3.ZERO
	var y_peak_t := 0.0
	var y_peak := -1e9
	for i in range(steps + 1):
		var t := anim.length * float(i) / float(steps)
		ap.seek(t, true)
		await process_frame
		await process_frame
		var hp := sk.get_bone_global_pose(hips).origin
		var hd := sk.get_bone_global_pose(hand).origin - Vector3(hp.x, 0.0, hp.z)   # sans le déplacement de la racine
		if i == 0:
			hips0 = hp
			first_hand = hd
			prev = hd
		else:
			var speed := (hd - prev).length() / (anim.length / steps)
			if speed > best_speed:
				best_speed = speed
				best_t = t
			prev = hd
		hand_min = hand_min.min(hd)
		hand_max = hand_max.max(hd)
		if hd.y > y_peak:
			y_peak = hd.y
			y_peak_t = t
		hips_end = hp
		last_hand = hd
	var root_move := hips_end - hips0
	print("%-34s dur=%.2fs  racine(x=%+.2f y=%+.2f z=%+.2f)  main: x[%+.2f..%+.2f] y[%+.2f..%+.2f] z[%+.2f..%+.2f]  impact~%.2fs (%.0f%%) vitesse=%.1f  main_haute@%.2fs" % [
		label, anim.length, root_move.x, root_move.y, root_move.z,
		hand_min.x, hand_max.x, hand_min.y, hand_max.y, hand_min.z, hand_max.z,
		best_t, 100.0 * best_t / anim.length, best_speed, y_peak_t])
	inst.queue_free()
