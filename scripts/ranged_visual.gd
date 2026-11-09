class_name RangedVisual
extends Node3D
## Arc et arbalète en formes simples, animés par code (corde tendue, flèche encochée, rechargement).
## Repère : épaule du héros, -Z devant, +X à droite. kind : 1 = arc, 2 = arbalète.

var _bow: Node3D
var _bow_strings: Array = []
var _bow_arrow: Node3D
var _xbow: Node3D
var _xbow_strings: Array = []
var _xbow_bolt: Node3D
var _bow_top := Vector3(0, 0.51, 0.13)
var _bow_bottom := Vector3(0, -0.51, 0.13)
var _bow_holder: Node3D
var _xbow_holder: Node3D
var _ammo_len := 0.72
var _xbow_nock_l := Vector3(-0.33, 0.0, -0.33)
var _xbow_nock_r := Vector3(0.33, 0.0, -0.33)
var _xbow_rest := Vector3(0.0, 0.043, 0.0)

const _WOOD := Color(0.45, 0.3, 0.15)
const _STRING := Color(0.9, 0.85, 0.7)


func _ready() -> void:
	# --- Arc : tenu de la main gauche, tendu vers l'avant ---
	_bow = Node3D.new()
	_bow.position = Vector3(-0.22, -0.05, -0.55)
	add_child(_bow)
	_bow_holder = Node3D.new()
	_bow.add_child(_bow_holder)
	_bow_strings = [_segment(_bow, _STRING, 0.008), _segment(_bow, _STRING, 0.008)]
	_bow_arrow = Node3D.new()
	_bow.add_child(_bow_arrow)
	_bow.visible = false

	# --- Arbalète : tenue devant la poitrine ---
	_xbow = Node3D.new()
	_xbow.position = Vector3(0.12, -0.12, -0.5)
	add_child(_xbow)
	_xbow_holder = Node3D.new()
	_xbow.add_child(_xbow_holder)
	_xbow_strings = [_segment(_xbow, _STRING, 0.01), _segment(_xbow, _STRING, 0.01)]
	_xbow_bolt = Node3D.new()
	_xbow.add_child(_xbow_bolt)
	_xbow.visible = false


## Met en place les modèles d'arc et d'arbalète (1re personne).
func set_weapons(bow: WeaponData, xbow: WeaponData) -> void:
	for n in [_bow_holder, _bow_arrow, _xbow_holder, _xbow_bolt]:
		for c in n.get_children():
			n.remove_child(c)
			c.queue_free()
	if bow != null and bow.model != null:
		var m := bow.model.instantiate()
		_bow_holder.add_child(m)
		var top := m.find_child("Nock_Top", true, false) as Node3D
		var bottom := m.find_child("Nock_Bottom", true, false) as Node3D
		if top != null and bottom != null:
			_bow_top = top.position
			_bow_bottom = bottom.position
		if bow.ammo != null and bow.ammo.model != null:
			_ammo_len = bow.ammo.length
			_bow_arrow.add_child(bow.ammo.model.instantiate())
	if xbow != null and xbow.model != null:
		var x := xbow.model.instantiate()
		_xbow_holder.add_child(x)
		var muzzle := x.find_child("Muzzle", true, false) as Node3D
		if muzzle != null:
			_xbow_bolt.position = muzzle.position
		var nl := x.find_child("Nock_Left", true, false) as Node3D
		var nr := x.find_child("Nock_Right", true, false) as Node3D
		var rest := x.find_child("Bolt_Rest", true, false) as Node3D
		if nl != null and nr != null and rest != null:
			_xbow_nock_l = nl.position
			_xbow_nock_r = nr.position
			_xbow_rest = rest.position
		if xbow.ammo != null and xbow.ammo.model != null:
			_xbow_bolt.add_child(xbow.ammo.model.instantiate())


## kind : 0 épée (rien), 1 arc, 2 arbalète. tension : 0..1 (arc). reload_left : secondes restantes (arbalète).
func refresh(kind: int, tension: float, drawing: bool, reload_left: float, first_person := false) -> void:
	_bow.visible = kind == 1
	_xbow.visible = kind == 2
	# 3e personne : les armes sont écartées du corps pour rester visibles ; 1re personne : plus proches de l'écran
	_bow.position = Vector3(-0.28, -0.12, -0.8) if first_person else Vector3(-0.52, -0.05, -0.55)
	_xbow.position = Vector3(0.2, -0.2, -0.45) if first_person else Vector3(0.42, -0.12, -0.3)
	if kind == 1:
		var tip_up := _bow_top
		var tip_down := _bow_bottom
		var nock := Vector3(0, 0, _bow_top.z + 0.45 * tension)
		_set_segment(_bow_strings[0], tip_up, nock)
		_set_segment(_bow_strings[1], tip_down, nock)
		_bow_arrow.visible = drawing
		_bow_arrow.position = nock + Vector3(0, 0.0, -_ammo_len)   # la queue de la flèche est sur la corde
	elif kind == 2:
		var ready_ratio := 1.0 - clampf(reload_left / GameConfig.CROSSBOW_RELOAD_TIME, 0.0, 1.0)
		var nock := Vector3(0.0, _xbow_rest.y, lerpf(_xbow_nock_l.z, _xbow_rest.z, ready_ratio))   # la corde se tend pendant le rechargement
		_set_segment(_xbow_strings[0], _xbow_nock_l, nock)
		_set_segment(_xbow_strings[1], _xbow_nock_r, nock)
		_xbow_bolt.visible = reload_left <= 0.0


func _part(parent: Node3D, size: Vector3, pos: Vector3, euler_deg: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation = Vector3(deg_to_rad(euler_deg.x), deg_to_rad(euler_deg.y), deg_to_rad(euler_deg.z))
	parent.add_child(mi)


func _segment(parent: Node3D, color: Color, thickness: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(thickness, thickness, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	bm.material = mat
	mi.mesh = bm
	parent.add_child(mi)
	return mi


func _set_segment(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return
	var up := Vector3.UP if absf(d.normalized().y) < 0.9 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(d.normalized(), up) * Basis.from_scale(Vector3(1, 1, len)), (a + b) * 0.5)


## Flèche d'affichage : la pointe est à l'origine, la hampe part vers +Z (la queue est sur la corde).
func _make_arrow_model(length: float, color: Color) -> Node3D:
	var n := Node3D.new()
	_part(n, Vector3(0.018, 0.018, length), Vector3(0, 0, length * 0.5), Vector3.ZERO, color)
	_part(n, Vector3(0.05, 0.05, 0.1), Vector3(0, 0, 0), Vector3.ZERO, Color(0.7, 0.72, 0.78))
	n.rotation.y = 0.0
	return n
