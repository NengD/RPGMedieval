extends SceneTree
## Liste les animations et le squelette d'un .glb : godot --headless --path . -s tools/list_glb_anims.gd -- res://chemin.glb
func _initialize() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var inst := (load(path) as PackedScene).instantiate()
	root.add_child(inst)
	for n in inst.find_children("*", "AnimationPlayer", true, false):
		var ap := n as AnimationPlayer
		for a in ap.get_animation_list():
			var anim := ap.get_animation(a)
			print("ANIM ", a, " ", snappedf(anim.length, 0.01), "s pistes=", anim.get_track_count())
	for n in inst.find_children("*", "Skeleton3D", true, false):
		var sk := n as Skeleton3D
		print("SKEL os=", sk.get_bone_count())
		var names := []
		for i in sk.get_bone_count():
			names.append(sk.get_bone_name(i))
		print("OS ", ", ".join(names))
	quit()
