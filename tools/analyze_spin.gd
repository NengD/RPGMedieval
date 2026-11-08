extends SceneTree
## Mesure de combien le corps (hanches) PIVOTE sur lui-même pendant un clip (en degrés) : les clips qui tournent
## beaucoup donnent un "tourbillon" en jeu.  godot --headless --path . -s tools/analyze_spin.gd
func _initialize() -> void:
	_run()
func _run() -> void:
	var dir := DirAccess.open("res://assets/anims")
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".fbx") and ("attack" in f or "slash" in f or "combo" in f):
			files.append(f)
	files.sort()
	for f in files:
		var inst: Node = (load("res://assets/anims/" + f) as PackedScene).instantiate()
		root.add_child(inst)
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
		var anim := ap.get_animation(ap.get_animation_list()[0])
		var hips := sk.find_bone("mixamorig_Hips")
		ap.play(ap.get_animation_list()[0])
		var n := 60
		var yaw0 := 0.0
		var prev := 0.0
		var total := 0.0
		var lo := 0.0
		var hi := 0.0
		for i in n + 1:
			ap.seek(anim.length * i / n, true)
			await process_frame
			await process_frame
			var b := sk.get_bone_global_pose(hips).basis
			var yaw := atan2(b.z.x, b.z.z)
			if i == 0:
				yaw0 = yaw
				prev = yaw
			total += angle_difference(prev, yaw)
			prev = yaw
			lo = minf(lo, total)
			hi = maxf(hi, total)
		print("SPIN %-52s  rotation du corps : de %+4.0f° à %+4.0f° (amplitude %3.0f°)" % [f.get_basename(), rad_to_deg(lo), rad_to_deg(hi), rad_to_deg(hi - lo)])
		inst.queue_free()
	quit()
