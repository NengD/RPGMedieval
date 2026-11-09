# -*- coding: utf-8 -*-
"""Accessoires de l'arène (caisses, tonneau, râtelier d'armes, poteau d'entraînement) -> assets/props/*.glb.

  blender -b --factory-startup -P tools/blender/make_props.py -- <dossier_sortie>

Repère : origine au centre de la base, posé sur le sol (Z = 0 en Blender) ; l'avant est vers -Y Blender (= +Z Godot).
Matériaux nommés « bois », « fer », « paille » : le jeu les remplace par les textures PBR (assets/textures/bois…).
Pas de UV : le jeu applique les textures en projection triplanaire.
"""
import sys, os, math
import bpy, bmesh
from mathutils import Vector, Matrix, Euler

OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

_mats = {}


def mat(name, color, metallic=0.0, rough=0.8):
    if name not in _mats:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Base Color"].default_value = (*color, 1.0)
        b.inputs["Metallic"].default_value = metallic
        b.inputs["Roughness"].default_value = rough
        m.diffuse_color = (*color, 1.0)
        _mats[name] = m
    return _mats[name]


BOIS = lambda: mat("bois", (0.4, 0.26, 0.13))
FER = lambda: mat("fer", (0.2, 0.2, 0.22), 0.9, 0.5)
PAILLE = lambda: mat("paille", (0.75, 0.62, 0.3), 0.0, 0.95)


def box(bm, size, loc, rot=(0, 0, 0)):
    m = Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4() @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


def cyl(bm, r1, r2, depth, loc, rot=(0, 0, 0), segs=16):
    m = Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=depth, matrix=m)


def lathe(bm, profile, segs=20):
    rings = []
    for r, z in profile:
        ring = [bm.verts.new((math.cos(2 * math.pi * k / segs) * r, math.sin(2 * math.pi * k / segs) * r, z)) for k in range(segs)]
        rings.append(ring)
    for a, b in zip(rings[:-1], rings[1:]):
        for k in range(segs):
            bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])


def make(name, parts):
    """parts : [(nom, bmesh, matériau, lisse)]"""
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    objs = []
    for pname, bm, material, smooth in parts:
        me = bpy.data.meshes.new(pname)
        bm.normal_update()
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(material)
        if smooth:
            for p in me.polygons:
                p.use_smooth = True
        ob = bpy.data.objects.new(pname, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = root
        objs.append(ob)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = root
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True, export_materials="EXPORT")
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    print("%-22s %4d triangles %5.0f Ko" % (name, tris, os.path.getsize(path) / 1024.0))
    for o in objs:
        me = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(me)
    bpy.data.objects.remove(root)


def crate(name, s):
    bm = bmesh.new()
    h = s
    # planches des quatre côtés + dessus
    for z in (0.18, 0.5, 0.82):
        for (x, y, w, d) in ((0, -h / 2 + 0.01, h, 0.025), (0, h / 2 - 0.01, h, 0.025), (-h / 2 + 0.01, 0, 0.025, h), (h / 2 - 0.01, 0, 0.025, h)):
            box(bm, (w, d, h * 0.3), (x, y, z * h))
    box(bm, (h, h, 0.04 * h), (0, 0, h - 0.02 * h))
    box(bm, (h, h, 0.04 * h), (0, 0, 0.02 * h))
    bm2 = bmesh.new()
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(bm2, (0.07 * h, 0.07 * h, h), (sx * (h / 2 - 0.035 * h), sy * (h / 2 - 0.035 * h), h / 2))
    # diagonale clouée sur la face avant
    box(bm2, (0.09 * h, 0.02, h * 1.2), (0, -h / 2 - 0.005, h / 2), (0, math.radians(38), 0))
    make(name, [(name + "_planches", bm, BOIS(), False), (name + "_montants", bm2, BOIS(), False)])


def barrel():
    bm = bmesh.new()
    lathe(bm, [(0.36, 0.0), (0.42, 0.12), (0.46, 0.35), (0.47, 0.5), (0.46, 0.65), (0.42, 0.88), (0.36, 1.0)], 20)
    bm2 = bmesh.new()
    for z, r in ((0.1, 0.415), (0.3, 0.462), (0.7, 0.462), (0.9, 0.415)):
        cyl(bm2, r + 0.012, r + 0.012, 0.045, (0, 0, z), segs=20)
    make("tonneau", [("tonneau_douelles", bm, BOIS(), True), ("tonneau_cercles", bm2, FER(), True)])


def rack():
    bm = bmesh.new()
    # deux montants, deux traverses, étagère basse ; face avant vers -Y
    for x in (-0.95, 0.95):
        box(bm, (0.1, 0.1, 1.7), (x, 0, 0.85))
        box(bm, (0.1, 0.5, 0.08), (x, 0, 0.04))
    box(bm, (2.0, 0.08, 0.08), (0, 0, 1.6))
    box(bm, (2.0, 0.08, 0.08), (0, 0, 1.1))
    box(bm, (1.9, 0.3, 0.05), (0, -0.12, 0.45))
    box(bm, (1.9, 0.04, 0.3), (0, 0.15, 0.62))
    bm2 = bmesh.new()
    for x in (-0.75, -0.25, 0.25, 0.75):
        cyl(bm2, 0.02, 0.02, 0.18, (x, -0.12, 1.6), (math.radians(90), 0, 0), 8)
        cyl(bm2, 0.02, 0.02, 0.18, (x, -0.12, 1.1), (math.radians(90), 0, 0), 8)
    make("ratelier", [("ratelier_bois", bm, BOIS(), False), ("ratelier_chevilles", bm2, FER(), True)])


def post():
    bm = bmesh.new()
    cyl(bm, 0.13, 0.13, 1.9, (0, 0, 0.95), segs=12)
    box(bm, (0.9, 0.1, 0.1), (0, 0, 1.45))
    box(bm, (0.5, 0.5, 0.15), (0, 0, 0.075))
    bm2 = bmesh.new()
    cyl(bm2, 0.2, 0.2, 0.5, (0, 0, 1.25), segs=14)
    cyl(bm2, 0.1, 0.1, 0.25, (-0.42, 0, 1.45), (0, math.radians(90), 0), 10)
    cyl(bm2, 0.1, 0.1, 0.25, (0.42, 0, 1.45), (0, math.radians(90), 0), 10)
    make("poteau_entrainement", [("poteau_bois", bm, BOIS(), False), ("poteau_paille", bm2, PAILLE(), True)])


crate("caisse", 1.2)
crate("caisse_petite", 0.8)
barrel()
rack()
post()
