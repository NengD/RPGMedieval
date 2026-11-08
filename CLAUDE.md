# RPG médiéval 3D — prototype de combat

Godot 4.7.2 (GDScript, Jolt Physics, 120 Hz physique). Tout le texte du jeu est en français.
Le propriétaire ne code pas : Claude écrit tout le code et construit les scènes (en code).
Projet 100 % gratuit ; chaque ressource externe va dans `CREDITS.md`.

## Objectif
Prototype de COMBAT UNIQUEMENT dans une arène de test (pas de monde/quêtes/inventaire) :
savoir si le combat est amusant. Toutes les valeurs de réglage sont dans `scripts/game_config.gd`.

## Commandes
- Godot console : `E:\_jeu perso\godot\Godot_v4.7.2-stable_win64_console.exe`
- Import : `godot --headless --path . --import`
- Tests : `godot --headless --path . --fixed-fps 120 -s tests/run_tests.gd` (code de sortie 1 si échec)
- Lancer le jeu : ouvrir le projet dans l'éditeur Godot puis F5.

## Architecture (scripts/)
- `game_config.gd` — TOUS les réglages (const). `input_setup.gd` — autoload, actions clavier/manette (touches physiques → ZQSD ok en AZERTY).
- `main.gd` — assemble arène, héros, mannequin, HUD ; R = réinitialiser.
- `arena.gd` — sol, murs, piliers, plateforme+rampe, lumière (tout en code, shader damier).
- `player.gd` — CharacterBody3D : marche/course/saut/roulade. `camera_rig.gd` — 3e/1re personne (SpringArm3D), touche V.
- `training_dummy.gd` — mannequin, affiche les dégâts. `hud.gd` — aide + état.
- Couches physiques : 1 monde, 2 joueur, 3 ennemis.

## Contrôles
ZQSD/stick G déplacer · souris/stick D regarder · Maj courir · Espace sauter · C roulade · V changer de vue · F coup de test · R reset · Échap libère la souris.

## Avancement
- [x] Étape 1 — Base : arène, héros, caméra 3e/1re personne, mannequin
- [ ] Étape 2 — Corps à corps 4 directions, parade, endurance
- [ ] Étape 3 — Ennemi IA
- [ ] Étape 4 — Arc / arbalète
- [ ] Étape 5 — Animations Mixamo, vrais modèles
- [ ] Étape 6 — Game feel, sons

## Règles du combat
(à compléter à l'étape 2)
