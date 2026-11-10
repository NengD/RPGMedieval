extends Node
## Autoload « Sfx » : sons (variantes aléatoires, légère variation de hauteur) et bus audio Musique / Effets / Ambiance.
## Les sons sont générés par tools/make_sounds.py (assets/sounds/nom_1..3.wav). Volumes mémorisés dans user://reglages.cfg.

const BUSES := ["Musique", "Effets", "Ambiance"]
const DEFAULT_DB := {"Musique": -12.0, "Effets": 0.0, "Ambiance": -8.0}   # niveau de base de chaque bus (avant le réglage du joueur)
const SOUND_DIR := "res://assets/sounds/"

var volumes := {"Musique": 0.6, "Effets": 1.0, "Ambiance": 0.6}   # 0..1, réglés dans le menu d'options
var _cache: Dictionary = {}     # nom -> Array[AudioStream]
var _ambient: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	_load_settings()
	_apply_volumes()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://reglages.cfg") == OK:
		for b in BUSES:
			volumes[b] = clampf(float(cfg.get_value("audio", b, volumes[b])), 0.0, 1.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://reglages.cfg")
	for b in BUSES:
		cfg.set_value("audio", b, volumes[b])
	cfg.save("user://reglages.cfg")


func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volumes()


func _apply_volumes() -> void:
	for b in BUSES:
		var idx := AudioServer.get_bus_index(b)
		if idx >= 0:
			var v: float = volumes[b]
			AudioServer.set_bus_volume_db(idx, float(DEFAULT_DB[b]) + (linear_to_db(v) if v > 0.001 else -80.0))
			AudioServer.set_bus_mute(idx, v <= 0.001)


## Variantes d'un son (nom_1, nom_2…).
func variants(sound: String) -> Array:
	if not _cache.has(sound):
		var list: Array = []
		for i in range(1, 6):
			var path := "%s%s_%d.wav" % [SOUND_DIR, sound, i]
			if ResourceLoader.exists(path):
				list.append(load(path))
		_cache[sound] = list
	return _cache[sound]


## Joue un son. `position` : monde (3D) ; null = son non positionné.
func play(sound: String, position: Variant = null, volume_db := 0.0, pitch_var := 0.08, bus := "Effets") -> void:
	var list := variants(sound)
	if list.is_empty():
		return
	var stream: AudioStream = list[randi() % list.size()]
	var pitch := 1.0 + randf_range(-pitch_var, pitch_var)
	if position is Vector3:
		var p := AudioStreamPlayer3D.new()
		p.stream = stream
		p.bus = bus
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.unit_size = 6.0
		p.max_distance = 45.0
		add_child(p)
		p.global_position = position
		p.finished.connect(p.queue_free)
		p.play()
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = stream
		p2.bus = bus
		p2.volume_db = volume_db
		p2.pitch_scale = pitch
		add_child(p2)
		p2.finished.connect(p2.queue_free)
		p2.play()


## Ambiance (vent) et musique (nappe grave) en boucle.
func start_ambience() -> void:
	if not _ambient.is_empty():
		return
	for spec in [["vent", "Ambiance"], ["drone", "Musique"]]:
		var list := variants(spec[0])
		if list.is_empty():
			continue
		var s: AudioStreamWAV = (list[0] as AudioStreamWAV).duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.bus = spec[1]
		add_child(p)
		p.play()
		_ambient.append(p)
