class_name Hud
extends CanvasLayer
## Interface : aide des touches, état du héros, messages de combat, barres, direction.

var player: Player
var dummy: TrainingDummy
var enemy: Enemy

var _help: Label
var _status: Label
var _message: Label
var _crosshair: ColorRect
var _canvas: HudCanvas

const _STATE_NAMES := ["libre", "préparation", "COUP", "récupération", "DÉSÉQUILIBRÉ"]


func _ready() -> void:
	_help = _make_label()
	_help.position = Vector2(16, 12)
	_help.text = "ÉTAPE 3 — Combat contre un ennemi\n" \
		+ "ZQSD : bouger   Maj : courir   Espace : sauter   C : pas de côté   V : changer de vue\n" \
		+ "Bouge la souris (ou stick droit) pour choisir haut/bas/gauche/droite, puis :\n" \
		+ "Clic gauche : attaquer   Clic droit (maintenu) : parer   Clic droit pendant l'élan : feinte\n" \
		+ "F1 / F2 / F3 : difficulté facile / normal / difficile   R : recommencer le combat\n" \
		+ "T : mannequin agressif (coin du fond)   Échap : libérer la souris"
	add_child(_help)

	_status = _make_label()
	_status.position = Vector2(16, 160)
	add_child(_status)

	_canvas = HudCanvas.new()
	add_child(_canvas)

	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.8)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE   # sinon il avale les mouvements de souris !
	_crosshair.size = Vector2(4, 4)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position -= Vector2(2, 2)
	add_child(_crosshair)

	_message = _make_label()
	_message.add_theme_font_size_override("font_size", 30)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.anchor_left = 0.0
	_message.anchor_right = 1.0
	_message.anchor_top = 0.64
	_message.anchor_bottom = 0.72
	_message.modulate.a = 0.0
	add_child(_message)

	var c := player.combatant
	c.hit_resolved.connect(_on_player_hit_resolved)
	c.strike_result.connect(_on_player_strike_result)
	c.feinted.connect(func(): show_message("Feinte", Color(0.8, 0.8, 0.8)))
	c.died.connect(func(): show_message("VOUS ÊTES MORT", Color(1, 0.3, 0.3), 2.0))
	enemy.combatant.died.connect(func(): show_message("ENNEMI VAINCU !", Color(0.5, 1.0, 0.5), 2.0))


func show_message(text: String, color: Color, duration := 0.9) -> void:
	_message.text = text
	_message.modulate = Color(color, 1.0)
	var tw := create_tween()
	tw.tween_interval(duration * 0.5)
	tw.tween_property(_message, "modulate:a", 0.0, duration * 0.5)


func _on_player_hit_resolved(result: int, _dir: int, amount: float, _attacker: Combatant) -> void:
	match result:
		Combatant.Result.HIT: show_message("Touché  -%d" % int(round(amount)), Color(1, 0.35, 0.3))
		Combatant.Result.BLOCKED: show_message("Paré", Color(0.5, 0.8, 1.0))
		Combatant.Result.PARRIED: show_message("PARADE PARFAITE !", Color(0.4, 1.0, 1.0))
		Combatant.Result.GUARD_BROKEN: show_message("GARDE BRISÉE !  -%d" % int(round(amount)), Color(1, 0.55, 0.1))
		Combatant.Result.DODGED: show_message("Esquive", Color(0.8, 0.8, 0.8))


func _on_player_strike_result(result: int, _victim: Combatant) -> void:
	if result == Combatant.Result.BLOCKED:
		show_message("Ton coup est paré", Color(0.8, 0.8, 0.8))
	elif result == Combatant.Result.PARRIED:
		show_message("Ton coup est paré — déséquilibré !", Color(1, 0.7, 0.2))


func _process(_delta: float) -> void:
	var c := player.combatant
	var fps_view := player.rig.first_person
	_crosshair.visible = fps_view
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var guard_text := ""
	if c.is_guarding():
		guard_text = "   GARDE : %s%s" % [GameConfig.DIR_NAMES[c.guard_dir], " (parfaite !)" if c.guard_time <= GameConfig.PERFECT_PARRY_WINDOW else ""]
	_status.text = "Vue : %s   Vitesse : %.1f m/s   Direction choisie : %s\nÉtat : %s%s%s\nMannequin agressif : %s (T)\nDifficulté : %s    Ennemi : %s" % [
		"1re personne" if fps_view else "3e personne",
		speed,
		GameConfig.DIR_NAMES[player.aim_dir].to_upper(),
		_STATE_NAMES[c.state],
		guard_text,
		"   PAS DE CÔTÉ" if player.is_dodging else "",
		"OUI" if dummy.practice else "non",
		GameConfig.DIFFICULTY_NAMES[enemy.difficulty],
		Enemy.MODE_NAMES[enemy.mode],
	]

	_canvas.selected_dir = player.aim_dir
	_canvas.guarding = c.guard_held
	_canvas.health_ratio = c.health / c.max_health
	_canvas.stamina_ratio = c.stamina / GameConfig.STAMINA_MAX
	_canvas.exhausted = c.exhausted
	_canvas.enemy_visible = not enemy.combatant.dead
	_canvas.enemy_health_ratio = enemy.combatant.health / enemy.combatant.max_health
	_canvas.enemy_stamina_ratio = enemy.combatant.stamina / GameConfig.STAMINA_MAX
	_canvas.enemy_exhausted = enemy.combatant.exhausted
	_canvas.enemy_title = "ENNEMI — %s" % GameConfig.DIFFICULTY_NAMES[enemy.difficulty]
	_canvas.threat_dir = _find_threat()
	_canvas.queue_redraw()


## Un adversaire prépare un coup contre le héros : retourne le côté à garder, sinon -1.
func _find_threat() -> int:
	for node in get_tree().get_nodes_in_group(&"combatants"):
		var c := node as Combatant
		if c != null and c.team != player.combatant.team and not c.dead and c.is_attacking():
			return Combatant.mirror(c.attack_dir)
	return -1


func _make_label() -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_font_size_override("font_size", 16)
	return l
