class_name Registry
extends RefCounted
## Registre central : retrouve n'importe quel type d'objet (par son identifiant stable) ou instance (identifiant unique).
## Identifiants de type : « arme.epee_longue », « armure.haubert_mailles », « materiau.mailles »…
## Identifiants d'instance : « hero#1 », « ennemi#1 »… (type + compteur, sauvegardé).
## Aucune dépendance à l'arbre de scène : utilisable partout, y compris dans les tests.

const DATA_ROOT := "res://data"

static var _data: Dictionary = {}          # id -> Resource
static var _duplicates: Array[String] = []
static var _scanned := false
static var _counters: Dictionary = {}      # type -> dernier numéro attribué
static var _instances: Dictionary = {}     # id d'instance -> Object


# ------------------------------------------------------------------ données (types d'objets)

static func scan(force := false) -> void:
	if _scanned and not force:
		return
	_data.clear()
	_duplicates.clear()
	_scanned = true
	_scan_dir(DATA_ROOT)


static func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan_dir(path.path_join(sub))
	for f in dir.get_files():
		var name := f.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			var res := ResourceLoader.load(path.path_join(name))
			if res != null and "id" in res and str(res.id) != "":
				register_data(res)


static func register_data(res: Resource) -> void:
	var id := StringName(str(res.get("id")))
	if _data.has(id) and _data[id] != res:
		_duplicates.append(str(id))
		push_error("Identifiant en double dans les données : %s" % id)
		return
	_data[id] = res


static func unregister_data(id: StringName) -> void:
	_data.erase(id)


static func get_data(id: StringName) -> Resource:
	scan()
	return _data.get(id)


static func all_ids() -> Array:
	scan()
	return _data.keys()


static func duplicates() -> Array[String]:
	scan()
	return _duplicates


# ------------------------------------------------------------------ instances

static func new_instance_id(type_id: String) -> String:
	var n: int = int(_counters.get(type_id, 0)) + 1
	_counters[type_id] = n
	return "%s#%d" % [type_id, n]


static func register_instance(instance_id: String, obj: Object) -> void:
	_instances[instance_id] = obj


static func find_instance(instance_id: String) -> Object:
	var o = _instances.get(instance_id)
	return o if is_instance_valid(o) else null


static func clear_instances() -> void:
	_instances.clear()
	_counters.clear()


static func capture_state() -> Dictionary:
	return {"compteurs": _counters.duplicate()}


static func restore_state(d: Dictionary) -> void:
	for k in d.get("compteurs", {}):
		_counters[k] = maxi(int(_counters.get(k, 0)), int(d["compteurs"][k]))
