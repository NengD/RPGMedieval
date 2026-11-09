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
	_make_armor()
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


# ------------------------------------------------------------------ armures et tenues (étape 4)

const S := ArmorData.Slot
const L := ArmorData.Layer
# id, clé, emplacement, couche, matière, poids (kg), régions du corps cachées, variantes de couleur
func _armor_table() -> Array:
	var cloth := [Color(1, 1, 1), Color(0.85, 0.85, 0.95), Color(0.9, 0.8, 0.7)]
	var tabard := [Color(0.62, 0.09, 0.09), Color(0.15, 0.25, 0.62), Color(0.2, 0.45, 0.25), Color(0.13, 0.13, 0.14)]   # rouge, bleu, vert, noir
	return [
		["armure.chemise", "ARMURE_CHEMISE", S.TORSE, L.VETEMENT, "materiau.tissu", 0.6, ["torso", "upper_arm", "forearm"], cloth],
		["armure.braies", "ARMURE_BRAIES", S.JAMBES, L.VETEMENT, "materiau.tissu", 0.4, ["hips", "thigh"], cloth],
		["armure.gants_cuir", "ARMURE_GANTS_CUIR", S.MAINS, L.VETEMENT, "materiau.cuir", 0.2, ["hand"], []],
		["armure.bottes_cuir", "ARMURE_BOTTES_CUIR", S.PIEDS, L.VETEMENT, "materiau.cuir", 0.9, ["foot"], []],
		["armure.gambison", "ARMURE_GAMBISON", S.TORSE, L.GAMBISON, "materiau.gambison", 3.0, ["torso", "upper_arm", "forearm"], [Color(1, 1, 1), Color(0.55, 0.4, 0.3)]],
		["armure.haubert_mailles", "ARMURE_HAUBERT_MAILLES", S.TORSE, L.MAILLES, "materiau.mailles", 9.0, ["torso", "upper_arm", "forearm", "hips"], []],
		["armure.capuchon_mailles", "ARMURE_CAPUCHON_MAILLES", S.TETE, L.MAILLES, "materiau.mailles", 1.0, [], []],
		["armure.cuirasse_plates", "ARMURE_CUIRASSE_PLATES", S.TORSE, L.PLAQUES, "materiau.plaques", 6.0, ["torso"], []],
		["armure.spalieres", "ARMURE_SPALIERES", S.EPAULES, L.PLAQUES, "materiau.plaques", 2.0, [], []],
		["armure.canons_cubitieres", "ARMURE_CANONS_CUBITIERES", S.BRAS, L.PLAQUES, "materiau.plaques", 2.5, ["forearm"], []],
		["armure.gantelets_plates", "ARMURE_GANTELETS_PLATES", S.MAINS, L.PLAQUES, "materiau.plaques", 1.2, ["hand"], []],
		["armure.tassettes", "ARMURE_TASSETTES", S.TAILLE, L.PLAQUES, "materiau.plaques", 2.0, ["hips"], []],
		["armure.greves_genouilleres", "ARMURE_GREVES_GENOUILLERES", S.JAMBES, L.PLAQUES, "materiau.plaques", 4.0, ["shin"], []],
		["armure.solerets", "ARMURE_SOLERETS", S.PIEDS, L.PLAQUES, "materiau.plaques", 1.4, ["foot"], []],
		["armure.bassinet", "ARMURE_BASSINET", S.TETE, L.PLAQUES, "materiau.plaques", 2.0, [], []],
		["armure.heaume", "ARMURE_HEAUME", S.TETE, L.PLAQUES, "materiau.plaques", 3.0, [], []],
		["armure.tabard", "ARMURE_TABARD", S.TORSE, L.SURCOT, "materiau.tissu", 0.8, [], tabard],
	]


func _make_armor() -> void:
	for d in ["armor", "outfits"]:
		DirAccess.make_dir_recursive_absolute("res://data/" + d)
	for row in _armor_table():
		var a := ArmorData.new()
		a.id = StringName(row[0])
		a.display_name = StringName(row[1])
		a.slot = row[2]
		a.layer = row[3]
		a.material = load("res://data/materials/%s.tres" % row[4]) as MaterialData
		a.weight = row[5]
		var regions: Array[StringName] = []
		for r in row[6]:
			regions.append(StringName(r))
		a.hidden_body_regions = regions
		var variants: Array[Color] = []
		for c in row[7]:
			variants.append(c)
		a.color_variants = variants
		a.model = load("res://assets/armor/%s.glb" % str(row[0]).replace(".", "_")) as PackedScene
		_save(a, "res://data/armor/%s.tres" % row[0])
	var outfits := [
		["tenue.chevalier_plates", "TENUE_CHEVALIER_PLATES", ["armure.chemise", "armure.braies", "armure.gambison", "armure.capuchon_mailles", "armure.cuirasse_plates", "armure.spalieres", "armure.canons_cubitieres", "armure.gantelets_plates", "armure.tassettes", "armure.greves_genouilleres", "armure.solerets", "armure.bassinet", "armure.tabard"], {}],
		["tenue.homme_armes", "TENUE_HOMME_ARMES", ["armure.chemise", "armure.braies", "armure.gambison", "armure.haubert_mailles", "armure.capuchon_mailles", "armure.gants_cuir", "armure.bottes_cuir", "armure.tabard"], {"armure.tabard": 0}],
		["tenue.archer_leger", "TENUE_ARCHER_LEGER", ["armure.chemise", "armure.braies", "armure.gambison", "armure.gants_cuir", "armure.bottes_cuir"], {"armure.gambison": 1}],
	]
	for o in outfits:
		var t := OutfitData.new()
		t.id = StringName(o[0])
		t.display_name = StringName(o[1])
		var ids: Array[StringName] = []
		for pid in o[2]:
			ids.append(StringName(pid))
		t.pieces = ids
		t.variants = o[3]
		_save(t, "res://data/outfits/%s.tres" % o[0])
