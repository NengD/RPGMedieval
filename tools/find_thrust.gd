extends SceneTree
## Cherche, parmi toutes les animations de assets/anims, celles où la main droite part nettement VERS L'AVANT
## (poussée / estoc) : déplacement dominé par l'axe avant du personnage (+Z dans le modèle).
## godot --headless --path . -s tools/find_thrust.gd
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
		var hand := sk.find_bone("mixamorig_RightHand")
		ap.play(ap.get_animation_list()[0])
		var n := 60
		var pts: Array = []
		for i in n + 1:
			ap.seek(anim.length * i / n, true)
			await process_frame
			await process_frame
			var hp := sk.get_bone_global_pose(hips).origin
			pts.append(sk.get_bone_global_pose(hand).origin - Vector3(hp.x, 0.0, hp.z))
		var best := 0.0
		var best_t := 0.0
		var best_v := Vector3.ZERO
		var w := maxi(2, int(0.3 / (anim.length / n)))
		for i in range(0, n + 1 - w):
			var d: Vector3 = pts[i + w] - pts[i]
			var forward := d.z
			var lateral := Vector2(d.x, d.y).length()
			if forward > 0.45 and forward > lateral * 1.6 and forward > best:
				best = forward
				best_t = anim.length * i / n
				best_v = d
		print("%-50s %s" % [f.get_basename(), ("POUSSÉE %.2f m vers l'avant à %.2fs (latéral %.2f)" % [best, best_t, Vector2(best_v.x, best_v.y).length()]) if best > 0.0 else "-"])
		inst.queue_free()
	quit()
