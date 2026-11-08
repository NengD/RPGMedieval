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
- Tests (code de sortie 1 si échec) : `godot --headless --path . --fixed-fps 120 -s tests/run_tests.gd` (arène, déplacement, caméra, combat) et `... -s tests/combat_tests.gd` (logique pure du combat)
- Test du regard souris en fenêtre réelle : `godot --path . --resolution 960x540 -s tests/shot.gd` (affiche RESULTAT OK)
- Lancer le jeu : ouvrir le projet dans l'éditeur Godot puis F5.

## Architecture (scripts/)
- `game_config.gd` — TOUS les réglages (const). `input_setup.gd` — autoload, actions clavier/manette (touches physiques → ZQSD ok en AZERTY).
- `main.gd` — assemble arène, héros, mannequin, HUD ; R = réinitialiser.
- `arena.gd` — sol, murs, piliers, plateforme+rampe, lumière (tout en code, shader damier).
- `player.gd` — CharacterBody3D : marche/course/saut/pas de côté. `camera_rig.gd` — 3e/1re personne (SpringArm3D), touche V.
- `combatant.gd` — cerveau du combat (états, parade, endurance, vie), réutilisé par le héros, le mannequin et l'ennemi (étape 3).
- `weapon_visual.gd` — épée en formes simples, poses par code selon l'état. `training_dummy.gd` — mannequin (T = agressif).
- `hud.gd` + `hud_canvas.gd` — aide, messages, barres vie/endurance, indicateur de direction (JAMAIS de Control qui bloque la souris : mouse_filter = IGNORE).
- Couches physiques : 1 monde, 2 joueur, 3 ennemis.

## Contrôles
F1/F2/F3 difficulté de l'ennemi (D-pad haut = suivante) · R recommencer le combat · ZQSD/stick G déplacer · souris/stick D regarder + choisir la direction · Maj courir · Espace sauter · C pas de côté · V changer de vue · clic gauche (RB) attaquer · clic droit (LB) parer / feinter · T mannequin agressif · R reset · Échap libère la souris.

## Avancement
- [x] Étape 1 — Base : arène, héros, caméra 3e/1re personne, mannequin
- [x] Étape 2 — Corps à corps 4 directions, feinte, parade directionnelle + parfaite, endurance (animations = poses codées)
- [x] Étape 3 — Ennemi IA (approche, tourne autour, attaque variée, parade imparfaite, recule épuisé, 3 difficultés)
- [ ] Étape 4 — Arc / arbalète
- [ ] Étape 5 — Animations Mixamo, vrais modèles
- [ ] Étape 6 — Game feel, sons

## Règles du combat
- 4 directions : 0 haut, 1 droite, 2 estoc (ex-« bas »), 3 gauche. L'estoc = coup pointé droit devant : plus de portée, cône plus étroit (ATTACK_REACH / ATTACK_ARC_DEG). Direction choisie par le mouvement de souris / stick droit récent ; elle reste affichée (chevrons autour du centre). Attaquer / parer utilisent la direction courante.
- Attaque = préparation (feintable) → coup (touche une fois, cône devant, portée MELEE_RANGE) → récupération. Un clic pendant la récupération est mémorisé.
- Feinte : clic droit pendant la préparation (coûte un peu d'endurance).
- Parade : maintenir clic droit, du côté d'où vient le coup *à l'écran* (gauche/droite inversés par rapport à la direction d'attaque : `Combatant.mirror`). Haut/bas identiques.
- Parade parfaite : garde levée (ou direction changée) depuis ≤ PERFECT_PARRY_WINDOW à l'impact → pas de dégâts, attaquant déséquilibré PARRY_STAGGER s (+50 % de dégâts sur lui).
- Parade normale : coûte endurance = dégâts. Pas assez d'endurance → garde brisée (déséquilibre + 40 % des dégâts).
- Endurance : attaque, feinte, pas de côté, parade en consomment ; à 0 on est ÉPUISÉ jusqu'à EXHAUSTED_RECOVER (ni attaque, ni garde, ni esquive).
- Pas de côté (C) : invulnérable une courte fenêtre, peut interrompre une récupération.
- Tout est réglable dans game_config.gd (section COMBAT).

## IA de l'ennemi (étape 3)
- Modes : s'approche (> 3,4 m) → tourne autour (rayon ~2,6 m, change de sens au hasard, anti-blocage) → attaque (cooldown AI_ATTACK_INTERVAL, endurance ≥ 30) ; recule quand épuisé ou endurance < 20 jusqu'à 65.
- Direction d'attaque pondérée : évite de répéter les 2 dernières, évite parfois la direction que le joueur garde (AI_SMART_CHANCE), seul l'estoc si trop loin pour une taille.
- Parade imparfaite : à chaque coup du joueur il tire au sort s'il pare (AI_PARRY_CHANCE), met AI_REACTION_TIME à réagir, peut garder du mauvais côté (AI_WRONG_SIDE_CHANCE), peut viser la parade parfaite (lève la garde juste avant l'impact). Les feintes du joueur le piègent s'il a levé la garde tôt.
- Il peut feinter ses propres attaques (AI_FEINT_CHANCE) puis enchaîner.
- Vaincu → "ENNEMI VAINCU" puis combat relancé ; changer de difficulté relance le combat.
- Pas encore : se protéger des flèches / se mettre à couvert (étape 4).
