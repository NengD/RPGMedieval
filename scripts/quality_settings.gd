class_name QualitySettings
extends RefCounted
## Réglage de qualité graphique Bas / Moyen / Élevé (touche F10). Les valeurs de chaque niveau sont ici : on peut les ajuster
## sans toucher au reste. Le choix est mémorisé dans user://reglages.cfg.

enum Level { LOW, MEDIUM, HIGH }

## Clés de traduction des noms de niveau
const NAMES := ["QUALITE_BAS", "QUALITE_MOYEN", "QUALITE_ELEVE"]

const PROFILES := {
	Level.LOW: {
		"ssao": false, "fog": false, "glow": false,
		"shadow_atlas": 2048, "shadow_splits": 1, "shadow_distance": 35.0, "soft_filter": 0, "light_angular": 0.0,
		"msaa": 0, "render_scale": 0.8,
	},
	Level.MEDIUM: {
		"ssao": true, "ssao_radius": 1.2, "ssao_intensity": 1.6, "fog": true, "glow": false,
		"shadow_atlas": 4096, "shadow_splits": 2, "shadow_distance": 50.0, "soft_filter": 2, "light_angular": 0.6,
		"msaa": 1, "render_scale": 1.0,
	},
	Level.HIGH: {
		"ssao": true, "ssao_radius": 1.6, "ssao_intensity": 2.0, "fog": true, "glow": true,
		"shadow_atlas": 8192, "shadow_splits": 4, "shadow_distance": 70.0, "soft_filter": 4, "light_angular": 1.0,
		"msaa": 2, "render_scale": 1.0,
	},
}

const SETTINGS_PATH := "user://reglages.cfg"

static var level: int = Level.MEDIUM
static var _loaded := false


static func load_saved() -> int:
	if not _loaded:
		_loaded = true
		var cfg := ConfigFile.new()
		if cfg.load(SETTINGS_PATH) == OK:
			level = clampi(int(cfg.get_value("graphismes", "qualite", Level.MEDIUM)), 0, Level.HIGH)
	return level


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("graphismes", "qualite", level)
	cfg.save(SETTINGS_PATH)


static func next() -> int:
	level = (level + 1) % PROFILES.size()
	save()
	return level


## Applique un niveau à l'environnement, au soleil et à la fenêtre.
static func apply(lv: int, env: Environment, sun: DirectionalLight3D, viewport: Viewport) -> void:
	level = lv
	var p: Dictionary = PROFILES[lv]
	if env != null:
		env.ssao_enabled = p["ssao"]
		if p["ssao"]:
			env.ssao_radius = p["ssao_radius"]
			env.ssao_intensity = p["ssao_intensity"]
		env.fog_enabled = p["fog"]
		env.glow_enabled = p["glow"]
	if sun != null:
		sun.directional_shadow_max_distance = p["shadow_distance"]
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if p["shadow_splits"] >= 4 else (DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if p["shadow_splits"] == 2 else DirectionalLight3D.SHADOW_ORTHOGONAL)
		sun.light_angular_distance = p["light_angular"]
	RenderingServer.directional_shadow_atlas_set_size(p["shadow_atlas"], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(p["soft_filter"])
	if viewport != null:
		viewport.msaa_3d = p["msaa"]
		viewport.scaling_3d_scale = p["render_scale"]
