# RPG médiéval 3D — prototype de combat

Godot 4.7.2 (GDScript, Jolt Physics, 120 Hz physique). Tout le texte du jeu est en français.
Le propriétaire ne code pas : Claude écrit tout le code et construit les scènes (en code).
Projet 100 % gratuit ; chaque ressource externe va dans `CREDITS.md`.

## RÈGLES PERMANENTES
- **TU FAIS TOUT TOI-MÊME.** Le propriétaire ne télécharge, ne filme et ne modélise plus rien. Claude télécharge lui-même les ressources gratuites et libres (CC0 de préférence : Poly Haven, Kenney, OpenGameArt, Freesound CC0…) et crée le reste avec Blender (MCP ou ligne de commande, dans une NOUVELLE scène, sans toucher aux `.blend` ouverts) et Godot. Ne plus demander d'aller sur Mixamo : ce qui manque se crée dans Blender sur le squelette Mixamo existant.
- Travail en arrière-plan : le propriétaire joue pendant que Claude travaille. Ne jamais prendre le focus ni capturer souris / clavier / manette ; Godot en `--headless` quand c'est possible ; captures dans une fenêtre hors écran (`--position 6000,3000`) sans lire les entrées réelles ; ne jamais fermer ni redémarrer ses programmes.
- Tout texte affiché passe par `tr("CLÉ")` (`locale/translations.csv`, colonnes keys,fr,en) ; jamais de texte en dur (testé).
- Chaque ressource externe ou créée est notée dans `CREDITS.md`. Toutes les valeurs de réglage sont dans `scripts/game_config.gd`.
- À chaque étape : tests qui passent, captures avant/après, résumé + liste de ce que le propriétaire doit tester, mise à jour de ce fichier / de `CREDITS.md` / des docs, commit en français, `git push`, puis S'ARRÊTER pour avoir son avis.
- Pas de `Control` qui bloque la souris dans l'interface (`mouse_filter = IGNORE`).

## Objectif
Prototype de COMBAT UNIQUEMENT dans une arène de test (pas de monde / quêtes / inventaire) : savoir si le combat est amusant, avec des fondations modulaires (données `.tres`) pour un futur RPG.

## Commandes
- Godot console : `E:\_jeu perso\godot\Godot_v4.7.2-stable_win64_console.exe` (abrégé `godot`). Blender : `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` (ligne de commande, `-b --factory-startup -P script.py`).
- Import : `godot --headless --path . --import`
- Tests (code de sortie 1 si échec), tous les trois doivent passer : `godot --headless --path . --fixed-fps 120 -s tests/run_tests.gd` (arène, déplacement, caméra, combat), `... -s tests/combat_tests.gd` (logique pure du combat), `... -s tests/rpg_tests.gd` (stats, dégâts/armures, identifiants, sauvegarde, traduction, équipement, armes, personnage modulaire, arène, animations, interface).
- Lancer le jeu : ouvrir le projet dans l'éditeur Godot puis F5.

## Contrôles (aide en jeu : F6)
ZQSD / stick G déplacer · souris / stick D regarder · Maj courir · Espace sauter · C pas de côté · V changer de vue · Tab / molette arme (épée, arc, arbalète) · clic gauche attaquer (clics répétés = combo) / bander / tirer · clic droit parer ou viser · G arme de mêlée suivante · H écu · K tenue · L couleur du tabard · F1/F2/F3 difficulté · F4 IA ennemie · R recommencer · T mannequin agressif · Retour arrière retire les flèches · F5 / F9 sauvegarde / chargement rapides · F10 qualité graphique · F6 aide · F7 infos de débogage · Échap libère la souris.

## Architecture (dossiers)
- `scripts/` : `game_config.gd` (TOUS les réglages), `main.gd` (assemble la scène), `arena.gd` + `quality_settings.gd`, `player.gd` + `camera_rig.gd`, `enemy.gd` (IA), `training_dummy.gd`, `combatant.gd` (cerveau du combat : états, parade, endurance, vie ; partagé par héros, ennemi, mannequin), `hero_model.gd` (personnage animé : AnimationTree, IK, armures, armes), `weapon_visual.gd` / `ranged_visual.gd` (armes en 1re personne), `arrow.gd`, `archery_target.gd`, `hud.gd` + `hud_canvas.gd` (interface), `input_setup.gd` (actions clavier / manette), `floating_text.gd`, `hand_aim_modifier.gd`.
- `scripts/rpg/` : stats, types de dégâts, armures, armes, équipement, registre d'identifiants, sauvegarde (voir `docs/FONDATIONS_RPG.md`).
- `scripts/character/` : `rig_mesh.gd` (pièces rattachées au squelette par nom d'os), `foot_ik.gd`, `ragdoll.gd`.
- `data/` : fichiers `.tres` (matières, armures, tenues, armes, catégories, munitions, formules de stats). `assets/` : `base/` (squelette + corps), `armor/`, `weapons/`, `props/`, `textures/`, `sky/`, `anims/` (FBX Mixamo + `hero_library.res`). `tools/` : scripts de fabrication (`bake_animations.gd`, `make_data.gd`, `make_base_rig.gd`, `blender/*.py`) et de mesure. `tests/` : tests et scripts de capture. `docs/` : documentation.
- Couches physiques : 1 monde, 2 joueur, 3 ennemis.

## Documentation (docs/)
- `DETAILS_TECHNIQUES.md` — combat, IA, visée, animations, IK, pièges Godot, méthode de test « comme un joueur ».
- `ARCHITECTURE.md` — architecture du chantier réalisme + RPG ; `FONDATIONS_RPG.md` — stats, dégâts, identifiants, sauvegarde, traduction.
- `AJOUTER_UNE_ARME.md`, `AJOUTER_UNE_PIECE.md`, `ARENE_ET_LUMIERE.md`, `ANIMATIONS_NATURELLES.md`, `GUIDE_MIXAMO.md` (historique des packs Mixamo utilisés).

## Avancement
Chantier « réalisme + RPG » (étapes numérotées dans la conversation du propriétaire) :
- [x] 0 Sauvegarde GitHub (https://github.com/NengD/RPGMedieval, branche `main`) · [x] 1 Diagnostic et architecture · [x] 2 Fondations RPG · [x] 3 Armes extensibles (11 modèles Blender) · [x] 4 Personnage modulaire (Mannequin + 17 pièces + 3 tenues) · [x] 5 Arène PBR, ciel HDRI, qualité F10 · [x] 6 Animations plus naturelles (cadence, pieds, regard, réactions, ragdoll).
- [x] 7 Remise en ordre : ce fichier allégé, aide masquée (F6), panneau de débogage séparé (F7), HUD sobre.
- [ ] 8 Réalisme visuel du chevalier (matériaux d'armure, tête et visage, mains, proportions des armes).
- [ ] 9 Animations créées dans Blender (corriger les limites de `ANIMATIONS_NATURELLES.md`, retravailler les clips Mixamo, créer attaques et parades par catégorie d'arme).
- [ ] 10 Game feel et sons (arrêt sur image, tremblement, étincelles, ralenti, sons CC0 ou générés, bus audio, menu d'options). C'est l'ancienne « étape 6 — Game feel, sons » du plan d'origine.
Historique du prototype d'origine : combat à 4 directions puis combo (direction retirée), IA, arc / arbalète, animations Mixamo (chevalier Paladin, remplacé par le Mannequin modulaire à l'étape 4).
