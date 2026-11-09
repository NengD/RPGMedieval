import bpy, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath="E:/_jeu perso/rpgmedieval/assets/base/base_body.fbx")
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
mesh = next(o for o in bpy.data.objects if o.type == "MESH")
print("ARM", arm.name, "scale", tuple(arm.scale), "loc", tuple(arm.location), "rot", tuple(arm.rotation_euler))
print("MESH", mesh.name, "parent", mesh.parent.name if mesh.parent else None, "scale", tuple(mesh.scale), "dims", tuple(mesh.dimensions), "verts", len(mesh.data.vertices))
print("BONES", len(arm.data.bones), [b.name for b in arm.data.bones][:6])
vg = [g.name for g in mesh.vertex_groups]
print("VGROUPS", len(vg), vg[:5])
import mathutils
mw = mesh.matrix_world
zs = [ (mw @ v.co) for v in mesh.data.vertices ]
print("WORLD bbox min", tuple(min(p[i] for p in zs) for i in range(3)), "max", tuple(max(p[i] for p in zs) for i in range(3)))
for n in ("mixamorig1:Hips","mixamorig1:LeftHand","mixamorig1:Head"):
    b = arm.data.bones.get(n)
    if b: print(n, "head world", tuple(arm.matrix_world @ b.head_local))
print("MATERIALS", [m.name for m in mesh.data.materials])
