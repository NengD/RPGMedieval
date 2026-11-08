extends SceneTree
## Affiche la structure d'un modèle importé : godot --headless --path . -s tests/inspect_fbx.gd -- res://assets/hero/hero.fbx
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://assets/hero/hero.fbx"
	var scene: PackedScene = load(path)
	if scene == null:
		print("IMPOSSIBLE DE CHARGER ", path)
		quit(1)
		return
	var inst := scene.instantiate()
	root.add_child(inst)
	_dump(inst, 0)
	for n in inst.find_children("*", "AnimationPlayer", true, false):
		var ap := n as AnimationPlayer
		for lib in ap.get_animation_library_list():
			for a in ap.get_animation_library(lib).get_animation_list():
				var anim := ap.get_animation(a)
				print("ANIM [", lib, "] ", a, "  durée=", snappedf(anim.length, 0.01), " pistes=", anim.get_track_count())
	for n in inst.find_children("*", "Skeleton3D", true, false):
		var sk := n as Skeleton3D
		print("SKELETON ", sk.get_path(), " os=", sk.get_bone_count())
		var names := []
		for i in sk.get_bone_count():
			names.append(sk.get_bone_name(i))
		print(", ".join(names.slice(0, 30)))
	quit()
func _dump(n: Node, depth: int) -> void:
	if depth > 3: return
	print("  ".repeat(depth), n.name, " (", n.get_class(), ")")
	for c in n.get_children():
		_dump(c, depth + 1)
