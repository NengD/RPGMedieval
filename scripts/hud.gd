class_name Hud
extends CanvasLayer
## Interface minimale : aide des touches, état du héros, réticule en 1re personne.

var player: Player
var dummy: TrainingDummy

var _help: Label
var _status: Label
var _crosshair: ColorRect


func _ready() -> void:
	_help = _make_label()
	_help.position = Vector2(16, 12)
	_help.text = "ÉTAPE 1 — Base\n" \
		+ "ZQSD / stick gauche : bouger   Souris / stick droit : regarder\n" \
		+ "Maj : courir   Espace : sauter   C : pas de côté   V : changer de vue\n" \
		+ "Clic gauche : coup de test sur le mannequin   R : remettre à zéro   Échap : libérer la souris"
	add_child(_help)

	_status = _make_label()
	_status.position = Vector2(16, 120)
	add_child(_status)

	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.8)
	_crosshair.size = Vector2(4, 4)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position -= Vector2(2, 2)
	add_child(_crosshair)


func _process(_delta: float) -> void:
	var fps_view := player.rig.first_person
	_crosshair.visible = fps_view
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	_status.text = "Vue : %s\nVitesse : %.1f m/s   %s%s" % [
		"première personne" if fps_view else "troisième personne",
		speed,
		"AU SOL" if player.is_on_floor() else "EN L'AIR",
		"   PAS DE CÔTÉ (invulnérable)" if player.invulnerable else ("   pas de côté" if player.is_dodging else ""),
	]


func _make_label() -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_font_size_override("font_size", 16)
	return l
