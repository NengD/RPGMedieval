class_name DamageType
extends RefCounted
## Les trois types de dégâts du jeu. Les valeurs numériques servent de clés dans les données et les sauvegardes.

enum Type { TRANCHANT, CONTONDANT, PERFORANT }

const IDS := [&"tranchant", &"contondant", &"perforant"]
## Clés de traduction (locale/translations.csv)
const NAME_KEYS := [&"DEGAT_TRANCHANT", &"DEGAT_CONTONDANT", &"DEGAT_PERFORANT"]
## Couleur des chiffres flottants (le jaune d'origine = tranchant, pour garder l'habitude)
const COLORS := [Color(1.0, 0.85, 0.2), Color(1.0, 0.55, 0.25), Color(0.6, 0.9, 1.0)]


static func id_of(type: int) -> StringName:
	return IDS[type]


static func from_id(id: StringName) -> int:
	return IDS.find(id)


static func color_of(type: int) -> Color:
	return COLORS[clampi(type, 0, COLORS.size() - 1)]


static func name_of(type: int) -> String:
	return TranslationServer.translate(NAME_KEYS[clampi(type, 0, NAME_KEYS.size() - 1)])
