# Game feel et sons (étape 10)

Tout est réglable dans `scripts/game_config.gd` (section « Sensations de jeu et sons ») et, pour le joueur, dans le menu d'options **F8**.

| Effet | Quand | Réglages |
|---|---|---|
| **Arrêt sur image** | coup qui touche (0,07 s), coup paré (0,045 s), garde brisée | `HIT_STOP_HIT`, `HIT_STOP_BLOCK`, `HIT_STOP_SCALE` ; case « Arrêt sur image et ralenti » |
| **Ralenti** | parade parfaite (0,5 s à 30 % de vitesse) | `SLOWMO_PERFECT_PARRY_TIME / _SCALE` |
| **Tremblement de caméra** | tout coup qui implique le joueur (plus fort à la garde brisée et à la parade parfaite) | `SHAKE_STRENGTH`, `SHAKE_DECAY`, `SHAKE_MAX_OFFSET` ; case « Tremblement de caméra » (désactivable) |
| **Étincelles** | sur acier (plates), parades | `PARTICLES_ENABLED` |
| **Éclats de bois** | flèche qui se plante | idem |
| **Poussière** | pas de côté, course rapide | idem |
| **Traînée de l'arme** | fin de la préparation et coup | `TRAIL_ENABLED`, `TRAIL_LIFETIME` |

Le décalage de la caméra est la seule chose qui tremble : la visée n'est jamais touchée. L'arrêt sur image et le ralenti sont ignorés en mode sans fenêtre (tests).

## Sons (`tools/make_sounds.py`, aucun fichier externe)
Synthèse (sinusoïdes inharmoniques, bruit filtré, voyelles à formants), 16 sons x 3 variantes + 2 boucles, dans `assets/sounds/`. `python tools/make_sounds.py assets/sounds` les régénère.
- **Combat** : `acier` (épée sur plates), `mailles`, `bois`, `chair` (choisi d'après la protection de la victime), `parade`, `parade_parfaite`, `elan` (déplacement d'air), `effort` et `cri` (voix).
- **Pas** : `pas_plaques` (cliquetis), `pas_mailles` (froissement), `pas_cuir`, `pas_pave` selon la tenue.
- **Tir** : `arc`, `arbalete`, `fleche_plantee`.
- **Ambiance** : `vent` (bus Ambiance), `drone` (bus Musique), en boucle.
- Chaque lecture choisit une variante au hasard et varie la hauteur (± 8 %). Sons positionnés dans l'espace (`AudioStreamPlayer3D`).

## Bus audio et options
Autoload `Sfx` (`scripts/sfx.gd`) : bus **Musique / Effets / Ambiance**, volumes 0 à 1 mémorisés dans `user://reglages.cfg`. Menu F8 (`scripts/options_menu.gd`) : trois curseurs, tremblement, arrêt sur image / ralenti.

## Limites
- Les sons sont synthétiques : ils sonnent « jeu rétro » plutôt que « enregistrement réel ». Pour des sons plus réalistes, déposer des `.wav` CC0 (Freesound, OpenGameArt, Kenney) sous les mêmes noms dans `assets/sounds/` ; le code n'a pas à changer.
- Pas de son de pas distinct selon le sol (une seule surface : pavés).
