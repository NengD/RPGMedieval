class_name SaveService
extends RefCounted
## Sauvegarde / chargement : JSON lisible, écriture atomique, copie de secours (.bak), versions et migrations.
##
## Tout nœud du groupe « saveable » expose :
##   save_id() -> String            identifiant d'instance unique (ex. « hero#1 »)
##   capture_state() -> Dictionary  données pures (nombres, textes, tableaux), jamais de nœuds
##   restore_state(d: Dictionary)   remet l'état
## Fichier : { "version": N, "date": "...", "registre": {...}, "objets": { "<id d'instance>": {...} } }

const GROUP := &"saveable"
const SAVE_DIR := "user://saves"
const QUICK_SLOT := "quick"

## Version du format actuellement écrite.
static var current_version := 1
## migrations[v] : fonction (Dictionary) -> Dictionary qui fait passer un fichier de la version v à v+1.
static var migrations: Dictionary = {}


static func path_for(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot]


# ------------------------------------------------------------------ capture / restauration du monde

static func capture_world(tree: SceneTree) -> Dictionary:
	var objects := {}
	for node in tree.get_nodes_in_group(GROUP):
		if node.has_method("save_id") and node.has_method("capture_state"):
			var id: String = node.save_id()
			if id != "":
				objects[id] = node.capture_state()
	return {
		"version": current_version,
		"date": Time.get_datetime_string_from_system(),
		"registre": Registry.capture_state(),
		"objets": objects,
	}


## Remet l'état. Retourne le nombre d'objets restaurés.
static func restore_world(tree: SceneTree, data: Dictionary) -> int:
	Registry.restore_state(data.get("registre", {}))
	var count := 0
	var objects: Dictionary = data.get("objets", {})
	for node in tree.get_nodes_in_group(GROUP):
		if node.has_method("save_id") and node.has_method("restore_state"):
			var id: String = node.save_id()
			if objects.has(id):
				node.restore_state(objects[id])
				count += 1
	return count


# ------------------------------------------------------------------ fichiers

## Écriture atomique : fichier temporaire, ancien fichier gardé en .bak, puis renommage.
static func write_atomic(path: String, data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path)


## Lit un fichier ; si le principal est absent ou illisible, essaie la copie de secours.
## Retourne un dictionnaire vide si rien n'est exploitable.
static func read_with_backup(path: String) -> Dictionary:
	for p in [path, path + ".bak"]:
		if FileAccess.file_exists(p):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
			if parsed is Dictionary and parsed.has("version"):
				return parsed
	return {}


## Applique les migrations en chaîne. Retourne {} si le fichier vient d'une version plus récente que le jeu.
static func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 1))   # JSON : les nombres reviennent en float
	if v > current_version:
		return {}
	while v < current_version:
		if not migrations.has(v):
			push_error("Aucune migration de sauvegarde depuis la version %d" % v)
			return {}
		data = (migrations[v] as Callable).call(data)
		v += 1
		data["version"] = v
	data["version"] = v
	return data


# ------------------------------------------------------------------ raccourcis

static func save_slot(tree: SceneTree, slot: String) -> Error:
	return write_atomic(path_for(slot), capture_world(tree))


## Retourne le nombre d'objets restaurés, ou -1 si le fichier est absent, illisible ou trop récent.
static func load_slot(tree: SceneTree, slot: String) -> int:
	var data := read_with_backup(path_for(slot))
	if data.is_empty():
		return -1
	data = migrate(data)
	if data.is_empty():
		return -1
	return restore_world(tree, data)
