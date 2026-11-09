extends SceneTree
## Tests des fondations RPG : stats, types de dégâts, identifiants, sauvegarde, traduction, équipement.
## godot --headless --path . --fixed-fps 120 -s tests/rpg_tests.gd   (code de sortie 1 si échec)

var failures := 0
const R := Combatant.Result
const T := DamageType.Type


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  ÉCHEC ") + label)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _make(team: int, pos: Vector3, yaw: float) -> Combatant:
	var body := Node3D.new()
	root.add_child(body)
	body.position = pos
	body.rotation.y = yaw
	var c := Combatant.new()
	c.body = body
	c.team = team
	body.add_child(c)
	return c


func _armor(id: String, slot: int, layer: int, mat_id: String, weight := 1.0) -> ArmorData:
	var a := ArmorData.new()
	a.id = StringName(id)
	a.display_name = StringName("TEST_" + id)
	a.slot = slot
	a.layer = layer
	a.material = Registry.get_data(StringName(mat_id)) as MaterialData
	a.weight = weight
	return a


func _full_body(mat_id: String) -> Array[ArmorData]:
	var out: Array[ArmorData] = []
	for slot in ArmorData.Slot.values():
		out.append(_armor("armure.test_%s_%d" % [mat_id, slot], slot, ArmorData.Layer.MAILLES, mat_id))
	return out


func _run() -> void:
	await _test_equivalence()
	_test_stats()
	await _test_damage_types()
	_test_registry()
	await _test_equipment()
	await _test_save()
	await _test_weapons()
	await _test_arm_ik()
	await _test_outfits()
	_test_translation()
	print("")
	print("RÉSULTAT RPG : %s (%d échec(s))" % ["SUCCÈS" if failures == 0 else "ÉCHEC", failures])
	quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------- équivalence avec l'ancien combat

func _test_equivalence() -> void:
	print("[Équivalence : les valeurs par défaut donnent exactement les chiffres d'avant]")
	var a := _make(0, Vector3.ZERO, 0.0)
	var b := _make(1, Vector3(0, 0, -1.8), PI)
	await physics_frame
	_check(is_equal_approx(a.max_health, GameConfig.PLAYER_MAX_HEALTH), "vie max = PLAYER_MAX_HEALTH")
	_check(is_equal_approx(a.stats.get_derived(&"endurance_max"), GameConfig.STAMINA_MAX), "endurance max = STAMINA_MAX")
	_check(is_equal_approx(a.stats.get_derived(&"recuperation_endurance"), GameConfig.STAMINA_REGEN), "récupération = STAMINA_REGEN")
	_check(is_equal_approx(a.speed_scale, 1.0), "vitesse d'attaque = 1")
	b.speed_scale = 1.5
	_check(is_equal_approx(b.speed_scale, 1.5), "le réglage de difficulté (speed_scale) passe toujours")
	b.speed_scale = 1.0
	b.max_health = 250.0
	_check(is_equal_approx(b.max_health, 250.0), "la vie imposée (ennemi) passe toujours")
	b.max_health = GameConfig.PLAYER_MAX_HEALTH
	b.reset()
	# un coup de chaque direction : mêmes dégâts et même endurance qu'avant
	for d in 4:
		a.reset()
		b.reset()
		var stam0 := a.stamina
		var hp0 := b.health
		var res := b.receive_hit(a, d, GameConfig.ATTACK_DAMAGE[d])
		_check(res == R.HIT and is_equal_approx(hp0 - b.health, GameConfig.ATTACK_DAMAGE[d]), "coup %s : %d dégâts (sans armure)" % [tr(GameConfig.DIR_NAMES[d]), int(GameConfig.ATTACK_DAMAGE[d])])
		a.request_attack(d)
		_check(is_equal_approx(stam0 - a.stamina, GameConfig.ATTACK_STAMINA[d]), "coup %s : coûte %d d'endurance" % [tr(GameConfig.DIR_NAMES[d]), int(GameConfig.ATTACK_STAMINA[d])])
		a.cancel_recovery()
	# parade normale : coût = dégâts × BLOCK_STAMINA_FACTOR
	a.reset()
	b.reset()
	b.set_guard(true)
	await _frames(70)
	var s0 := b.stamina
	var r2 := b.receive_hit(a, 1, 20.0)
	_check(r2 == R.BLOCKED and is_equal_approx(s0 - b.stamina, 20.0 * GameConfig.BLOCK_STAMINA_FACTOR), "parade : coût en endurance inchangé")
	a.body.queue_free()
	b.body.queue_free()
	await physics_frame


# ---------------------------------------------------------------- stats

func _test_stats() -> void:
	print("[Stats et modificateurs]")
	var s := Stats.new()
	var base_hp := s.get_derived(&"vie_max")
	s.base[&"vigueur"] = 20.0
	_check(is_equal_approx(s.get_derived(&"vie_max"), base_hp * 1.3), "vigueur 20 : +30 % de vie")
	s.base[&"vigueur"] = 10.0
	s.add_modifier(StatModifier.make(&"vie_max", 20.0, 0.0, "equipement:x"))
	_check(is_equal_approx(s.get_derived(&"vie_max"), base_hp + 20.0), "modificateur plat")
	s.add_modifier(StatModifier.make(&"vie_max", 0.0, 0.10, "effet:a"))
	s.add_modifier(StatModifier.make(&"vie_max", 0.0, 0.10, "effet:b"))
	_check(is_equal_approx(s.get_derived(&"vie_max"), (base_hp + 20.0) * 1.2), "deux +10 % s'additionnent (pas de produit : 1,2 et non 1,21)")
	_check(s.remove_by_source("effet:a") == 1 and is_equal_approx(s.get_derived(&"vie_max"), (base_hp + 20.0) * 1.1), "retrait par source")
	var temp := StatModifier.make(&"force", 5.0, 0.0, "effet:potion", 2.0)
	s.add_modifier(temp)
	_check(is_equal_approx(s.get_attribute(&"force"), 15.0), "bonus temporaire actif")
	s.tick(1.0)
	_check(is_equal_approx(s.get_attribute(&"force"), 15.0), "toujours actif après 1 s")
	s.tick(1.5)
	_check(is_equal_approx(s.get_attribute(&"force"), 10.0), "expiré après sa durée")
	_check(s.modifiers.size() == 2, "le modificateur expiré est retiré de la liste")
	var changes := [0]
	s.changed.connect(func(): changes[0] += 1)
	s.add_modifier(StatModifier.make(&"agilite", 1.0, 0.0, "t"))
	_check(changes[0] == 1, "signal changed émis")
	s.carried_weight = 100.0
	_check(s.is_overloaded(), "surcharge détectée (poids > charge max)")


# ---------------------------------------------------------------- types de dégâts × matières

func _test_damage_types() -> void:
	print("[Types de dégâts contre chaque matière]")
	Registry.scan(true)
	var coefs := {}
	for mat_id in ["materiau.tissu", "materiau.cuir", "materiau.gambison", "materiau.mailles", "materiau.plaques"]:
		var mat := Registry.get_data(StringName(mat_id)) as MaterialData
		coefs[mat_id] = mat
		_check(mat != null, "matière %s chargée" % mat_id)
		for t in [T.TRANCHANT, T.CONTONDANT, T.PERFORANT]:
			var a := _make(0, Vector3.ZERO, 0.0)
			var b := _make(1, Vector3(0, 0, -1.8), PI)
			for piece in _full_body(mat_id):
				b.equipment.equip(piece)
			var packet := DamagePacket.of(100.0, t)
			var hp0 := b.health
			b.receive_hit(a, 0, packet)
			var expected := 100.0 * (1.0 - float(mat.protection()[t]))
			_check(absf((hp0 - b.health) - expected) < 0.01, "%s contre %s : %.0f dégâts sur 100" % [mat_id, DamageType.name_of(t), hp0 - b.health])
			a.body.queue_free()
			b.body.queue_free()
	var m: Dictionary = coefs
	_check(m["materiau.mailles"].tranchant > m["materiau.mailles"].perforant and m["materiau.mailles"].tranchant > m["materiau.mailles"].contondant, "mailles : arrêtent bien le tranchant, mal le perforant et le contondant")
	_check(m["materiau.plaques"].tranchant > 0.7 and m["materiau.plaques"].perforant > 0.6 and m["materiau.plaques"].contondant < m["materiau.plaques"].tranchant, "plaques : tranchant et perforant bien arrêtés, contondant en partie transmis")
	_check(m["materiau.gambison"].contondant > m["materiau.mailles"].contondant, "gambison : meilleur que les mailles contre le contondant")
	# mélange de types et type du dernier coup
	var a2 := _make(0, Vector3.ZERO, 0.0)
	var b2 := _make(1, Vector3(0, 0, -1.8), PI)
	var mix := DamagePacket.mixed(100.0, {T.CONTONDANT: 0.7, T.PERFORANT: 0.3})
	_check(absf(mix.total() - 100.0) < 0.001 and mix.dominant_type() == T.CONTONDANT, "mélange 70 % contondant / 30 % perforant")
	b2.receive_hit(a2, 0, mix)
	_check(b2.last_damage_type == T.CONTONDANT, "le type du dernier coup est mémorisé (couleur des chiffres)")
	b2.reset()
	b2.receive_projectile(a2, 10.0, Vector3(0, 0, 1), false)
	_check(b2.last_damage_type == T.PERFORANT, "un tir (nombre simple) est perforant")
	_check(DamageType.color_of(T.TRANCHANT) != DamageType.color_of(T.CONTONDANT) and DamageType.color_of(T.CONTONDANT) != DamageType.color_of(T.PERFORANT), "trois couleurs différentes")
	a2.body.queue_free()
	b2.body.queue_free()
	await physics_frame


# ---------------------------------------------------------------- identifiants

func _test_registry() -> void:
	print("[Identifiants et registre]")
	Registry.scan(true)
	_check(Registry.duplicates().is_empty(), "aucun identifiant de données en double")
	var seen := {}
	var all_ok := true
	for id in Registry.all_ids():
		if seen.has(id) or not str(id).contains("."):
			all_ok = false
		seen[id] = true
	_check(all_ok, "tous les identifiants sont uniques et de la forme « type.nom » (%d objets)" % Registry.all_ids().size())
	_check(Registry.get_data(&"materiau.mailles") is MaterialData, "retrouver un objet par son identifiant")
	var dup := MaterialData.new()
	dup.id = &"materiau.mailles"
	Registry.register_data(dup)
	_check(Registry.duplicates().has("materiau.mailles"), "un doublon est détecté")
	Registry.scan(true)
	Registry.clear_instances()
	var i1 := Registry.new_instance_id("ennemi")
	var i2 := Registry.new_instance_id("ennemi")
	var i3 := Registry.new_instance_id("hero")
	_check(i1 == "ennemi#1" and i2 == "ennemi#2" and i3 == "hero#1", "identifiants d'instance uniques et lisibles (%s, %s, %s)" % [i1, i2, i3])
	var obj := Node.new()
	Registry.register_instance(i1, obj)
	_check(Registry.find_instance(i1) == obj and Registry.find_instance("inconnu#9") == null, "retrouver une instance par son identifiant")
	obj.free()
	_check(Registry.find_instance(i1) == null, "une instance détruite n'est plus retournée")
	Registry.clear_instances()


# ---------------------------------------------------------------- équipement

func _test_equipment() -> void:
	print("[Équipement]")
	Registry.scan(true)
	var a := _make(0, Vector3.ZERO, 0.0)
	await physics_frame
	var gamb := _armor("armure.test_gambison_torse", ArmorData.Slot.TORSE, ArmorData.Layer.GAMBISON, "materiau.gambison", 2.0)
	gamb.stat_modifiers = [StatModifier.make(&"vitesse_attaque", 0.0, -0.02, "")]
	var mail := _armor("armure.test_haubert_torse", ArmorData.Slot.TORSE, ArmorData.Layer.MAILLES, "materiau.mailles", 9.0)
	var plate := _armor("armure.test_cuirasse_torse", ArmorData.Slot.TORSE, ArmorData.Layer.PLAQUES, "materiau.plaques", 6.0)
	plate.hidden_body_regions = [&"torse"]
	var plate2 := _armor("armure.test_cuirasse_bis", ArmorData.Slot.TORSE, ArmorData.Layer.PLAQUES, "materiau.plaques", 5.0)
	a.equipment.equip(gamb)
	a.equipment.equip(mail)
	_check(a.equipment.pieces().size() == 2, "deux couches dans le même emplacement")
	var prot_two: float = a.protection[T.TRANCHANT]
	a.equipment.equip(plate)
	var prot_three: float = a.protection[T.TRANCHANT]
	_check(prot_three > prot_two, "ajouter une couche augmente la protection (%.3f → %.3f)" % [prot_two, prot_three])
	var max_one_slot: float = EquipmentComponent.SLOT_SHARE[ArmorData.Slot.TORSE] * EquipmentComponent.MAX_PROTECTION
	_check(prot_three <= max_one_slot + 0.0001, "la protection d'un emplacement ne dépasse pas sa part du corps")
	_check(is_equal_approx(a.stats.carried_weight, 17.0), "poids porté = 17 kg")
	_check(a.equipment.hidden_regions() == [&"torse"], "parties du corps cachées par la plaque")
	a.equipment.equip(plate2)
	_check(a.equipment.pieces().size() == 3 and not a.equipment.pieces().has(plate) and is_equal_approx(a.stats.carried_weight, 16.0), "même emplacement + même couche : l'ancienne pièce est remplacée")
	_check(a.stats.modifiers.size() == 1, "les modificateurs de la pièce équipée sont actifs")
	a.equipment.unequip(ArmorData.Slot.TORSE, ArmorData.Layer.GAMBISON)
	_check(a.stats.modifiers.is_empty(), "retirer la pièce retire ses modificateurs")
	_check(a.equipment.get_piece(ArmorData.Slot.TORSE, ArmorData.Layer.GAMBISON) == null, "pièce retirée")
	# sauvegarde / restauration
	Registry.register_data(mail)
	Registry.register_data(plate2)
	var state := a.equipment.capture_state()
	var b := _make(0, Vector3.ZERO, 0.0)
	b.equipment.restore_state(state)
	_check(b.equipment.pieces().size() == 2 and is_equal_approx(b.stats.carried_weight, 14.0), "équipement restauré à l'identique")
	_check(is_equal_approx(float(b.protection[T.TRANCHANT]), float(a.protection[T.TRANCHANT])), "protection restaurée identique")
	Registry.unregister_data(mail.id)
	Registry.unregister_data(plate2.id)
	a.body.queue_free()
	b.body.queue_free()
	await physics_frame


# ---------------------------------------------------------------- sauvegarde

func _test_save() -> void:
	print("[Sauvegarde]")
	var slot := "test_rpg"
	var path := SaveService.path_for(slot)
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)

	# aller-retour sur le vrai monde (scène principale)
	Registry.clear_instances()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var p: Player = main.player
	var e: Enemy = main.enemy
	_check(p.instance_id == "hero#1" and e.instance_id == "ennemi#1", "le héros et l'ennemi ont un identifiant d'instance")
	var piece := _armor("armure.test_plaque_save", ArmorData.Slot.TORSE, ArmorData.Layer.PLAQUES, "materiau.plaques", 6.0)
	Registry.register_data(piece)
	var pieces_before := p.combatant.equipment.pieces().size()   # le héros porte déjà sa tenue de départ
	p.combatant.equipment.equip(piece)
	p.combatant.stats.add_modifier(StatModifier.make(&"force", 3.0, 0.0, "effet:test"))
	p.combatant.health = 61.0
	p.combatant.stamina = 33.0
	p.global_position = Vector3(2.5, 0.05, 4.0)
	e.combatant.health = 12.0
	_check(SaveService.save_slot(self, slot) == OK, "sauvegarde écrite")
	_check(FileAccess.file_exists(path), "fichier JSON présent")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary and int(parsed["version"]) == SaveService.current_version and parsed["objets"].has("hero#1"), "JSON lisible avec version et objets")
	# on abîme l'état, puis on recharge
	p.combatant.health = 5.0
	p.combatant.stamina = 1.0
	p.global_position = Vector3(-6, 0.05, 2)
	p.combatant.equipment.unequip(ArmorData.Slot.TORSE, ArmorData.Layer.PLAQUES)
	p.combatant.stats.remove_by_source("effet:test")
	e.combatant.health = 99.0
	var n := SaveService.load_slot(self, slot)
	_check(n >= 3, "chargement : %d objets restaurés" % n)
	_check(is_equal_approx(p.combatant.health, 61.0) and is_equal_approx(p.combatant.stamina, 33.0), "vie et endurance restaurées")
	_check(p.global_position.distance_to(Vector3(2.5, 0.05, 4.0)) < 0.01, "position restaurée")
	_check(is_equal_approx(p.combatant.stats.get_attribute(&"force"), 13.0), "modificateurs de stats restaurés")
	_check(p.combatant.equipment.pieces().size() == pieces_before and p.combatant.protection[T.TRANCHANT] > 0.0, "équipement et protection restaurés")
	_check(is_equal_approx(e.combatant.health, 12.0), "l'ennemi aussi est restauré")

	# écriture atomique + copie de secours
	_check(SaveService.save_slot(self, slot) == OK and FileAccess.file_exists(path + ".bak"), "deuxième écriture : copie de secours .bak créée")
	_check(not FileAccess.file_exists(path + ".tmp"), "aucun fichier temporaire laissé")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ ceci n'est pas du json")
	f.close()
	_check(SaveService.load_slot(self, slot) >= 3, "fichier principal corrompu : la copie de secours est utilisée")

	# migration d'une ancienne version
	var old_version := SaveService.current_version
	var old_migrations := SaveService.migrations.duplicate()
	SaveService.current_version = 2
	SaveService.migrations[1] = func(d: Dictionary) -> Dictionary:
		d["objets"] = d.get("personnages", {})   # exemple : l'ancienne version appelait « personnages » ce qui s'appelle « objets »
		d.erase("personnages")
		return d
	var legacy := {"version": 1, "registre": {}, "personnages": {"hero#1": {"position": [1.0, 0.05, 1.0], "yaw": 0.0, "combat": {"vie": 77.0, "endurance": 50.0}}}}
	SaveService.write_atomic(path, legacy)
	DirAccess.remove_absolute(path + ".bak")
	_check(SaveService.load_slot(self, slot) >= 1 and is_equal_approx(p.combatant.health, 77.0), "une sauvegarde de version 1 est migrée en version 2 puis chargée")
	SaveService.write_atomic(path, {"version": 9, "objets": {}})
	DirAccess.remove_absolute(path + ".bak")
	_check(SaveService.load_slot(self, slot) == -1, "une sauvegarde plus récente que le jeu est refusée")
	SaveService.current_version = old_version
	SaveService.migrations = old_migrations
	_check(SaveService.load_slot(self, "slot_inexistant") == -1, "fichier absent : pas d'erreur, retour propre")

	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + suffix)
	Registry.unregister_data(piece.id)
	main.queue_free()
	await physics_frame


# ---------------------------------------------------------------- traduction

func _script_files() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at("res://scripts"):
		if f.ends_with(".gd"):
			out.append("res://scripts/" + f)
	return out


func _test_translation() -> void:
	print("[Traduction]")
	var keys := {}
	var literal_problems: Array[String] = []
	var key_re := RegEx.create_from_string("\"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\"")
	var tr_re := RegEx.create_from_string("\\btr\\(([^\\n]*?)\\)")
	var text_re := RegEx.create_from_string("(?:show_message\\(|\\.text = |FloatingText\\.spawn\\([^,]+, |_spawn_floating_number\\()\\s*\"([^\"]*)\"")
	var word_re := RegEx.create_from_string("[a-zàâçéèêëîïôûùüÿ]{3,}")
	for path in _script_files():
		var src := FileAccess.get_file_as_string(path)
		for line in src.split("\n"):
			var stripped := line.strip_edges()
			if stripped.begins_with("#"):
				continue
			for m in tr_re.search_all(line):
				for k in key_re.search_all(m.get_string(1)):
					keys[k.get_string(1)] = path
			if line.contains("_NAMES") or line.contains("notice.emit(&"):
				for k in key_re.search_all(line):
					keys[k.get_string(1)] = path
			for m in text_re.search_all(line):
				if word_re.search(m.get_string(1)) != null:
					literal_problems.append("%s : « %s »" % [path.get_file(), m.get_string(1)])
	# clés des données (matières, types de dégâts, stats)
	for mat_id in Registry.all_ids():
		var res := Registry.get_data(mat_id)
		if "display_name" in res and str(res.display_name) != "":
			keys[str(res.display_name)] = "données"
	for k in DamageType.NAME_KEYS:
		keys[str(k)] = "DamageType"
	var missing: Array[String] = []
	for k in keys:
		if TranslationServer.translate(k) == k:
			missing.append("%s (%s)" % [k, str(keys[k]).get_file()])
	_check(keys.size() > 40, "%d clés de traduction utilisées dans le code et les données" % keys.size())
	_check(missing.is_empty(), "toutes les clés utilisées existent en français" + ("" if missing.is_empty() else " — manquantes : " + ", ".join(missing)))
	_check(literal_problems.is_empty(), "aucun texte affiché écrit en dur" + ("" if literal_problems.is_empty() else " — " + " | ".join(literal_problems)))
	var csv_lines := FileAccess.get_file_as_string("res://locale/translations.csv").split("\n")
	_check(csv_lines[0].strip_edges() == "keys,fr,en", "le CSV a la colonne anglaise (vide pour l'instant)")
	var old_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_check(TranslationServer.translate("MSG_DEAD") == "VOUS ÊTES MORT", "anglais vide : retour sur le français (jamais la clé brute)")
	TranslationServer.set_locale(old_locale)
	for name_const in [GameConfig.DIR_NAMES, GameConfig.DIFFICULTY_NAMES, GameConfig.WEAPON_NAMES, Enemy.MODE_NAMES]:
		var all := true
		for k in name_const:
			if TranslationServer.translate(k) == k:
				all = false
		_check(all, "liste de noms traduisible (%s…)" % name_const[0])


# ---------------------------------------------------------------- armes

func _triangles(node: Node) -> int:
	var n := 0
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(si)
			var idx = arrays[Mesh.ARRAY_INDEX]
			n += (idx.size() if idx != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return n


func _test_weapons() -> void:
	print("[Armes]")
	Registry.scan(true)
	var ids: Array = []
	for id in Registry.all_ids():
		if Registry.get_data(id) is WeaponData:
			ids.append(id)
	_check(ids.size() == 9, "9 armes dans les données (6 mêlée, écu, arc, arbalète) : %d" % ids.size())
	var ok_models := true
	var ok_faces := true
	var ok_size := true
	for id in ids:
		var w := Registry.get_data(id) as WeaponData
		var inst := w.model.instantiate() if w.model != null else null
		if inst == null:
			ok_models = false
			continue
		if _triangles(inst) > 2000:
			ok_faces = false
		var path := w.model.resource_path
		if FileAccess.get_file_as_bytes(path).size() > 1024 * 1024:
			ok_size = false
		inst.free()
	_check(ok_models, "chaque arme a un modèle .glb qui se charge")
	_check(ok_faces, "chaque modèle fait moins de 2 000 triangles")
	_check(ok_size, "chaque fichier modèle fait moins de 1 Mo")
	# repères de prise
	var checks := {
		&"arme.epee_deux_mains": ["Grip_L"], &"arme.lance": ["Grip_L"], &"arme.ecu": ["Grip_L"],
		&"arme.arc_long": ["Nock_Top", "Nock_Bottom", "Arrow_Rest"], &"arme.arbalete": ["Grip_R", "Grip_L", "Bolt_Rest", "Muzzle", "Nock_Left", "Nock_Right"],
	}
	for id in checks:
		var inst := (Registry.get_data(id) as WeaponData).model.instantiate()
		var missing: Array[String] = []
		for m in checks[id]:
			if inst.find_child(m, true, false) == null:
				missing.append(m)
		_check(missing.is_empty(), "%s : repères présents (%s)" % [id, ", ".join(checks[id])])
		inst.free()
	for id in [&"munition.fleche", &"munition.carreau"]:
		var am := Registry.get_data(id) as AmmoData
		_check(am != null and am.model != null and am.model.instantiate().find_child("Nock", true, false) != null, "%s : modèle avec repère Nock" % id)

	# équivalence : le fichier de l'épée longue = les valeurs de game_config.gd
	var sword := Registry.get_data(&"arme.epee_longue") as WeaponData
	var ref := WeaponData.from_config()
	var same := sword.attacks.size() == 4
	for i in 4:
		var a := sword.attacks[i]
		var b := ref.attacks[i]
		same = same and is_equal_approx(a.windup, b.windup) and is_equal_approx(a.strike, b.strike) and is_equal_approx(a.recovery, b.recovery) 			and is_equal_approx(a.stamina, b.stamina) and is_equal_approx(a.damage, b.damage) and is_equal_approx(a.reach, b.reach) and is_equal_approx(a.arc_deg, b.arc_deg)
	_check(same and sword.combo_order == ref.combo_order, "épée longue (fichier de données) = valeurs de game_config.gd")

	# le combat avec chaque arme utilise ses propres chiffres
	var a := _make(0, Vector3.ZERO, 0.0)
	var b := _make(1, Vector3(0, 0, -1.8), PI)
	await physics_frame
	for id in ids:
		var w := Registry.get_data(id) as WeaponData
		if w.kind() != WeaponCategory.Kind.MELEE:
			continue
		a.reset()
		b.reset()
		a.equipment.equip_weapon(w)
		var order: Array[int] = w.combo_order
		var stam0 := a.stamina
		a.request_attack()
		var step := w.attack_for(order[0])
		_check(a.attack_dir == order[0] and is_equal_approx(stam0 - a.stamina, step.stamina), "%s : 1er coup du combo = geste %d, coût %.1f" % [id, order[0], step.stamina])
		var hp0 := b.health
		b.receive_hit(a, a.attack_dir, DamagePacket.mixed(step.damage, w.damage_mix))
		_check(hp0 - b.health > 0.0 and is_equal_approx(hp0 - b.health, step.damage), "%s : %.1f dégâts" % [id, step.damage])
		a.cancel_recovery()
	var mace := Registry.get_data(&"arme.masse_armes") as WeaponData
	var axe := Registry.get_data(&"arme.hache_guerre") as WeaponData
	var spear := Registry.get_data(&"arme.lance") as WeaponData
	var great := Registry.get_data(&"arme.epee_deux_mains") as WeaponData
	var short_sword := Registry.get_data(&"arme.epee_courte") as WeaponData
	_check(DamagePacket.mixed(10.0, mace.damage_mix).dominant_type() == T.CONTONDANT, "masse : dégâts contondants")
	_check(DamagePacket.mixed(10.0, spear.damage_mix).dominant_type() == T.PERFORANT, "lance : dégâts perforants")
	_check(spear.attack_for(1).reach > sword.attack_for(1).reach + 0.4, "lance : plus de portée que l'épée")
	_check(great.attack_for(0).damage > sword.attack_for(0).damage and great.attack_for(0).windup > sword.attack_for(0).windup, "deux mains : frappe plus fort mais plus lentement")
	_check(short_sword.attack_for(0).windup < sword.attack_for(0).windup and short_sword.attack_for(0).stamina < sword.attack_for(0).stamina, "épée courte : plus rapide et moins fatigante")
	_check(is_equal_approx(axe.held_rotation_deg.y, 180.0), "hache : tenue avec le tranchant vers l'avant (rotation de prise dans les données)")
	_check(axe.damage_mix.has(T.CONTONDANT) and axe.damage_mix.has(T.TRANCHANT), "hache : tranchant et contondant mêlés")

	# deux mains / bouclier
	var shield := Registry.get_data(&"arme.ecu") as WeaponData
	a.reset()
	a.equipment.equip_weapon(sword)
	_check(a.equipment.equip_weapon(shield), "épée une main + écu : possible")
	_check(a.equipment.equip_weapon(great) and a.equipment.get_weapon(&"off_hand") == null, "équiper une arme à deux mains retire l'écu")
	_check(not a.equipment.equip_weapon(shield), "écu refusé avec une arme à deux mains")
	a.equipment.equip_weapon(sword)
	_check(a.equipment.equip_weapon(shield), "écu de nouveau possible avec l'épée")
	# l'écu réduit le coût des parades
	a.reset()
	b.reset()
	a.equipment.stats.base[&"force"] = 12.0
	a.equipment.stats.changed.emit()
	a.set_guard(true)
	await _frames(70)
	var s0 := a.stamina
	a.receive_hit(b, 1, 20.0)
	_check(is_equal_approx(s0 - a.stamina, 20.0 * GameConfig.BLOCK_STAMINA_FACTOR * shield.guard_cost_factor), "avec l'écu : parer coûte %.0f %% de moins" % ((1.0 - shield.guard_cost_factor) * 100.0))
	# exigences de force
	a.equipment.stats.base[&"force"] = 10.0
	a.equipment.unequip_weapon(&"off_hand")
	var speed_before := a.stats.get_derived(&"vitesse_attaque")
	a.equipment.equip_weapon(shield)
	_check(a.stats.get_derived(&"vitesse_attaque") < speed_before, "force insuffisante pour l'écu : attaques ralenties")
	a.equipment.unequip_weapon(&"off_hand")
	_check(is_equal_approx(a.stats.get_derived(&"vitesse_attaque"), speed_before), "écu retiré : vitesse normale")
	# poids porté
	a.equipment.equip_weapon(shield)
	_check(is_equal_approx(a.stats.carried_weight, sword.weight + shield.weight), "poids des armes dans la charge portée")
	# sauvegarde des armes
	var state := a.equipment.capture_state()
	var c2 := _make(0, Vector3.ZERO, 0.0)
	c2.equipment.restore_state(state)
	_check(c2.equipment.get_weapon(&"main_hand") == sword and c2.equipment.get_weapon(&"off_hand") == shield and c2.weapon == sword, "armes restaurées par la sauvegarde")
	a.body.queue_free()
	b.body.queue_free()
	c2.body.queue_free()
	await physics_frame


# ---------------------------------------------------------------- bras : écu, arc, arbalète

func _test_arm_ik() -> void:
	print("[Bras : prises des armes]")
	Registry.clear_instances()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var p: Player = main.player
	p.combatant.invincible = true
	Input.action_press(&"guard")
	await _frames(120)
	_check(p.model.ik_l.influence > 0.9 and p.model.ik.influence > 0.9, "parade sans écu : l'épée pare et le bras libre reste bas (il ne se lève plus)")
	Input.action_release(&"guard")
	await _frames(60)
	_check(p.toggle_shield() == 1, "écu équipé")
	Input.action_press(&"guard")
	await _frames(120)
	_check(p.combatant.is_guarding() and p.model.ik_l.influence > 0.9, "parade avec écu : le bras gauche amène l'écu (%.0f %%)" % (p.model.ik_l.influence * 100.0))
	_check(p.model.ik.influence < 0.1, "parade avec écu : le bras de l'épée ne se tend plus (%.0f %%)" % (p.model.ik.influence * 100.0))
	var shield_pos: Vector3 = p.model._shield_node.global_position
	var fwd: Vector3 = -p.global_basis.z
	_check((shield_pos - p.global_position).dot(fwd) > 0.2, "l'écu est devant le héros en parade")
	Input.action_release(&"guard")
	p.toggle_shield()
	await _frames(60)
	_check(p.model.ik_l.influence < 0.1, "écu retiré / garde relâchée : le bras gauche reprend l'animation")
	p.switch_weapon(Player.Weapon.CROSSBOW)
	await _frames(90)
	_check(p.model.ik.influence > 0.9 and p.model.ik_l.influence > 0.9, "arbalète : les deux bras tiennent les poignées")
	# les positions demandées aux mains sont à portée des bras (les os animés par IK ne se lisent pas en mode sans fenêtre)
	await _frames(30)
	_check(p.rig.aim_side > 0.0, "arbalète : la caméra de visée passe du côté de l'épaule droite")
	_check(_reach_ok(p, "Right", p.model._grip_r) and _reach_ok(p, "Left", p.model._grip_l), "arbalète : les poignées sont à portée des deux bras")
	p.switch_weapon(Player.Weapon.BOW)
	Input.action_press(&"attack")
	p.start_draw()
	await _frames(60)
	_check(p.model.ik_l.influence > 0.9, "arc bandé : le bras de l'arc est tendu par cinématique inverse")
	_check(p.rig.aim_side > 0.0, "arc : la caméra de visée passe par-dessus l'épaule droite, comme l'arbalète")
	_check(_reach_ok(p, "Left", p.model._grip_l), "arc : la poignée est à portée du bras gauche (bras tendu)")
	Input.action_release(&"attack")
	p.cancel_draw()
	await _frames(120)
	_check(p.model.ik_l.influence < 0.1 and not p.model._bow_in_hand, "arc relâché : retour dans le dos, bras libre")
	main.queue_free()
	await physics_frame


## Le point est-il à la portée du bras (longueur épaule-coude-poignet) ?
func _reach_ok(p: Player, side: String, point: Vector3) -> bool:
	var m: HeroModel = p.model
	var shoulder := m._hand_world("mixamorig_%sArm" % side)
	var elbow := m._hand_world("mixamorig_%sForeArm" % side)
	var wrist := m._hand_world("mixamorig_%sHand" % side)
	var length := shoulder.distance_to(elbow) + elbow.distance_to(wrist)
	return shoulder.distance_to(point) <= length + 0.02

# ---------------------------------------------------------------- tenues et pièces modulaires

func _mesh_vertices(inst: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			out.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	return out


func _test_outfits() -> void:
	print("[Personnage modulaire]")
	Registry.scan(true)
	var rig := (load("res://assets/base/base_rig.tscn") as PackedScene).instantiate()
	root.add_child(rig)
	var sk: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	_check(sk.get_bone_count() == 65 and sk.find_bone("mixamorig_Hips") >= 0 and sk.find_bone("mixamorig1_Hips") < 0, "squelette de base : 65 os nommés mixamorig_*")
	var body_scene := load("res://assets/base/body.glb") as PackedScene
	var body_nodes := RigMesh.attach(sk, body_scene, sk)
	var regions: Array[String] = []
	for n in body_nodes:
		regions.append(String(n.name).trim_prefix("corps_"))
	regions.sort()
	_check(regions == ["foot", "forearm", "hand", "head", "hips", "shin", "thigh", "torso", "upper_arm"], "corps de base en 9 régions : %s" % ", ".join(regions))
	var body_verts := _mesh_vertices(body_scene.instantiate())
	var pieces: Array[ArmorData] = []
	for id in Registry.all_ids():
		var piece := Registry.get_data(id) as ArmorData
		if piece != null and piece.model != null:
			pieces.append(piece)
	_check(pieces.size() == 17, "17 pièces d'armure et d'habit avec modèle : %d" % pieces.size())
	var bones_ok := true
	var budget_ok := true
	var inside := 0
	var checked := 0
	for piece in pieces:
		var inst := piece.model.instantiate()
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var skin := (mi as MeshInstance3D).skin
			if skin == null:
				bones_ok = false
				continue
			for i in skin.get_bind_count():
				if sk.find_bone(String(skin.get_bind_name(i))) < 0:
					bones_ok = false
		if _triangles(inst) > 12000:
			budget_ok = false
		var verts := _mesh_vertices(inst)
		var step := maxi(1, verts.size() / 60)
		for vi in range(0, verts.size(), step):
			var nearest := 1e9
			for bi in range(0, body_verts.size(), 5):
				nearest = minf(nearest, verts[vi].distance_squared_to(body_verts[bi]))
			checked += 1
			if sqrt(nearest) < 0.004:
				inside += 1
		inst.free()
	_check(bones_ok, "tous les os utilisés par les pièces existent dans le squelette du jeu")
	_check(budget_ok, "chaque pièce fait moins de 12 000 triangles")
	_check(inside <= checked / 100, "les pièces ne traversent pas la peau en pose de repos (%d sommets contrôlés, %d trop près : bords des coques, tolérance 1 %%)" % [checked, inside])
	var t_plates := Registry.get_data(&"tenue.chevalier_plates") as OutfitData
	var t_mail := Registry.get_data(&"tenue.homme_armes") as OutfitData
	var t_light := Registry.get_data(&"tenue.archer_leger") as OutfitData
	_check(t_plates != null and t_mail != null and t_light != null, "trois tenues complètes en données")
	var a := _make(0, Vector3.ZERO, 0.0)
	var prot := {}
	for pair in [["plates", t_plates], ["mailles", t_mail], ["leger", t_light]]:
		a.equipment.equip_outfit(pair[1])
		prot[pair[0]] = a.protection.duplicate()
		_check(a.equipment.pieces().size() == pair[1].pieces.size(), "tenue %s : %d pièces portées" % [pair[0], a.equipment.pieces().size()])
	_check(prot["plates"][T.TRANCHANT] > prot["mailles"][T.TRANCHANT] and prot["mailles"][T.TRANCHANT] > prot["leger"][T.TRANCHANT], "protection au tranchant : plates > mailles > cuir et tissu")
	_check(prot["mailles"][T.TRANCHANT] > prot["mailles"][T.CONTONDANT] and prot["mailles"][T.TRANCHANT] > prot["mailles"][T.PERFORANT], "tenue de mailles : mieux protégée contre le tranchant que contre le contondant et le perforant")
	_check(prot["plates"][T.PERFORANT] > prot["mailles"][T.PERFORANT] and prot["plates"][T.CONTONDANT] < prot["plates"][T.TRANCHANT], "plates : perforant mieux arrêté que par les mailles, contondant en partie transmis")
	a.equipment.equip_outfit(t_plates)
	_check(a.equipment.hidden_regions().has(&"torso") and a.equipment.hidden_regions().has(&"hand") and a.equipment.hidden_regions().has(&"foot"), "la tenue de plates cache torse, mains et pieds du corps")
	var w_plates: float = a.stats.carried_weight
	a.equipment.equip_outfit(t_light)
	_check(a.stats.carried_weight < w_plates * 0.6, "la tenue légère pèse nettement moins que les plates (%.1f kg contre %.1f kg)" % [a.stats.carried_weight, w_plates])
	a.equipment.clear_armor()
	_check(a.equipment.pieces().is_empty() and a.protection.get(T.TRANCHANT, 0.0) < 0.001 and is_equal_approx(a.stats.carried_weight, 0.0), "sans tenue : plus de protection, plus de poids")
	a.body.queue_free()

	# affichage dans le jeu
	Registry.clear_instances()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var p: Player = main.player
	var m: HeroModel = p.model
	_check(m._armor_holder.get_child_count() >= 13, "le héros affiche sa tenue de chevalier (%d maillages)" % m._armor_holder.get_child_count())
	_check(not (m._body_nodes["torso"] as Node3D).visible and not (m._body_nodes["hand"] as Node3D).visible and (m._body_nodes["head"] as Node3D).visible, "torse et mains cachés sous l'armure, tête visible")
	_check(main.enemy.model._armor_holder.get_child_count() >= 8, "l'ennemi porte sa tenue d'homme d'armes (%d maillages)" % main.enemy.model._armor_holder.get_child_count())
	var plate_count := m._armor_holder.get_child_count()
	p.cycle_outfit()
	await _frames(2)
	_check(m._armor_holder.get_child_count() != plate_count and m._armor_holder.get_child_count() > 0, "tenue suivante : l'affichage change (%d maillages)" % m._armor_holder.get_child_count())
	p.combatant.equipment.clear_armor()
	await _frames(2)
	_check(m._armor_holder.get_child_count() == 0 and (m._body_nodes["torso"] as Node3D).visible, "sans tenue : le corps nu réapparaît")
	var tabard := Registry.get_data(&"armure.tabard") as ArmorData
	p.combatant.equipment.equip(tabard, 0)
	await _frames(2)
	var color0 := _first_tint(m)
	p.combatant.equipment.set_variant(tabard, 1)
	await _frames(2)
	var color1 := _first_tint(m)
	_check(tabard.color_variants.size() == 4 and color0 != color1, "le tabard change de couleur (4 variantes)")
	main.queue_free()
	rig.queue_free()
	await physics_frame


func _first_tint(m: HeroModel) -> Color:
	for mi in m._armor_holder.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).get_surface_override_material(0)
		if mat is StandardMaterial3D:
			return mat.albedo_color
	return Color(0, 0, 0)
