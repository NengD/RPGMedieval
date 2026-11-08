class_name HandAimModifier
extends SkeletonModifier3D
## Oriente la lame de l'épée : fait tourner l'os de la main pour que la lame (axe X local de la main)
## pointe dans la direction voulue (en repère monde). À placer APRÈS le TwoBoneIK3D du bras.

@export var bone_name := "mixamorig_RightHand"
var target_direction_world := Vector3.FORWARD


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var idx := sk.find_bone(bone_name)
	if idx < 0:
		return
	var pose := sk.get_bone_global_pose(idx)
	var current := pose.basis.x.normalized()
	var wanted := (sk.global_transform.basis.inverse() * target_direction_world).normalized()
	if current.length() < 0.001 or wanted.length() < 0.001:
		return
	var rotation := Quaternion(current, wanted)   # plus court chemin entre la lame actuelle et la direction voulue
	sk.set_bone_global_pose(idx, Transform3D(Basis(rotation) * pose.basis, pose.origin))
