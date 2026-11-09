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
	_make_weapons()
	var f := StatsFormulas.new()
	print("res://data/stats_formulas.tres -> ", "OK" if ResourceSaver.save(f, "res://data/stats_formulas.tres") == OK else "ERREUR")
	quit()


# ------------------------------------------------------------------ armes (étape 3)

# id : [clé de traduction, genre, deux mains]
const CATEGORIES := {
	"categorie.epee_une_main": ["CAT_EPEE_UNE_MAIN", WeaponCategory.Kind.MELEE, false],
	"categorie.hache": ["CAT_HACHE", WeaponCategory.Kind.MELEE, false],
	"categorie.masse": ["CAT_MASSE", WeaponCategory.Kind.MELEE, false],
	"categorie.lance": ["CAT_LANCE", WeaponCategory.Kind.MELEE, true],
	"categorie.deux_mains": ["CAT_DEUX_MAINS", WeaponCategory.Kind.MELEE, true],
	"categorie.bouclier": ["CAT_BOUCLIER", WeaponCategory.Kind.SHIELD, false],
	"categorie.arc": ["CAT_ARC", WeaponCategory.Kind.BOW, true],
	"categorie.arbalete": ["CAT_ARBALETE", WeaponCategory.Kind.CROSSBOW, true],
}


func _save(res: Resource, path: String) -> Resource:
	var ok := ResourceSaver.save(res, path) == OK
	print(path, " -> ", "OK" if ok else "ERREUR")
	return load(path)   # recharge : les références vers d'autres fichiers deviennent des liens, pas des copies


func _model(id: String) -> PackedScene:
	return load("res://assets/weapons/%s.glb" % id.replace(".", "_")) as PackedScene


func _make_weapons() -> void:
	for d in ["categories", "weapons", "ammo"]:
		DirAccess.make_dir_recursive_absolute("res://data/" + d)
	var cats := {}
	for id in CATEGORIES:
		var spec: Array = CATEGORIES[id]
		var c := WeaponCategory.new()
		c.id = StringName(id)
		c.display_name = StringName(spec[0])
		c.kind = spec[1]
		c.two_handed = spec[2]
		cats[id] = _save(c, "res://data/categories/%s.tres" % id)
	var ammo := {}
	for spec in [["munition.fleche", "MUNITION_FLECHE", 0.72, 0.03], ["munition.carreau", "MUNITION_CARREAU", 0.4, 0.06]]:
		var a := AmmoData.new()
		a.id = StringName(spec[0])
		a.display_name = StringName(spec[1])
		a.model = _model(spec[0])
		a.length = spec[2]
		a.weight = spec[3]
		ammo[spec[0]] = _save(a, "res://data/ammo/%s.tres" % spec[0])
	var T := DamageType.Type
	var sw: Array = [1, 3, 0, 2]
	# id, clé, catégorie, mains, poids, mélange de dégâts, facteurs de chiffres, combo
	var melee := [
		["arme.epee_longue", "ARME_EPEE_LONGUE", "categorie.epee_une_main", 1, 1.4, {T.TRANCHANT: 1.0}, {}, sw],
		["arme.epee_courte", "ARME_EPEE_COURTE", "categorie.epee_une_main", 1, 0.9, {T.TRANCHANT: 0.85, T.PERFORANT: 0.15}, {"windup": 0.85, "strike": 0.9, "recovery": 0.85, "stamina": 0.8, "damage": 0.85, "reach": -0.15}, [1, 3, 2, 0]],
		["arme.hache_guerre", "ARME_HACHE_GUERRE", "categorie.hache", 1, 2.0, {T.TRANCHANT: 0.8, T.CONTONDANT: 0.2}, {"windup": 1.15, "recovery": 1.1, "stamina": 1.15, "damage": 1.2}, [0, 1, 3, 0]],
		["arme.masse_armes", "ARME_MASSE_ARMES", "categorie.masse", 1, 2.5, {T.CONTONDANT: 1.0}, {"windup": 1.2, "recovery": 1.15, "stamina": 1.25, "damage": 1.15}, [1, 0, 3, 2]],
		["arme.lance", "ARME_LANCE", "categorie.lance", 2, 2.2, {T.PERFORANT: 1.0}, {"windup": 1.1, "recovery": 1.1, "stamina": 1.1, "reach": 0.55, "arc": 0.8}, [2, 2, 0, 2]],
		["arme.epee_deux_mains", "ARME_EPEE_DEUX_MAINS", "categorie.deux_mains", 2, 3.2, {T.TRANCHANT: 1.0}, {"windup": 1.35, "strike": 1.1, "recovery": 1.3, "stamina": 1.5, "damage": 1.5, "reach": 0.25}, [0, 1, 3, 2]],
	]
	for m in melee:
		var w := WeaponData.derived_melee(m[0], m[1], cats[m[2]], _model(m[0]), m[3], m[4], m[5], m[6], m[7])
		w.length = 1.0
		if m[0] == "arme.hache_guerre":
			w.held_rotation_deg = Vector3(0.0, 180.0, 0.0)   # le tranchant regarde devant
		_save(w, "res://data/weapons/%s.tres" % m[0])
	var shield := WeaponData.new()
	shield.id = &"arme.ecu"
	shield.display_name = &"ARME_ECU"
	shield.category = cats["categorie.bouclier"]
	shield.model = _model("arme.ecu")
	shield.weight = 3.0
	shield.guard_cost_factor = 0.7
	shield.stat_requirements = {&"force": 11}
	_save(shield, "res://data/weapons/arme.ecu.tres")
	for spec in [["arme.arc_long", "ARME_ARC_LONG", "categorie.arc", "munition.fleche", 1.0], ["arme.arbalete", "ARME_ARBALETE", "categorie.arbalete", "munition.carreau", 3.5]]:
		var r := WeaponData.new()
		r.id = StringName(spec[0])
		r.display_name = StringName(spec[1])
		r.category = cats[spec[2]]
		r.model = _model(spec[0])
		r.hands = 2
		r.weight = spec[4]
		r.ammo = ammo[spec[3]]
		r.damage_mix = {T.PERFORANT: 1.0}
		_save(r, "res://data/weapons/%s.tres" % spec[0])
