extends Node3D
## Scène principale : assemble l'arène, le héros, le mannequin et l'interface.

var player: Player
var dummy: TrainingDummy
var enemy: Enemy
var hud: Hud

const PLAYER_START := Vector3(0, 0.05, 9)
const DUMMY_POS := Vector3(-8, 0, -9)
const ENEMY_START := Vector3(0, 0, -6)


func _ready() -> void:
	add_child(Arena.new())

	dummy = TrainingDummy.new()
	dummy.position = DUMMY_POS
	add_child(dummy)

	player = Player.new()
	player.position = PLAYER_START
	add_child(player)
	dummy.target_node = player
	player.combatant.died.connect(_on_player_died)

	enemy = Enemy.new()
	enemy.position = ENEMY_START
	enemy.target = player
	enemy.difficulty = GameConfig.DEFAULT_DIFFICULTY
	add_child(enemy)
	enemy.combatant.died.connect(_on_enemy_died)

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


func _on_player_died() -> void:
	get_tree().create_timer(GameConfig.RESPAWN_DELAY).timeout.connect(reset_combat)


func _on_enemy_died() -> void:
	get_tree().create_timer(GameConfig.RESPAWN_DELAY + 0.5).timeout.connect(reset_combat)


## Change la difficulté de l'ennemi et relance le combat.
func set_difficulty(level: int) -> void:
	enemy.difficulty = level
	reset_combat()
	hud.show_message("Difficulté : %s" % GameConfig.DIFFICULTY_NAMES[level], Color(1, 0.9, 0.5), 1.5)


func reset_combat() -> void:
	player.reset_to(PLAYER_START, 0.0)
	dummy.reset_stats()
	enemy.reset_to(ENEMY_START)
