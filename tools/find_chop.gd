extends SceneTree
## Cherche un coup d'en haut : la main droite part haut et descend vite, presque à la verticale.
## godot --headless --path . -s tools/find_chop.gd
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
		var n := 80
		var pts: Array = []
		var hips_y: Array = []
		for i in n + 1:
			ap.seek(anim.length * i / n, true)
			await process_frame
			await process_frame
			var hp := sk.get_bone_global_pose(hips).origin
			hips_y.append(hp.y)
			pts.append(sk.get_bone_global_pose(hand).origin - Vector3(hp.x, 0.0, hp.z))
		var w := maxi(2, int(0.35 / (anim.length / n)))
		var best := 0.0
		var best_t := 0.0
		var info := ""
		for i in range(0, n + 1 - w):
			var d: Vector3 = pts[i + w] - pts[i]
			var side := Vector2(d.x, d.z).length()
			if pts[i].y > 1.45 and -d.y > 0.7 and side < -d.y * 0.7 and -d.y > best:
				best = -d.y
				best_t = anim.length * i / n
				info = "main de %.2f à %.2f m (côté %.2f)" % [pts[i].y, pts[i + w].y, side]
		if best > 0.0:
			print("CHOP %-48s à %.2fs : descente %.2f m  %s" % [f.get_basename(), best_t, best, info])
		inst.queue_free()
	print("fin")
	quit()
