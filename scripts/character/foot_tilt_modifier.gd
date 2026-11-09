class_name FootTiltModifier
extends SkeletonModifier3D
## Incline la cheville pour que la semelle suive la pente du sol. À placer APRÈS les TwoBoneIK3D des jambes.
## `normal_world` : normale du sol sous le pied (monde) ; `amount` : part appliquée (0 = pied tel qu'animé).

@export var bone_name := "mixamorig_LeftFoot"
var normal_world := Vector3.UP
var amount := 0.0


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or amount <= 0.001:
		return
	var idx := sk.find_bone(bone_name)
	if idx < 0:
		return
	var pose := sk.get_bone_global_pose(idx)
	var up_local := (sk.global_transform.basis.inverse() * Vector3.UP).normalized()
	var n_local := (sk.global_transform.basis.inverse() * normal_world).normalized()
	var tilt := Quaternion(up_local, n_local)          # de l'horizontale à la pente
	tilt = Quaternion.IDENTITY.slerp(tilt, amount)
	sk.set_bone_global_pose(idx, Transform3D(Basis(tilt) * pose.basis, pose.origin))
