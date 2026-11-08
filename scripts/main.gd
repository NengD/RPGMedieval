extends Node3D
## Scène principale : assemble l'arène, le héros, le mannequin et l'interface.

var player: Player
var dummy: TrainingDummy
var hud: Hud

const PLAYER_START := Vector3(0, 0.05, 9)
const DUMMY_POS := Vector3(0, 0, -5)


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

	hud = Hud.new()
	hud.player = player
	hud.dummy = dummy
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


func _on_player_died() -> void:
	get_tree().create_timer(GameConfig.RESPAWN_DELAY).timeout.connect(reset_combat)


func reset_combat() -> void:
	player.reset_to(PLAYER_START, 0.0)
	dummy.reset_stats()
