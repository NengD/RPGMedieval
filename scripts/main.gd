extends Node3D
## Scène principale : assemble l'arène, le héros, le mannequin et l'interface.

var player: Player
var dummy: TrainingDummy
var enemy: Enemy
var hud: Hud
var arena: Arena
var targets: Array = []
var target_score := 0
var _reset_gen := 0   # évite qu'un ancien minuteur relance un combat déjà recommencé

const PLAYER_START := Vector3(0, 0.05, 9)
const DUMMY_POS := Vector3(-8, 0, -9)
const ENEMY_START := Vector3(0, 0, -6)


func _ready() -> void:
	arena = Arena.new()
	add_child(arena)

	dummy = TrainingDummy.new()
	dummy.position = DUMMY_POS
	add_child(dummy)
	dummy.instance_id = Registry.new_instance_id("mannequin")
	Registry.register_instance(dummy.instance_id, dummy)

	player = Player.new()
	player.position = PLAYER_START
	add_child(player)
	player.instance_id = Registry.new_instance_id("hero")
	Registry.register_instance(player.instance_id, player)
	dummy.target_node = player
	player.combatant.died.connect(_on_player_died)

	enemy = Enemy.new()
	enemy.position = ENEMY_START
	enemy.target = player
	enemy.difficulty = GameConfig.DEFAULT_DIFFICULTY
	enemy.cover_objects = arena.cover_objects
	add_child(enemy)
	enemy.instance_id = Registry.new_instance_id("ennemi")
	Registry.register_instance(enemy.instance_id, enemy)
	enemy.combatant.died.connect(_on_enemy_died)

	_build_targets()

	hud = Hud.new()
	hud.player = player
	hud.dummy = dummy
	hud.enemy = enemy
	add_child(hud)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"reset_combat"):
		reset_combat()
	elif event.is_action_pressed(&"next_melee"):
		var w := player.cycle_melee()
		if w != null:
			hud.show_message(tr("MSG_WEAPON") % tr(w.display_name), Color(1, 0.9, 0.5), 1.2)
	elif event.is_action_pressed(&"toggle_shield"):
		var res := player.toggle_shield()
		hud.show_message(tr("MSG_SHIELD_ON") if res == 1 else (tr("MSG_SHIELD_OFF") if res == 0 else tr("MSG_SHIELD_BLOCKED")), Color(1, 0.9, 0.5), 1.2)
	elif event.is_action_pressed(&"quick_save"):
		quick_save()
	elif event.is_action_pressed(&"quick_load"):
		quick_load()
	elif event.is_action_pressed(&"toggle_ai"):
		enemy.ai_enabled = not enemy.ai_enabled
		hud.show_message(tr("MSG_AI_ON") if enemy.ai_enabled else tr("MSG_AI_OFF"), Color(1, 0.9, 0.5), 1.5)
	elif event.is_action_pressed(&"clear_arrows"):
		Arrow.clear_all(get_tree())
	elif event.is_action_pressed(&"toggle_practice"):
		dummy.set_practice(not dummy.practice)
	elif event.is_action_pressed(&"difficulty_easy"):
		set_difficulty(0)
	elif event.is_action_pressed(&"difficulty_normal"):
		set_difficulty(1)
	elif event.is_action_pressed(&"difficulty_hard"):
		set_difficulty(2)
	elif event.is_action_pressed(&"difficulty_cycle"):
		set_difficulty((enemy.difficulty + 1) % 3)


## Sauvegarde rapide (F5) : écrit user://saves/quick.json.
func quick_save() -> void:
	var err := SaveService.save_slot(get_tree(), SaveService.QUICK_SLOT)
	hud.show_message(tr("MSG_SAVED") if err == OK else tr("MSG_LOAD_FAILED"), Color(0.6, 1.0, 0.6), 1.2)


## Chargement rapide (F9).
func quick_load() -> void:
	_reset_gen += 1   # annule un redémarrage de combat programmé
	var n := SaveService.load_slot(get_tree(), SaveService.QUICK_SLOT)
	hud.show_message(tr("MSG_LOADED") if n >= 0 else tr("MSG_LOAD_FAILED"), Color(0.6, 1.0, 0.6) if n >= 0 else Color(1, 0.5, 0.4), 1.2)


## Cibles d'entraînement au tir, à différentes distances (la dernière se déplace).
func _build_targets() -> void:
	var specs := [
		{"pos": Vector3(-14.2, 1.5, 6.0), "move": 0.0},
		{"pos": Vector3(14.2, 1.5, 0.0), "move": 0.0},
		{"pos": Vector3(-14.2, 1.5, -11.0), "move": 0.0},
		{"pos": Vector3(0.0, 1.4, -14.3), "move": 5.0},
	]
	for spec in specs:
		var t := ArcheryTarget.new()
		t.move_range = spec.move
		t.move_speed = 1.2
		add_child(t)
		t.place(spec.pos, Vector3(0.0, spec.pos.y, 0.0))
		t.scored.connect(func(points: int):
			target_score += points
			hud.target_score = target_score)
		targets.append(t)


func _on_player_died() -> void:
	_reset_later(GameConfig.RESPAWN_DELAY)


func _on_enemy_died() -> void:
	_reset_later(GameConfig.RESPAWN_DELAY + 0.5)


## Change la difficulté de l'ennemi et relance le combat.
func set_difficulty(level: int) -> void:
	enemy.difficulty = level
	reset_combat()
	hud.show_message(tr("MSG_DIFFICULTY") % tr(GameConfig.DIFFICULTY_NAMES[level]), Color(1, 0.9, 0.5), 1.5)


func _reset_later(delay: float) -> void:
	var gen := _reset_gen
	get_tree().create_timer(delay).timeout.connect(func(): if gen == _reset_gen: reset_combat())


func reset_combat() -> void:
	_reset_gen += 1
	player.reset_to(PLAYER_START, 0.0)
	dummy.reset_stats()
	enemy.reset_to(ENEMY_START)
