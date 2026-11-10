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
	await _test_arena()
	await _test_polish()
	await _test_hud()
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
	_check(pieces.size() == 19, "19 pièces d'armure et d'habit avec modèle (dont tête et barbe) : %d" % pieces.size())
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
		if _triangles(inst) > (25000 if str(piece.id) == "armure.tete_homme" else 12000):
			budget_ok = false
		if str(piece.id) in ["armure.tete_homme", "armure.barbe"]:
			inst.free()
			continue   # la tête remplace la région « head » du corps, la barbe colle à la tête : elles sont censées la toucher
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
	_check(budget_ok, "chaque pièce fait moins de 12 000 triangles (25 000 pour la tête)")
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
	_check(not (m._body_nodes["torso"] as Node3D).visible and not (m._body_nodes["hand"] as Node3D).visible and not (m._body_nodes["head"] as Node3D).visible, "torse, mains et tête du corps de base cachés (la tête modelée les remplace)")
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

# ---------------------------------------------------------------- arène, matériaux, lumière, qualité

func _test_arena() -> void:
	print("[Arène, matériaux et lumière]")
	Registry.clear_instances()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var arena: Arena = main.arena
	var names_needed := ["Sol", "MurNord", "MurSud", "MurEst", "MurOuest", "Plateforme", "Rampe", "Caisse1", "Caisse2", "Caisse3", "Tonneau1", "Ratelier", "Poteau1", "Poteau2"]
	var missing: Array[String] = []
	for n in names_needed:
		var body := arena.get_node_or_null(n) as StaticBody3D
		if body == null or body.collision_layer != GameConfig.LAYER_WORLD or body.find_children("*", "CollisionShape3D", false, false).is_empty():
			missing.append(n)
	_check(missing.is_empty(), "l'arène garde ses collisions (monde) et ajoute les accessoires" + ("" if missing.is_empty() else " — manquants : " + ", ".join(missing)))
	var piliers := 0
	for c in arena.get_children():
		if c is StaticBody3D and not c.find_children("*", "CollisionShape3D", false, false).is_empty() and (c.find_children("*", "CollisionShape3D", false, false)[0] as CollisionShape3D).shape is CylinderShape3D and (c as Node3D).position.y > 2.0:
			piliers += 1
	_check(piliers == 4, "les 4 piliers sont toujours là")
	var floor_mi := arena.get_node("Sol").get_child(0) as MeshInstance3D
	var floor_mat := floor_mi.mesh.surface_get_material(0) as StandardMaterial3D
	_check(floor_mat != null and floor_mat.albedo_texture != null and floor_mat.normal_texture != null and floor_mat.roughness_texture != null and floor_mat.uv1_world_triplanar, "sol : matériau PBR (couleur, normale, rugosité) en projection triplanaire")
	var wall_mat := (arena.get_node("MurNord").get_child(0) as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
	_check(wall_mat != null and wall_mat.albedo_texture != null, "murs : matériau PBR de pierre")
	var barrel := arena.get_node("Tonneau1")
	var wood_ok := false
	for mi in barrel.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).get_surface_override_material(0)
		if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null:
			wood_ok = true
	_check(wood_ok, "tonneau : bois PBR appliqué sur le modèle")
	_check(arena.cover_objects.size() >= 7, "obstacles pour se mettre à couvert : %d (piliers et caisses ; les tonneaux et poteaux sont trop bas ou trop fins)" % arena.cover_objects.size())
	# lumière
	var env := arena.environment
	_check(env.background_mode == Environment.BG_SKY and env.sky.sky_material is PanoramaSkyMaterial and (env.sky.sky_material as PanoramaSkyMaterial).panorama != null, "ciel HDRI (panorama)")
	_check(env.tonemap_mode == Environment.TONE_MAPPER_FILMIC, "tonemapping filmique")
	_check(arena.sun.shadow_enabled and arena.sun.light_angular_distance >= 0.0, "ombres du soleil activées")
	# qualité
	var original := QualitySettings.level
	QualitySettings.apply(QualitySettings.Level.LOW, env, arena.sun, root)
	_check(not env.ssao_enabled and not env.fog_enabled, "qualité Bas : pas d'occlusion ambiante ni de brouillard")
	QualitySettings.apply(QualitySettings.Level.MEDIUM, env, arena.sun, root)
	_check(env.ssao_enabled and env.fog_enabled and not env.glow_enabled, "qualité Moyen : occlusion ambiante et brouillard léger")
	QualitySettings.apply(QualitySettings.Level.HIGH, env, arena.sun, root)
	_check(env.ssao_enabled and env.fog_enabled and env.glow_enabled and arena.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "qualité Élevé : occlusion, brouillard, lueur, ombres à 4 cascades")
	var shadow_low: float = QualitySettings.PROFILES[QualitySettings.Level.LOW]["shadow_distance"]
	var shadow_high: float = QualitySettings.PROFILES[QualitySettings.Level.HIGH]["shadow_distance"]
	_check(shadow_high > shadow_low and QualitySettings.PROFILES.size() == 3, "trois niveaux de qualité, de plus en plus détaillés")
	for key in QualitySettings.NAMES:
		_check(TranslationServer.translate(key) != key, "nom de qualité traduit : %s" % key)
	QualitySettings.apply(original, env, arena.sun, root)
	# fichiers et crédits
	var credits := FileAccess.get_file_as_string("res://CREDITS.md")
	var all_files := true
	for f in ["sky/ciel_nuageux_1k.hdr", "textures/pave/diff.jpg", "textures/pierre/diff.jpg", "textures/bois/diff.jpg", "props/caisse.glb", "props/tonneau.glb", "props/ratelier.glb", "props/poteau_entrainement.glb"]:
		if not FileAccess.file_exists("res://assets/" + f):
			all_files = false
	_check(all_files, "toutes les textures, le ciel et les accessoires sont présents")
	_check(credits.contains("polyhaven.com/a/cobblestone_floor_01") and credits.contains("polyhaven.com/a/rustic_stone_wall") and credits.contains("polyhaven.com/a/rough_wood") and credits.contains("kloofendal_48d_partly_cloudy_puresky"), "chaque ressource Poly Haven est créditée dans CREDITS.md")
	main.queue_free()
	await physics_frame

# ---------------------------------------------------------------- animations plus naturelles (étape 6)

func _test_polish() -> void:
	print("[Animations plus naturelles]")
	Registry.clear_instances()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var p: Player = main.player
	var m: HeroModel = p.model
	var e: Enemy = main.enemy
	e.ai_enabled = false
	# --- cadence = vitesse réelle
	var walk := GameConfig.WALK_SPEED
	var run := GameConfig.RUN_SPEED
	var load_ratio := clampf(p.combatant.stats.carried_weight / p.combatant.stats.get_derived(&"charge_max"), 0.0, 1.5)
	var weight_k := 1.0 - GameConfig.ANIM_WEIGHT_EFFECT * load_ratio
	var walk_ref: float = m._refs[&"loco"][0]
	var run_ref: float = m._refs[&"loco"][1]
	_check(walk_ref > 0.8 and run_ref > 3.0 and run_ref > walk_ref * 2.0, "vitesses d'origine des animations mesurées (marche %.2f m/s, course %.2f m/s)" % [walk_ref, run_ref])
	var foot_ok := true
	var last_scale := 0.0
	var monotonic := true
	for h in [0.8, 1.2, 2.0, 3.0, 4.5, 6.0]:
		var sc := m.stride_scale(&"loco", h)
		var t := clampf((h - walk_ref) / (run_ref - walk_ref), 0.0, 1.0)
		var ref := lerpf(walk_ref, run_ref, t)
		if h >= walk_ref and absf(sc / weight_k * ref - h) > h * 0.06 and sc < GameConfig.ANIM_STRIDE_MAX - 0.01:
			foot_ok = false
		if sc < last_scale - 0.35:
			monotonic = false
		last_scale = sc
	_check(foot_ok, "la cadence suit la vitesse réelle : les pieds ne glissent pas (de 0,8 à 6 m/s)")
	_check(monotonic and m.stride_scale(&"loco", run) <= GameConfig.ANIM_STRIDE_MAX, "la cadence reste progressive, plafonnée à %.1f x" % GameConfig.ANIM_STRIDE_MAX)
	var s_walk := m.stride_scale(&"loco", walk)
	var s_heavy := m.stride_scale(&"loco", walk)
	p.combatant.equipment.clear_armor()
	var s_light := m.stride_scale(&"loco", walk)
	_check(s_light > s_heavy, "le poids de la tenue ralentit un peu la cadence (%.2f x en plates, %.2f x sans tenue)" % [s_heavy, s_light])
	p.combatant.equipment.equip_outfit(Registry.get_data(&"tenue.chevalier_plates"))
	# --- pieds
	_check(FootIK.ground_offset(0.3, 0.0, 0.35) == 0.3 and FootIK.ground_offset(1.0, 0.0, 0.35) == 0.35 and FootIK.ground_offset(-1.0, 0.0, 0.35) == -0.35, "pieds : correction de hauteur limitée")
	_check(FootIK.plant_weight(0.0) > 0.99 and FootIK.plant_weight(0.3) < 0.01 and FootIK.plant_weight(0.1) > 0.1 and FootIK.plant_weight(0.1) < 0.9, "pieds : un pied posé suit le terrain, un pied en l'air presque pas")
	_check(m.foot_ik != null and m.foot_ik._legs.size() == 2, "deux jambes pilotées par cinématique inverse")
	# --- coups reçus selon la direction
	var c: Combatant = p.combatant
	var attacker: Combatant = e.combatant
	var base_pos: Vector3 = p.global_position
	var cases := [
		["de la gauche", Vector3(-1.5, 0, 0), 20.0, false, &"hit_left"],
		["de la droite", Vector3(1.5, 0, 0), 20.0, false, &"hit_right"],
		["de face, léger", Vector3(0, 0, -1.5), 10.0, false, &"hit_front_light"],
		["de face, fort", Vector3(0, 0, -1.5), 40.0, false, &"hit_gut"],
	]
	for cs in cases:
		e.global_position = base_pos + p.global_basis * cs[1]
		c.last_attacker = attacker
		c.last_hit_amount = cs[2]
		c.last_hit_head = cs[3]
		_check(m._pick_hit_anim(false) == cs[4], "coup %s (%.0f dégâts) : réaction %s" % [cs[0], cs[2], cs[4]])
	c.last_hit_head = true
	_check(m._pick_hit_anim(false) == &"hit_head", "tir à la tête : secousse de la tête")
	c.last_hit_head = false
	var lib := m.anim_player.get_animation_library("")
	var all_there := true
	for a in [&"hit_left", &"hit_right", &"hit_gut", &"hit_front_light", &"hit_head"]:
		if not lib.has_animation(a) or not HeroModel.UPPER_STATES.has(a):
			all_there = false
	_check(all_there, "les cinq réactions directionnelles sont dans la bibliothèque et le graphe d'animation")
	# --- recul physique
	var pushes := {}
	var victim := _make(0, Vector3(20, 0, 20), 0.0)
	var striker := _make(1, Vector3(20, 0, 18), 0.0)
	var got: Array[Vector3] = []
	victim.knockback.connect(func(v: Vector3): got.append(v))
	for t in [T.TRANCHANT, T.CONTONDANT, T.PERFORANT]:
		victim.reset()
		victim.receive_hit(striker, 0, DamagePacket.of(20.0, t))
		pushes[t] = got[-1]
	_check(pushes[T.CONTONDANT].length() > pushes[T.TRANCHANT].length() and pushes[T.TRANCHANT].length() > pushes[T.PERFORANT].length(), "recul : contondant > tranchant > perforant (%.1f, %.1f, %.1f m/s)" % [pushes[T.CONTONDANT].length(), pushes[T.TRANCHANT].length(), pushes[T.PERFORANT].length()])
	_check(pushes[T.TRANCHANT].z > 0.0 and absf(pushes[T.TRANCHANT].x) < 0.01, "le recul éloigne la victime de l'agresseur")
	victim.reset()
	victim.receive_hit(striker, 0, DamagePacket.of(40.0, T.TRANCHANT))
	_check(got[-1].length() > pushes[T.TRANCHANT].length(), "un coup plus fort fait plus reculer")
	victim.reset()
	victim.equipment.equip_outfit(Registry.get_data(&"tenue.chevalier_plates"))
	victim.receive_hit(striker, 0, DamagePacket.of(20.0, T.TRANCHANT))
	_check(got[-1].length() < pushes[T.TRANCHANT].length(), "les plates, plus lourdes, font moins reculer")
	victim.body.queue_free()
	striker.body.queue_free()
	# --- petit pas en avant visuel : le corps réel et la portée ne bougent pas
	e.global_position = Vector3(30, 0, 30)
	p.combatant.reset()
	p.combatant.stamina = 100.0
	var body_before: Vector3 = p.global_position
	var reach_before := c.attack_step(1).reach
	p.try_attack()
	var max_lunge := 0.0
	for i in 120:
		await physics_frame
		max_lunge = maxf(max_lunge, -m.model_root.position.z)
	_check(max_lunge > GameConfig.ATTACK_LUNGE * 0.9, "pendant l'attaque le personnage fait un petit pas en avant (%.2f m)" % max_lunge)
	_check(Vector2(p.global_position.x - body_before.x, p.global_position.z - body_before.z).length() < 0.01 and is_equal_approx(c.attack_step(1).reach, reach_before), "le corps réel et la portée du coup ne changent pas")
	await _frames(120)
	_check(absf(m.model_root.position.z) < 0.01, "retour en position après l'attaque")
	# --- pieds au sol : les orteils ne s'enfoncent pas
	e.global_position = Vector3(30, 0, 30)
	await _frames(60)
	_check(m.foot_ik.lift > 0.0 and m.foot_ik.lift <= 0.15, "les pieds sont remontés pour ne pas s'enfoncer dans le sol (+%.1f cm)" % (m.foot_ik.lift * 100.0))
	# --- chevilles inclinées selon la pente
	var tm: FootTiltModifier = m.foot_ik._legs[0]["tilt"]
	m.foot_ik._legs[0]["normal"] = Vector3(0.0, 0.94, -0.34).normalized()
	tm.normal_world = m.foot_ik._legs[0]["normal"]
	_check(tm is FootTiltModifier and m.foot_ik._legs[0]["tilt"].bone_name == "mixamorig_LeftFoot" and GameConfig.FOOT_TILT_AMOUNT > 0.0, "chevilles : un modificateur incline le pied selon la normale du sol")
	# --- réactions raccourcies : le clip est accéléré pour tenir dans l'étourdissement
	c.stagger(GameConfig.HIT_STUN)
	var react_speed := float(m.tree.get("parameters/UpperTS/scale"))
	_check(react_speed >= 1.0 and react_speed <= GameConfig.HIT_REACT_MAX_SPEED, "réaction de coup reçu accélérée pour tenir dans l'étourdissement (x%.1f)" % react_speed)
	c.reset()
	# --- main fermée sur l'épée
	await _frames(30)
	_check(m.grip_r != null and m.grip_r.curl > 0.99 and m.grip_r.influence > 0.0, "la main droite se ferme sur la poignée de l'épée")
	m._dead = false
	# --- regard
	e.global_position = p.global_position + Vector3(0, 0, -5)
	await _frames(40)
	_check(m._look_amount > 0.8 and m._look_head.influence > 0.5, "la tête suit l'adversaire proche (%.0f %%)" % (m._look_amount * 100.0))
	e.global_position = p.global_position + Vector3(0, 0, -40)
	await _frames(120)
	_check(m._look_amount < 0.1, "adversaire lointain : le regard revient droit devant")
	# --- deux mains
	e.global_position = Vector3(30, 0, 30)
	p.combatant.equipment.equip_weapon(Registry.get_data(&"arme.lance"))
	await _frames(60)
	_check(m._grip_l_marker != null and m.ik_l.influence > 0.9, "lance : la main gauche tient la hampe (repère Grip_L)")
	p.combatant.equipment.equip_weapon(Registry.get_data(&"arme.epee_longue"))
	await _frames(60)
	_check(m._grip_l_marker == null and m.ik_l.influence < 0.1, "épée à une main : le bras gauche est libre")
	# --- ragdoll
	var meshes_before := m._armor_holder.get_child_count()
	p.combatant.invincible = false
	c.take_damage(9999.0, attacker)
	await _frames(30)
	_check(m.is_ragdoll() and m.ragdoll_sim.get_child_count() == 16, "mort en ragdoll : 16 os physiques")
	var elbow := m.ragdoll_sim.get_node("PB_LeftForeArm") as PhysicalBone3D
	var knee := m.ragdoll_sim.get_node("PB_RightLeg") as PhysicalBone3D
	var neck := m.ragdoll_sim.get_node("PB_Head") as PhysicalBone3D
	_check(elbow.joint_type == PhysicalBone3D.JOINT_TYPE_HINGE and knee.joint_type == PhysicalBone3D.JOINT_TYPE_HINGE and neck.joint_type == PhysicalBone3D.JOINT_TYPE_CONE, "ragdoll : coudes et genoux en charnière, cou en cône limité")
	_check(elbow.get("joint_constraints/angular_limit_enabled") == true and knee.get("joint_constraints/angular_limit_enabled") == true and float(neck.get("joint_constraints/swing_span")) <= 45.0, "ragdoll : limites d'articulations actives (coude, genou, cou ≤ 45°)")
	_check(m._armor_holder.get_child_count() == meshes_before and m.sword_holder.visible, "l'équipement suit le corps (même maillages, arme en main)")
	p.reset_to(Vector3(0, 0.05, 9), 0.0)
	await _frames(30)
	_check(not m.is_ragdoll() and m.tree.active and not c.dead, "remise à zéro : plus de ragdoll, animations réactivées")
	main.queue_free()
	await physics_frame


# ---------------------------------------------------------------- interface sobre

func _action_event(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _test_hud() -> void:
	print("[Interface]")
	Registry.clear_instances()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	var hud: Hud = main.hud
	_check(not hud.help_visible() and not hud.debug_visible(), "aide et infos de débogage masquées par défaut")
	_check(hud._hint != null and hud._hint.visible and hud._hint.text.contains("F6"), "un petit rappel de la touche d'aide reste dans un coin")
	root.push_input(_action_event(&"toggle_help"))
	await _frames(2)
	_check(hud.help_visible() and not hud.debug_visible(), "F6 affiche l'aide")
	root.push_input(_action_event(&"toggle_debug"))
	await _frames(2)
	_check(hud.help_visible() and hud.debug_visible(), "F7 affiche les infos de débogage, séparément")
	root.push_input(_action_event(&"toggle_help"))
	root.push_input(_action_event(&"toggle_debug"))
	await _frames(2)
	_check(not hud.help_visible() and not hud.debug_visible(), "les mêmes touches les masquent")
	var keys_free := true
	for action in [&"toggle_help", &"toggle_debug"]:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				for other in InputMap.get_actions():
					if other != action and InputMap.action_has_event(other, ev):
						keys_free = false
	_check(keys_free, "F6 et F7 ne sont utilisées par aucune autre action")
	for panel in [hud._help_panel, hud._debug_panel]:
		_check(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "le panneau ne bloque jamais la souris")
	_check(hud._status.text.contains("%") and hud._status.text.contains("kg"), "le panneau de débogage contient protection et poids")
	main.queue_free()
	await physics_frame
