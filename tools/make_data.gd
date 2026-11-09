extends SceneTree
## Fabrique les fichiers de données de départ (matières d'armure, formules de stats).
## Les .tres produits sont ensuite édités à la main / dans l'éditeur pour équilibrer.
## godot --headless --path . -s tools/make_data.gd

# id : [clé de traduction, tranchant, contondant, perforant]
const MATERIALS := {
	"materiau.tissu": ["MATERIAU_TISSU", 0.10, 0.05, 0.05],
	"materiau.cuir": ["MATERIAU_CUIR", 0.30, 0.15, 0.20],
	"materiau.gambison": ["MATERIAU_GAMBISON", 0.40, 0.35, 0.25],
	"materiau.mailles": ["MATERIAU_MAILLES", 0.65, 0.15, 0.25],
	"materiau.plaques": ["MATERIAU_PLAQUES", 0.80, 0.45, 0.70],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/materials")
	for id in MATERIALS:
		var spec: Array = MATERIALS[id]
		var m := MaterialData.new()
		m.id = StringName(id)
		m.display_name = StringName(spec[0])
		m.tranchant = spec[1]
		m.contondant = spec[2]
		m.perforant = spec[3]
		var path := "res://data/materials/%s.tres" % id
		print(path, " -> ", "OK" if ResourceSaver.save(m, path) == OK else "ERREUR")
	var f := StatsFormulas.new()
	print("res://data/stats_formulas.tres -> ", "OK" if ResourceSaver.save(f, "res://data/stats_formulas.tres") == OK else "ERREUR")
	quit()
