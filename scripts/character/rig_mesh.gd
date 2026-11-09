class_name RigMesh
extends RefCounted
## Rattache les maillages d'un .glb (corps de base, pièces d'armure) au squelette du jeu.
## Les .glb viennent de Blender (tools/blender/make_armor.py) avec leur propre squelette ; on ne garde que les
## maillages et on remappe leurs indices d'os sur le squelette du jeu PAR NOM d'os (mixamorig_*). Ainsi les
## animations (qui dépendent du squelette d'origine) restent valides, quel que soit le squelette du .glb.


## Retourne les MeshInstance3D créés (enfants de `parent`, qui doit être le squelette ou un de ses descendants).
static func attach(skeleton: Skeleton3D, scene: PackedScene, parent: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var inst := scene.instantiate()
	var skin := skeleton.create_skin_from_rest_transforms()
	for src in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := src as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		var remap := PackedInt32Array()
		for i in mi.skin.get_bind_count():
			var bone_name := String(mi.skin.get_bind_name(i))
			var idx := skeleton.find_bone(bone_name)
			remap.append(idx if idx >= 0 else 0)
		var src_mesh := mi.mesh as ArrayMesh
		var new_mesh := ArrayMesh.new()
		for s in src_mesh.get_surface_count():
			var arrays := src_mesh.surface_get_arrays(s)
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			for k in bones.size():
				bones[k] = remap[bones[k]]
			arrays[Mesh.ARRAY_BONES] = bones
			var fmt := src_mesh.surface_get_format(s)
			new_mesh.add_surface_from_arrays(src_mesh.surface_get_primitive_type(s), arrays, [], {}, fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			new_mesh.surface_set_material(s, src_mesh.surface_get_material(s))
		var node := MeshInstance3D.new()
		node.name = mi.name
		node.mesh = new_mesh
		node.skin = skin
		node.transform = Transform3D.IDENTITY
		parent.add_child(node)
		node.skeleton = node.get_path_to(skeleton)
		out.append(node)
	inst.free()
	return out
