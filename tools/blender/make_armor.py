# -*- coding: utf-8 -*-
"""Fabrique le corps de base (en régions) et les pièces d'armure / d'habit du lot 1, exportés en .glb.

Lancer (nouvelle scène, ne touche à aucun .blend ouvert) :
  blender -b --factory-startup -P tools/blender/make_armor.py -- <fbx du corps> <dossier base> <dossier armure>

Principe : chaque pièce est une COQUE du corps de base (mêmes sommets, mêmes poids de peau) décalée le long des
normales, donc elle épouse le corps et suit exactement le même squelette. Les pièces rigides (plaques) ont leurs
poids limités à quelques os ; les pièces souples (vêtements, gambison, mailles) gardent les poids naturels.
Dans Godot, seuls les maillages sont utilisés : ils sont rattachés au squelette du jeu par NOM d'os
(`mixamorig_*`), voir scripts/character/rig_mesh.gd.
"""
import sys, os, math
import bpy, bmesh
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
FBX, OUT_BASE, OUT_ARMOR = argv[0], argv[1], argv[2]
os.makedirs(OUT_BASE, exist_ok=True)
os.makedirs(OUT_ARMOR, exist_ok=True)

# ------------------------------------------------------------------ import et mise à l'échelle
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=FBX)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = next(o for o in bpy.data.objects if o.type == "MESH")
# la géométrie passe en repère monde (mètres, pose en T) ; l'armature et le maillage n'ont plus de transformation
body.data.transform(body.matrix_world)
body.parent = None
body.matrix_world = Matrix.Identity(4)
arm.data.transform(arm.matrix_world)
arm.matrix_world = Matrix.Identity(4)
for m in list(body.modifiers):
    body.modifiers.remove(m)
for b in arm.data.bones:
    b.name = b.name.replace("mixamorig1:", "mixamorig_")
for g in body.vertex_groups:
    g.name = g.name.replace("mixamorig1:", "mixamorig_")
GROUPS = [g.name for g in body.vertex_groups]
GROUP_INDEX = {n: i for i, n in enumerate(GROUPS)}

# ------------------------------------------------------------------ régions du corps
def region_of(bone):
    b = bone.replace("mixamorig_", "")
    for side in ("Left", "Right"):
        b = b.replace(side, "")
    if b in ("Head", "Neck", "HeadTop_End") or b.startswith("Head"):
        return "head"
    if b.startswith("Spine") or b == "Shoulder":
        return "torso"
    if b == "Hips":
        return "hips"
    if b == "Arm":
        return "upper_arm"
    if b == "ForeArm":
        return "forearm"
    if b.startswith("Hand"):
        return "hand"
    if b == "UpLeg":
        return "thigh"
    if b == "Leg":
        return "shin"
    if b.startswith("Foot") or b.startswith("Toe"):
        return "foot"
    return "torso"


REGIONS = ["head", "torso", "hips", "upper_arm", "forearm", "hand", "thigh", "shin", "foot"]

# ------------------------------------------------------------------ matériaux
_mats = {}


def mat(name, color, metallic=0.0, rough=0.7):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*color, 1.0)
    m.use_backface_culling = False
    _mats[name] = m
    return m


MATS = {
    "peau": lambda: mat("peau", (0.74, 0.55, 0.43), 0.0, 0.65),
    "lin": lambda: mat("teinte_lin", (0.80, 0.76, 0.64), 0.0, 0.95),
    "gambison": lambda: mat("teinte_gambison", (0.66, 0.58, 0.44), 0.0, 0.95),
    "cuir": lambda: mat("cuir", (0.22, 0.13, 0.07), 0.0, 0.85),
    "mailles": lambda: mat("mailles", (0.30, 0.31, 0.35), 0.9, 0.6),
    "acier": lambda: mat("acier_plaques", (0.42, 0.44, 0.49), 0.9, 0.5),
    "tabard": lambda: mat("teinte_tabard", (0.85, 0.85, 0.85), 0.0, 0.9),
}

# ------------------------------------------------------------------ outils bmesh
Y_FRONT = -1.0   # l'avant du personnage est vers -Y (Blender) = +Z (modèle Mixamo)


class Src:
    """Le corps de base lu une fois : région dominante de chaque sommet, normales."""

    def __init__(self):
        self.me = body.data
        self.dom = []        # sommet -> os dominant
        self.reg = []        # sommet -> région
        for v in self.me.vertices:
            best = None
            for g in v.groups:
                if best is None or g.weight > best[1]:
                    best = (g.group, g.weight)
            name = GROUPS[best[0]] if best else "mixamorig_Hips"
            self.dom.append(name)
            self.reg.append(region_of(name))


SRC = Src()


def fresh():
    bm = bmesh.new()
    bm.from_mesh(SRC.me)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    bm.normal_update()
    return bm


def face_regions(f):
    return [SRC.reg[v.index] for v in f.verts]


def majority(f):
    rs = face_regions(f)
    return max(set(rs), key=rs.count)


def center(f):
    return f.calc_center_median()


def keep_faces(bm, pred):
    """Ne garde que les faces pour lesquelles pred(face) est vrai ; mémorise les normales d'origine."""
    normals = {v: v.normal.copy() for v in bm.verts}
    doms = {v: SRC.dom[v.index] for v in bm.verts}
    drop = [f for f in bm.faces if not pred(f)]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    return normals, doms


def inflate(bm, normals, offset):
    for v in bm.verts:
        o = offset(v.co) if callable(offset) else offset
        v.co += normals[v] * o


def side_of(co):
    return "Left" if co.x > 0 else "Right"


def set_weights(bm, mode, doms):
    """mode : None (poids naturels) | ('rigid', 'Spine2') | ('limit', ['Spine', 'Spine1'])  ({S} = Left/Right selon le côté)."""
    if mode is None:
        return
    dl = bm.verts.layers.deform.verify()
    kind, arg = mode
    for v in bm.verts:
        d = v[dl]
        if kind == "rigid":
            bone = "mixamorig_" + arg.replace("{S}", side_of(v.co))
            d.clear()
            d[GROUP_INDEX[bone]] = 1.0
        else:
            allowed = {GROUP_INDEX["mixamorig_" + a.replace("{S}", side_of(v.co))] for a in arg}
            kept = {k: w for k, w in d.items() if k in allowed}
            d.clear()
            if not kept:
                kept = {GROUP_INDEX["mixamorig_" + arg[0].replace("{S}", side_of(v.co))]: 1.0}
            total = sum(kept.values())
            for k, w in kept.items():
                d[k] = w / total


def to_object(name, bm, material, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for g in GROUPS:
        ob.vertex_groups.new(name=g)
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return ob


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_skins=True, export_animations=False,
                              export_cameras=False, export_lights=False, export_materials="EXPORT")


def discard(objs):
    for o in objs:
        me = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(me)


# ------------------------------------------------------------------ corps de base en régions
def build_body():
    objs = []
    for r in REGIONS:
        bm = fresh()
        keep_faces(bm, lambda f, r=r: majority(f) == r)
        if len(bm.faces) == 0:
            bm.free()
            continue
        objs.append(to_object("corps_" + r, bm, MATS["peau"]()))
    export(objs, os.path.join(OUT_BASE, "body.glb"))
    tris = sum(len(o.data.polygons) for o in objs)
    print("CORPS : %d régions, %d polygones" % (len(objs), tris))
    discard(objs)


# ------------------------------------------------------------------ pièces
Z = lambda f: f.calc_center_median().z


def piece(pid, pred, offset, material, weights=None, pattern=None, smooth=True):
    bm = fresh()
    normals, doms = keep_faces(bm, pred)
    off = offset
    if pattern is not None:
        base = offset
        off = lambda co: base + pattern(co)
    inflate(bm, normals, off)
    set_weights(bm, weights, doms)
    name = pid.replace(".", "_")
    ob = to_object(name, bm, material, smooth)
    path = os.path.join(OUT_ARMOR, name + ".glb")
    export([ob], path)
    n = len(ob.data.polygons)
    print("%-28s %5d polygones %6.0f Ko" % (pid, n, os.path.getsize(path) / 1024.0))
    discard([ob])


def quilt(co):          # matelassage du gambison
    return 0.004 * math.sin(co.z * 70.0) * math.sin((co.x + co.y) * 55.0)


def mail(co):           # texture de mailles (relief fin)
    return 0.0025 * math.sin(co.z * 140.0) * math.sin(co.x * 140.0 + co.y * 90.0)


def ridge(co):          # arête centrale de la cuirasse
    return 0.02 * max(0.0, 1.0 - abs(co.x) / 0.07) * (1.0 if co.y < 0 else 0.3)


def build_pieces():
    R = lambda f: majority(f)
    # --- vêtements
    piece("armure.chemise", lambda f: R(f) in ("torso", "upper_arm", "forearm"), 0.006, MATS["lin"]())
    piece("armure.braies", lambda f: R(f) in ("hips", "thigh") or (R(f) == "shin" and Z(f) > 0.45), 0.006, MATS["lin"]())
    piece("armure.gants_cuir", lambda f: R(f) == "hand", 0.006, MATS["cuir"]())
    piece("armure.bottes_cuir", lambda f: R(f) == "foot" or (R(f) == "shin" and Z(f) < 0.42), 0.011, MATS["cuir"]())
    # --- gambison
    piece("armure.gambison", lambda f: R(f) in ("torso", "upper_arm", "forearm") or (R(f) == "hips" and Z(f) > 0.8), 0.02, MATS["gambison"](), pattern=quilt)
    # --- mailles
    piece("armure.haubert_mailles", lambda f: R(f) in ("torso", "upper_arm", "forearm", "hips") or (R(f) == "thigh" and Z(f) > 0.66), 0.03, MATS["mailles"](), pattern=mail)

    def hood(f):
        if R(f) != "head":
            return False
        c = center(f)
        in_face = abs(c.x) < 0.085 and 1.57 < c.z < 1.72 and c.y < SRC_HEAD_Y
        return not in_face
    piece("armure.capuchon_mailles", hood, 0.014, MATS["mailles"](), pattern=mail)
    # --- plaques
    piece("armure.cuirasse_plates", lambda f: R(f) == "torso" and "Shoulder" not in "".join(SRC.dom[v.index] for v in f.verts) and 1.05 < Z(f) < 1.5, 0.036, MATS["acier"](), weights=("limit", ["Spine", "Spine1", "Spine2"]), pattern=ridge)
    piece("armure.spalieres", lambda f: (R(f) == "torso" and "Shoulder" in "".join(SRC.dom[v.index] for v in f.verts)) or (R(f) == "upper_arm" and Z(f) > 1.33), 0.045, MATS["acier"](), weights=("limit", ["{S}Shoulder", "{S}Arm"]))
    piece("armure.canons_cubitieres", lambda f: (R(f) == "upper_arm" and Z(f) <= 1.33) or R(f) == "forearm", 0.03, MATS["acier"](), weights=None)
    piece("armure.gantelets_plates", lambda f: R(f) == "hand", 0.018, MATS["acier"](), weights=("limit", ["{S}Hand", "{S}ForeArm"]))
    piece("armure.tassettes", lambda f: R(f) == "hips" or (R(f) == "thigh" and Z(f) > 0.74), 0.034, MATS["acier"](), weights=("limit", ["Hips", "{S}UpLeg"]))
    piece("armure.greves_genouilleres", lambda f: R(f) == "shin" or (R(f) == "thigh" and Z(f) <= 0.74 and Z(f) > 0.42), 0.026, MATS["acier"]())
    piece("armure.solerets", lambda f: R(f) == "foot", 0.018, MATS["acier"](), weights=("limit", ["{S}Foot", "{S}ToeBase"]))
    # --- surcot
    piece("armure.tabard", lambda f: R(f) in ("torso", "hips") or (R(f) == "thigh" and Z(f) > 0.62), 0.07, MATS["tabard"]())


# tête : hauteur du visage
def head_front_y():
    ys = [v.co.y for v in body.data.vertices if SRC.reg[v.index] == "head" and v.co.z > 1.62]
    return min(ys), max(ys)


HEAD_MIN_Y, HEAD_MAX_Y = head_front_y()
SRC_HEAD_Y = (HEAD_MIN_Y + HEAD_MAX_Y) / 2.0 - 0.01   # le visage est devant (y < centre)


# ------------------------------------------------------------------ casques (modélisés, pas de coque)
def helmet(pid, kind):
    head_c = Vector(((0.0), (HEAD_MIN_Y + HEAD_MAX_Y) / 2.0, 1.655))
    bm = bmesh.new()
    if kind == "bassinet":
        bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=1.0,
                                  matrix=Matrix.Translation(head_c + Vector((0, 0, 0.015))) @ Matrix.Diagonal((0.118, 0.14, 0.135, 1.0)))
        # pointe du dessus : on étire le sommet
        top = max(bm.verts, key=lambda v: v.co.z)
        top.co.z += 0.025
        # coupe sous la nuque / le menton et ouverture du visage
        drop = []
        for f in bm.faces:
            c = f.calc_center_median()
            if c.z < head_c.z - 0.11:
                drop.append(f)
            elif abs(c.x) < 0.08 and c.y < head_c.y - 0.02 and c.z < head_c.z + 0.035:
                drop.append(f)
        bmesh.ops.delete(bm, geom=drop, context="FACES")
    else:  # heaume : grand heaume fermé (tour de révolution) avec fente pour les yeux
        profile = [(0.118, 1.50), (0.132, 1.53), (0.138, 1.58), (0.140, 1.64), (0.140, 1.70), (0.136, 1.76), (0.120, 1.80), (0.085, 1.83), (0.0, 1.845)]
        segs = 24
        rings = []
        for r, z in profile:
            ring = []
            for k in range(segs):
                a = 2 * math.pi * k / segs
                ring.append(bm.verts.new((math.cos(a) * r, head_c.y + math.sin(a) * r * 1.08, z)))
            rings.append(ring)
        slit = []
        for i in range(len(rings) - 1):
            for k in range(segs):
                f = bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
                c = f.calc_center_median()
                if 1.635 < c.z < 1.685 and c.y < head_c.y - 0.05 and abs(c.x) < 0.11:
                    slit.append(f)   # fente des yeux (devant = -Y)
        # dessous ouvert (le cou passe), dessus fermé par le dernier anneau (pointe)
        bmesh.ops.delete(bm, geom=slit, context="FACES")
    for v in bm.verts:
        pass
    dl = bm.verts.layers.deform.verify()
    for v in bm.verts:
        d = v[dl]
        d.clear()
        d[GROUP_INDEX["mixamorig_Head"]] = 1.0
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    name = pid.replace(".", "_")
    ob = to_object(name, bm, MATS["acier"](), smooth=True)
    path = os.path.join(OUT_ARMOR, name + ".glb")
    export([ob], path)
    print("%-28s %5d polygones %6.0f Ko" % (pid, len(ob.data.polygons), os.path.getsize(path) / 1024.0))
    discard([ob])


build_body()
build_pieces()
helmet("armure.bassinet", "bassinet")
helmet("armure.heaume", "heaume")
print("TERMINÉ : tête de y=%.3f à %.3f" % (HEAD_MIN_Y, HEAD_MAX_Y))
