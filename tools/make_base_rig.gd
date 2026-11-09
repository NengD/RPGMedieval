extends SceneTree
## Extrait le squelette du corps de base Mixamo (Mannequin) dans assets/base/base_rig.tscn, sans maillage ni textures,
## avec les os renommés « mixamorig_* » (comme le héros d'origine : les animations de hero_library.res s'appliquent telles quelles).
## Source : assets/base/base_body.fbx (téléchargé sur Mixamo ; il n'est plus nécessaire ensuite).
## godot --headless --path . -s tools/make_base_rig.gd
func _initialize() -> void:
	var scene: PackedScene = load("res://assets/base/base_body.fbx")
	var inst := scene.instantiate()
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	for i in sk.get_bone_count():
		sk.set_bone_name(i, sk.get_bone_name(i).replace("mixamorig1_", "mixamorig_"))
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		mi.get_parent().remove_child(mi)
		mi.free()
	for ap in inst.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	var root_node := Node3D.new()
	root_node.name = "BaseRig"
	sk.get_parent().remove_child(sk)
	root_node.add_child(sk)
	sk.owner = root_node
	for c in sk.get_children():
		c.owner = root_node
	var packed := PackedScene.new()
	packed.pack(root_node)
	var err := ResourceSaver.save(packed, "res://assets/base/base_rig.tscn")
	print("base_rig.tscn : ", "OK" if err == OK else "ERREUR %d" % err, " os=", sk.get_bone_count(), " première=", sk.get_bone_name(0))
	quit()
