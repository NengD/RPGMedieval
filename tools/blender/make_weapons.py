# -*- coding: utf-8 -*-
"""Fabrique le lot 1 d'armes (low-poly) et les exporte en .glb dans assets/weapons/.

Lancer (nouvelle scène, ne touche à aucun .blend ouvert) :
  blender -b --factory-startup -P tools/blender/make_weapons.py -- <dossier_sortie> [<dossier_apercu>]

Conventions (repère Blender, Z vers le haut ; glTF/Godot : Y vers le haut) :
  * l'origine est la prise de la main principale ; l'arme pointe vers +Z Blender (= +Y Godot) ;
  * armes à deux mains / lance : l'origine est la main arrière, le repère « Grip_L » marque la main avant ;
  * arc : branches le long de Z, corde côté archer = -Y Blender (= +Z Godot) ; repères Nock_Top / Nock_Bottom ;
  * arbalète : le canon pointe vers +Y Blender (= -Z Godot) ; repères Grip_L, Bolt_Rest, Nock_Left / Nock_Right ;
  * flèche / carreau : la pointe est à l'origine, la hampe s'étend vers -Y Blender (= +Z Godot).
Matériaux : PBR simples (couleur, métal, rugosité), pas d'image. Moins de 2 000 faces par objet.
"""
import sys, os, math
import bpy, bmesh
from mathutils import Vector, Matrix, Euler

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else os.path.join(os.getcwd(), "assets", "weapons")
PREVIEW = argv[1] if len(argv) > 1 else None
os.makedirs(OUT, exist_ok=True)

# ------------------------------------------------------------------ matériaux
_mats = {}


def mat(name, color, metallic=0.0, rough=0.6):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*color, 1.0)
    _mats[name] = m
    return m


def steel():  return mat("acier", (0.66, 0.68, 0.72), 1.0, 0.32)
def iron():   return mat("fer_sombre", (0.22, 0.22, 0.25), 0.9, 0.5)
def brass():  return mat("laiton", (0.78, 0.58, 0.22), 1.0, 0.38)
def wood():   return mat("bois", (0.38, 0.23, 0.1), 0.0, 0.8)
def wood_d(): return mat("bois_sombre", (0.24, 0.14, 0.07), 0.0, 0.85)
def leather(): return mat("cuir", (0.2, 0.11, 0.06), 0.0, 0.9)
def cord():   return mat("cordage", (0.82, 0.76, 0.6), 0.0, 0.95)
def paint():  return mat("peinture_rouge", (0.52, 0.09, 0.09), 0.0, 0.7)
def feather():
    m = mat("plume", (0.9, 0.9, 0.85), 0.0, 0.9)
    m.use_backface_culling = False   # plume visible des deux côtés
    return m


# ------------------------------------------------------------------ géométrie (bmesh)
def new_bm():
    return bmesh.new()


def box(bm, size, loc=(0, 0, 0), rot=(0, 0, 0)):
    m = Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4() @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


def cyl(bm, r1, r2, depth, loc=(0, 0, 0), rot=(0, 0, 0), segs=10, caps=True):
    m = Matrix.Translation(Vector(loc)) @ Euler(rot, "XYZ").to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=depth, matrix=m)


def sphere(bm, r, loc=(0, 0, 0), segs=8, rings=5, scale=(1, 1, 1)):
    m = Matrix.Translation(Vector(loc)) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r, matrix=m)


def loft(bm, sections):
    """Lame : sections = [(z, demi_largeur, demi_épaisseur[, y])], section en losange ; largeur 0 = pointe."""
    rings = []
    for s in sections:
        z, hw, ht = s[0], s[1], s[2]
        y = s[3] if len(s) > 3 else 0.0
        if hw <= 1e-6:
            rings.append([bm.verts.new((0, y, z))])
        else:
            rings.append([bm.verts.new((-hw, y, z)), bm.verts.new((0, y + ht, z)), bm.verts.new((hw, y, z)), bm.verts.new((0, y - ht, z))])
    for a, b in zip(rings[:-1], rings[1:]):
        if len(b) == 1:
            for i in range(4):
                bm.faces.new((a[i], a[(i + 1) % 4], b[0]))
        else:
            for i in range(4):
                bm.faces.new((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]))
    if len(rings[0]) == 4:
        bm.faces.new(rings[0][::-1])
    if len(rings[-1]) == 4:
        bm.faces.new(rings[-1])


def prism(bm, pts_xz, thickness, y=0.0):
    """Plaque découpée selon un contour dans le plan XZ, d'épaisseur donnée (le long de Y)."""
    h = thickness / 2.0
    back = [bm.verts.new((x, y - h, z)) for x, z in pts_xz]
    front = [bm.verts.new((x, y + h, z)) for x, z in pts_xz]
    bm.faces.new(front)
    bm.faces.new(back[::-1])
    n = len(pts_xz)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((back[i], back[j], front[j], front[i]))


def tube(bm, pts, radius, segs=6, radii=None):
    """Tube qui suit une suite de points (plan YZ), pour les branches d'arc."""
    rings = []
    for i, p in enumerate(pts):
        a = Vector(pts[max(i - 1, 0)])
        b = Vector(pts[min(i + 1, len(pts) - 1)])
        t = (b - a).normalized()
        side = Vector((1, 0, 0))
        nrm = t.cross(side).normalized()
        r = radii[i] if radii else radius
        ring = []
        for k in range(segs):
            ang = 2 * math.pi * k / segs
            ring.append(bm.verts.new(Vector(p) + side * math.cos(ang) * r + nrm * math.sin(ang) * r))
        rings.append(ring)
    for a, b in zip(rings[:-1], rings[1:]):
        for k in range(segs):
            bm.faces.new((a[k], a[(k + 1) % segs], b[(k + 1) % segs], b[k]))
    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])


# ------------------------------------------------------------------ objets
_scene_objs = []


def make_root(name, location=(0, 0, 0)):
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    root.location = location
    return root


def part(root, name, bm, material, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = root
    return ob


def marker(root, name, loc):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "PLAIN_AXES"
    e.empty_display_size = 0.03
    bpy.context.scene.collection.objects.link(e)
    e.parent = root
    e.location = loc
    return e


def count_tris(root):
    n = 0
    for ob in [root] + list(root.children_recursive):
        if ob.type == "MESH":
            me = ob.data
            n += sum(len(p.vertices) - 2 for p in me.polygons)
    return n


# ---- épées
def sword(root, blade_len, half_w, grip_len, guard_w, two_hand=False, name="epee"):
    g0 = 0.0
    if two_hand:
        # origine = main arrière ; la poignée s'étend un peu en dessous et beaucoup au-dessus
        g_lo, g_hi = -0.08, grip_len - 0.08
    else:
        g_lo, g_hi = -grip_len / 2, grip_len / 2
    bm = new_bm()
    z0 = g_hi + 0.015
    loft(bm, [(z0, half_w, 0.0045), (z0 + blade_len * 0.55, half_w * 0.9, 0.0042), (z0 + blade_len * 0.9, half_w * 0.6, 0.0035), (z0 + blade_len, 0, 0)])
    part(root, name + "_lame", bm, steel())
    bm = new_bm()
    box(bm, (guard_w, 0.026, 0.022), (0, 0, g_hi + 0.004))
    box(bm, (0.026, 0.03, 0.03), (guard_w / 2, 0, g_hi + 0.004))
    box(bm, (0.026, 0.03, 0.03), (-guard_w / 2, 0, g_hi + 0.004))
    cyl(bm, 0.022, 0.022, 0.014, (0, 0, g_lo - 0.02), segs=8)
    sphere(bm, 0.022, (0, 0, g_lo - 0.034), 8, 5)
    part(root, name + "_garde", bm, brass(), True)
    bm = new_bm()
    cyl(bm, 0.0165, 0.0165, g_hi - g_lo, (0, 0, (g_hi + g_lo) / 2), segs=8)
    part(root, name + "_poignee", bm, leather(), True)
    if two_hand:
        marker(root, "Grip_L", (0, 0, g_hi - 0.06))
    marker(root, "Tip", (0, 0, z0 + blade_len))


def build_longsword(root):
    sword(root, 0.82, 0.026, 0.19, 0.22, name="epee_longue")


def build_shortsword(root):
    sword(root, 0.52, 0.027, 0.15, 0.17, name="epee_courte")


def build_greatsword(root):
    sword(root, 1.05, 0.034, 0.32, 0.3, two_hand=True, name="epee_deux_mains")


# ---- hache de guerre
def build_axe(root):
    bm = new_bm()
    cyl(bm, 0.019, 0.016, 0.98, (0, 0, 0.36), segs=8)
    cyl(bm, 0.022, 0.022, 0.03, (0, 0, -0.12), segs=8)
    part(root, "hache_manche", bm, wood(), True)
    bm = new_bm()
    prism(bm, [(0.02, 0.6), (0.06, 0.575), (0.19, 0.5), (0.25, 0.68), (0.2, 0.88), (0.06, 0.8), (0.02, 0.77)], 0.014)
    prism(bm, [(-0.02, 0.665), (-0.13, 0.7), (-0.02, 0.735)], 0.016)
    cyl(bm, 0.03, 0.03, 0.28, (0, 0, 0.69), segs=8)
    part(root, "hache_fer", bm, steel())
    bm = new_bm()
    cyl(bm, 0.02, 0.02, 0.05, (0, 0, 0.88), segs=8)
    part(root, "hache_pointe", bm, iron(), True)
    marker(root, "Grip_L", (0, 0, 0.4))
    marker(root, "Tip", (0.25, 0, 0.68))


# ---- masse d'armes
def build_mace(root):
    bm = new_bm()
    cyl(bm, 0.019, 0.017, 0.7, (0, 0, 0.22), segs=8)
    part(root, "masse_manche", bm, wood(), True)
    bm = new_bm()
    cyl(bm, 0.05, 0.05, 0.14, (0, 0, 0.62), segs=10)
    for k in range(8):
        a = k * math.pi / 4
        box(bm, (0.075, 0.012, 0.15), (math.cos(a) * 0.055, math.sin(a) * 0.055, 0.62), (0, 0, a))
    cyl(bm, 0.03, 0.002, 0.07, (0, 0, 0.725), segs=8)
    cyl(bm, 0.027, 0.027, 0.03, (0, 0, 0.53), segs=8)
    part(root, "masse_tete", bm, iron())
    bm = new_bm()
    sphere(bm, 0.025, (0, 0, -0.12), 8, 5)
    part(root, "masse_pommeau", bm, brass(), True)
    marker(root, "Tip", (0, 0, 0.73))


# ---- lance
def build_spear(root):
    bm = new_bm()
    cyl(bm, 0.015, 0.012, 2.0, (0, 0, 0.5), segs=8)
    part(root, "lance_hampe", bm, wood(), True)
    bm = new_bm()
    cyl(bm, 0.022, 0.018, 0.13, (0, 0, 1.46), segs=8)
    loft(bm, [(1.5, 0.018, 0.006), (1.58, 0.036, 0.009), (1.66, 0.024, 0.007), (1.78, 0, 0)])
    part(root, "lance_fer", bm, steel())
    bm = new_bm()
    cyl(bm, 0.017, 0.017, 0.1, (0, 0, -0.45), segs=8)
    part(root, "lance_talon", bm, iron(), True)
    marker(root, "Grip_L", (0, 0, 0.5))
    marker(root, "Tip", (0, 0, 1.78))


# ---- bouclier (écu) : origine au centre, face vers -Y (côté ennemi = +Y glTF -Z... voir doc)
def build_shield(root):
    outline = [(-0.23, 0.30), (0.23, 0.30), (0.23, 0.06), (0.17, -0.14), (0.0, -0.32), (-0.17, -0.14), (-0.23, 0.06)]
    bm = new_bm()
    prism(bm, outline, 0.03, y=0.0)
    part(root, "ecu_planches", bm, wood())
    bm = new_bm()
    big = [(x * 1.0, z * 1.0) for x, z in outline]
    # liseré : mince bordure peinte en front
    prism(bm, [(x * 0.86, z * 0.86 - 0.01) for x, z in outline], 0.034, y=-0.003)
    part(root, "ecu_peinture", bm, paint())
    bm = new_bm()
    cyl(bm, 0.055, 0.045, 0.04, (0, -0.03, 0.02), (math.pi / 2, 0, 0), segs=10)
    sphere(bm, 0.04, (0, -0.045, 0.02), 8, 4, (1, 0.5, 1))
    part(root, "ecu_umbo", bm, iron(), True)
    bm = new_bm()
    box(bm, (0.04, 0.02, 0.5), (0, 0.025, 0.0))
    box(bm, (0.5, 0.02, 0.05), (0, 0.025, 0.1))
    part(root, "ecu_renforts", bm, leather())
    marker(root, "Grip_L", (0, 0.04, 0.05))


# ---- arc long : branches le long de Z, côté archer = -Y
BOW_HALF = 0.8
BOW_SAG = 0.13


def bow_points(n=9):
    pts = []
    for i in range(n):
        z = -BOW_HALF + 2 * BOW_HALF * i / (n - 1)
        y = -BOW_SAG * (z / BOW_HALF) ** 2
        pts.append((0.0, y, z))
    return pts


def build_longbow(root):
    pts = bow_points()
    radii = [0.006 + 0.012 * (1 - abs(p[2]) / BOW_HALF) for p in pts]
    bm = new_bm()
    tube(bm, pts, 0.014, 6, radii)
    part(root, "arc_branches", bm, wood())
    bm = new_bm()
    cyl(bm, 0.022, 0.022, 0.16, (0, 0, 0), segs=8)
    part(root, "arc_poignee", bm, leather(), True)
    bm = new_bm()
    box(bm, (0.012, 0.03, 0.06), (0.014, 0.012, 0.09))
    part(root, "arc_repos", bm, iron())
    top = pts[-1]
    bot = pts[0]
    marker(root, "Nock_Top", (0.0, top[1], top[2]))
    marker(root, "Nock_Bottom", (0.0, bot[1], bot[2]))
    marker(root, "Arrow_Rest", (0.0, 0.0, 0.07))


# ---- arbalète : canon vers +Y
def build_crossbow(root):
    bm = new_bm()
    box(bm, (0.05, 0.62, 0.065), (0, 0.16, -0.01))         # fût
    box(bm, (0.05, 0.2, 0.09), (0, -0.2, -0.03), (0.0, 0, 0))   # crosse
    part(root, "arbalete_fut", bm, wood())
    bm = new_bm()
    box(bm, (0.026, 0.46, 0.014), (0, 0.2, 0.034))         # rail
    box(bm, (0.04, 0.05, 0.05), (0, 0.46, 0.0))
    part(root, "arbalete_rail", bm, iron())
    # arc (prod) : deux branches qui s'incurvent vers l'arrière
    bm = new_bm()
    for sign in (-1, 1):
        pts = []
        for i in range(6):
            x = sign * 0.33 * i / 5
            y = 0.42 - 0.09 * (i / 5) ** 2
            pts.append((x, y, 0.0))
        # tube le long de X : on réutilise tube() avec un repère adapté en créant les anneaux à la main
        rings = []
        for i, p in enumerate(pts):
            r = 0.016 - 0.008 * i / 5
            ring = []
            for k in range(6):
                a = 2 * math.pi * k / 6
                ring.append(bm.verts.new((p[0], p[1] + math.cos(a) * r * 0.6, p[2] + math.sin(a) * r)))
            rings.append(ring)
        for a, b in zip(rings[:-1], rings[1:]):
            for k in range(6):
                bm.faces.new((a[k], a[(k + 1) % 6], b[(k + 1) % 6], b[k]))
        bm.faces.new(rings[-1])
    part(root, "arbalete_prod", bm, wood_d())
    bm = new_bm()
    cyl(bm, 0.045, 0.045, 0.012, (0, 0.52, 0.0), (0, 0, 0), segs=10, caps=False)   # étrier (anneau)
    box(bm, (0.012, 0.012, 0.09), (0.04, 0.52, 0.0))
    box(bm, (0.012, 0.012, 0.09), (-0.04, 0.52, 0.0))
    box(bm, (0.08, 0.012, 0.012), (0, 0.52, -0.045))
    part(root, "arbalete_etrier", bm, iron())
    bm = new_bm()
    box(bm, (0.012, 0.03, 0.05), (0, 0.0, -0.075), (0.4, 0, 0))   # détente
    box(bm, (0.045, 0.1, 0.012), (0, 0.0, -0.062))
    part(root, "arbalete_detente", bm, iron())
    marker(root, "Bolt_Rest", (0, 0.0, 0.043))
    marker(root, "Nock_Left", (-0.33, 0.42 - 0.09, 0.0))
    marker(root, "Nock_Right", (0.33, 0.42 - 0.09, 0.0))
    marker(root, "Muzzle", (0, 0.5, 0.043))
    # Le fût est remonté : l'origine (Grip_R) est la paume de la main arrière, SOUS le fût, sur une poignée.
    # Grip_L est sous l'avant du fût, là où la main avant le soutient.
    for ob in list(root.children):
        ob.location.z += 0.045
    bm = new_bm()
    box(bm, (0.032, 0.035, 0.1), (0, -0.01, -0.005), (0.25, 0, 0))   # poignée
    box(bm, (0.012, 0.09, 0.012), (0, 0.045, -0.045))                 # pontet
    part(root, "arbalete_poignee", bm, wood_d())
    marker(root, "Grip_R", (0, 0, 0))
    marker(root, "Grip_L", (0, 0.30, 0.0))
    # Agrandie de 30 % : vue de derrière, une arbalète à l'échelle réelle n'est qu'un trait fin
    sc = 1.3
    for ob in list(root.children):
        if ob.type == "MESH":
            ob.data.transform(Matrix.Scale(sc, 4))
        ob.location = ob.location * sc


# ---- projectiles : pointe à l'origine, hampe vers -Y
def projectile(root, length, head_len, head_w, shaft_r, fletch_len, name):
    bm = new_bm()
    cyl(bm, shaft_r, shaft_r, length - head_len, (0, -(head_len + (length - head_len) / 2), 0), (math.pi / 2, 0, 0), segs=6)
    part(root, name + "_hampe", bm, wood())
    bm = new_bm()
    cyl(bm, 0.0, head_w, head_len, (0, -head_len / 2, 0), (math.pi / 2, 0, 0), segs=6)
    part(root, name + "_pointe", bm, steel())
    bm = new_bm()
    for k in range(3):
        a = k * 2 * math.pi / 3
        loft_pts = [(0, -length + 0.002), (0, -length + fletch_len)]
        v = Vector((math.cos(a), 0, math.sin(a)))
        v0 = bm.verts.new(Vector((0, -length + 0.002, 0)) + v * shaft_r)
        v1 = bm.verts.new(Vector((0, -length + fletch_len, 0)) + v * shaft_r)
        v2 = bm.verts.new(Vector((0, -length + fletch_len, 0)) + v * (shaft_r + 0.012))
        v3 = bm.verts.new(Vector((0, -length + 0.002, 0)) + v * (shaft_r + 0.018))
        bm.faces.new((v0, v1, v2, v3))
    part(root, name + "_plumes", bm, feather())
    marker(root, "Nock", (0, -length, 0))


def build_arrow(root):
    projectile(root, 0.72, 0.07, 0.014, 0.0045, 0.14, "fleche")


def build_bolt(root):
    projectile(root, 0.4, 0.06, 0.016, 0.0065, 0.07, "carreau")


ITEMS = [
    ("arme.epee_longue", build_longsword),
    ("arme.epee_courte", build_shortsword),
    ("arme.hache_guerre", build_axe),
    ("arme.masse_armes", build_mace),
    ("arme.lance", build_spear),
    ("arme.epee_deux_mains", build_greatsword),
    ("arme.ecu", build_shield),
    ("arme.arc_long", build_longbow),
    ("arme.arbalete", build_crossbow),
    ("munition.fleche", build_arrow),
    ("munition.carreau", build_bolt),
]


def export(root, path):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for c in root.children_recursive:
        c.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_cameras=False, export_lights=False,
                              export_materials="EXPORT", export_image_format="AUTO")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    report = []
    x = 0.0
    for item_id, fn in ITEMS:
        root = make_root(item_id.split(".")[1], (0, 0, 0))
        fn(root)
        tris = count_tris(root)
        name = item_id.replace(".", "_")
        path = os.path.join(OUT, name + ".glb")
        export(root, path)
        # les noms d'objets sont uniques dans tout le fichier Blender : on suffixe ceux de cette arme après l'export
        # pour que les repères de la suivante (Grip_L, Nock…) gardent leur nom propre dans son .glb
        for ob in [root] + list(root.children_recursive):
            ob.name = ob.name + "~" + item_id.split(".")[1]
        report.append("%-22s %5d triangles  %7.0f Ko" % (item_id, tris, os.path.getsize(path) / 1024.0))
        root.location = (x, 0, 0 if "munition" not in item_id else 0.0)
        x += 0.75
        if item_id in ("arme.arbalete",):
            x += 0.3
    print("\n".join(report))
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        scene = bpy.context.scene
        scene.render.engine = "BLENDER_WORKBENCH"
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "MATERIAL"
        scene.render.resolution_x = 1800
        scene.render.resolution_y = 760
        scene.render.film_transparent = False
        scene.world = bpy.data.worlds.new("w")
        scene.world.color = (0.5, 0.55, 0.6)
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 6.2
        scene.collection.objects.link(cam)
        scene.camera = cam
        for tag, loc, rot in (("face", (4.1, -6, 0.6), (math.pi / 2, 0, 0)), ("profil", (4.1 + 5, 0, 0.6), None)):
            if rot is None:
                continue
            cam.location = loc
            cam.rotation_euler = rot
            scene.render.filepath = os.path.join(PREVIEW, "apercu_%s.png" % tag)
            bpy.ops.render.render(write_still=True)
        # vue du dessus pour l'arbalète et les projectiles
        cam.location = (4.1, 0, 6)
        cam.rotation_euler = (0, 0, 0)
        scene.render.filepath = os.path.join(PREVIEW, "apercu_dessus.png")
        bpy.ops.render.render(write_still=True)


main()
