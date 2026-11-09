class_name CharacterSave
extends RefCounted
## État sauvegardé d'un personnage (héros, ennemi, mannequin) : position, orientation et tout son Combatant.


static func capture(body: Node3D, c: Combatant) -> Dictionary:
	var p := body.global_position
	return {
		"position": [p.x, p.y, p.z],
		"yaw": body.global_rotation.y,
		"combat": c.capture_state(),
	}


static func restore(body: Node3D, c: Combatant, d: Dictionary) -> void:
	var pos: Array = d.get("position", [])
	if pos.size() == 3:
		body.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	body.global_rotation.y = float(d.get("yaw", body.global_rotation.y))
	if "velocity" in body:
		body.velocity = Vector3.ZERO
	c.restore_state(d.get("combat", {}))
