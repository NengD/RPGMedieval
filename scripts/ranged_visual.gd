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

const _WOOD := Color(0.45, 0.3, 0.15)
const _STRING := Color(0.9, 0.85, 0.7)


func _ready() -> void:
	# --- Arc : tenu de la main gauche, tendu vers l'avant ---
	_bow = Node3D.new()
	_bow.position = Vector3(-0.22, -0.05, -0.55)
	add_child(_bow)
	_part(_bow, Vector3(0.04, 0.2, 0.04), Vector3(0, 0, 0), Vector3.ZERO, _WOOD)
	_part(_bow, Vector3(0.025, 0.45, 0.025), Vector3(0, 0.3, 0.075), Vector3(20, 0, 0), _WOOD)
	_part(_bow, Vector3(0.025, 0.45, 0.025), Vector3(0, -0.3, 0.075), Vector3(-20, 0, 0), _WOOD)
	_bow_strings = [_segment(_bow, _STRING, 0.008), _segment(_bow, _STRING, 0.008)]
	_bow_arrow = _make_arrow_model(0.7, Color(0.55, 0.38, 0.2))
	_bow.add_child(_bow_arrow)
	_bow.visible = false

	# --- Arbalète : tenue devant la poitrine ---
	_xbow = Node3D.new()
	_xbow.position = Vector3(0.12, -0.12, -0.5)
	add_child(_xbow)
	_part(_xbow, Vector3(0.06, 0.08, 0.62), Vector3(0, 0, 0.0), Vector3.ZERO, _WOOD)
	_part(_xbow, Vector3(0.04, 0.03, 0.5), Vector3(0, 0.055, -0.04), Vector3.ZERO, Color(0.3, 0.3, 0.33))
	_part(_xbow, Vector3(0.38, 0.035, 0.04), Vector3(-0.19, 0.02, -0.27), Vector3(0, 12, 0), Color(0.3, 0.3, 0.33))
	_part(_xbow, Vector3(0.38, 0.035, 0.04), Vector3(0.19, 0.02, -0.27), Vector3(0, -12, 0), Color(0.3, 0.3, 0.33))
	_xbow_strings = [_segment(_xbow, _STRING, 0.01), _segment(_xbow, _STRING, 0.01)]
	_xbow_bolt = _make_arrow_model(0.4, Color(0.3, 0.3, 0.33))
	_xbow.add_child(_xbow_bolt)
	_xbow.visible = false


## kind : 0 épée (rien), 1 arc, 2 arbalète. tension : 0..1 (arc). reload_left : secondes restantes (arbalète).
func refresh(kind: int, tension: float, drawing: bool, reload_left: float, first_person := false) -> void:
	_bow.visible = kind == 1
	_xbow.visible = kind == 2
	# 3e personne : les armes sont écartées du corps pour rester visibles ; 1re personne : plus proches de l'écran
	_bow.position = Vector3(-0.28, -0.12, -0.8) if first_person else Vector3(-0.52, -0.05, -0.55)
	_xbow.position = Vector3(0.2, -0.2, -0.7) if first_person else Vector3(0.42, -0.12, -0.55)
	if kind == 1:
		var tip_up := Vector3(0, 0.51, 0.15)
		var tip_down := Vector3(0, -0.51, 0.15)
		var nock := Vector3(0, 0, 0.15 + 0.45 * tension)
		_set_segment(_bow_strings[0], tip_up, nock)
		_set_segment(_bow_strings[1], tip_down, nock)
		_bow_arrow.visible = drawing
		_bow_arrow.position = nock + Vector3(0, 0.02, -0.7)   # la queue de la flèche est sur la corde
	elif kind == 2:
		var ready_ratio := 1.0 - clampf(reload_left / GameConfig.CROSSBOW_RELOAD_TIME, 0.0, 1.0)
		var nock := Vector3(0, 0.04, lerpf(-0.27, -0.03, ready_ratio))
		_set_segment(_xbow_strings[0], Vector3(-0.37, 0.02, -0.2), nock)
		_set_segment(_xbow_strings[1], Vector3(0.37, 0.02, -0.2), nock)
		_xbow_bolt.visible = reload_left <= 0.0
		_xbow_bolt.position = Vector3(0, 0.09, -0.03 - 0.4)


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
	mi.transform = Transform3D(Basis.looking_at(d.normalized(), up).scaled(Vector3(1, 1, len)), (a + b) * 0.5)


## Flèche d'affichage : la pointe est à l'origine, la hampe part vers +Z (la queue est sur la corde).
func _make_arrow_model(length: float, color: Color) -> Node3D:
	var n := Node3D.new()
	_part(n, Vector3(0.018, 0.018, length), Vector3(0, 0, length * 0.5), Vector3.ZERO, color)
	_part(n, Vector3(0.05, 0.05, 0.1), Vector3(0, 0, 0), Vector3.ZERO, Color(0.7, 0.72, 0.78))
	n.rotation.y = 0.0
	return n
