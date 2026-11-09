extends SceneTree
func _initialize() -> void:
	for cls in ["LookAtModifier3D", "PhysicalBone3D", "PhysicalBoneSimulator3D"]:
		var props := []
		for p in ClassDB.class_get_property_list(cls, true):
			props.append(p.name)
		print(cls, " : ", ", ".join(props))
	print("BONE AXES: ", ClassDB.class_get_enum_constants("SkeletonModifier3D", "BoneAxis") if ClassDB.class_has_enum("SkeletonModifier3D", "BoneAxis") else "pas dans SkeletonModifier3D")
	print("LookAt enums: ", ClassDB.class_get_enum_list("LookAtModifier3D", true))
	var rig := (load("res://assets/base/base_rig.tscn") as PackedScene).instantiate()
	root.add_child(rig)
	var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	for b in ["mixamorig_Head", "mixamorig_Spine2", "mixamorig_Hips"]:
		var g := sk.global_transform * sk.get_bone_global_rest(sk.find_bone(b))
		print(b, " axes monde : X=", g.basis.x.snapped(Vector3(0.01, 0.01, 0.01)), " Y=", g.basis.y.snapped(Vector3(0.01, 0.01, 0.01)), " Z=", g.basis.z.snapped(Vector3(0.01, 0.01, 0.01)))
	quit()
