# Détails techniques (référence)

Notes détaillées sorties de `CLAUDE.md` pour le garder lisible. À lire quand on touche au combat, aux animations, aux armes ou à la visée.

## Combat (`combatant.gd`, valeurs dans `game_config.gd`)
- Pas de choix de direction : un clic = le coup suivant d'un COMBO (`WeaponData.combo_order`, par défaut `COMBO_ORDER` = droite, gauche, haut, estoc ; `COMBO_RESET_TIME` : sans attaquer on repart du premier ; `Combatant.request_attack()` sans argument = coup suivant, `combo_index`). Les index internes restent 0 haut, 1 droite, 2 estoc, 3 gauche (animation, pose, ligne de chiffres) ; `attack_dir` = coup en cours. L'estoc a plus de portée et un cône étroit.
- Attaque = préparation → coup (touche une fois, cône devant, portée `MELEE_RANGE` + portée du coup) → récupération. Un clic pendant la récupération est mémorisé. Pas de feinte.
- Parade : clic droit maintenu, une seule parade qui arrête tous les coups de face (pose `GUARD_POSE`). Parfaite si la garde est levée depuis ≤ `PERFECT_PARRY_WINDOW` (pas de dégâts, attaquant déséquilibré `PARRY_STAGGER` s, +50 % de dégâts sur lui). Normale : coûte endurance = dégâts (× `guard_cost_factor` de l'écu). Pas assez d'endurance : garde brisée (déséquilibre + 40 % des dégâts).
- Endurance : attaque, pas de côté et parade en consomment ; à 0 on est ÉPUISÉ jusqu'à `EXHAUSTED_RECOVER`. Pas de côté (C) : invulnérable une courte fenêtre, peut interrompre une récupération.
- Dégâts : `DamagePacket` (tranchant / contondant / perforant) réduits par la protection de la tenue (`combatant.protection`) ; seul ce qui PASSE est réduit (le coût d'une parade ne change pas).
- Recul : `Combatant.knockback` (selon dégâts, type, poids porté).

## IA de l'ennemi (`enemy.gd`)
- Modes : s'approche (> 3,4 m) → tourne autour (rayon ≈ 2,6 m, sens aléatoire, anti-blocage) → attaque (`AI_ATTACK_INTERVAL`, endurance ≥ 30) ; recule quand épuisé ou endurance < 20 jusqu'à 65. Coup choisi au hasard (évite de répéter les 2 derniers, seul l'estoc si trop loin).
- Parade volontairement faible : `AI_PARRY_CHANCE`, `AI_REACTION_TIME`, peut viser la parade parfaite.
- Vaincu → « ENNEMI VAINCU » puis combat relancé ; changer de difficulté (F1/F2/F3) relance le combat. F4 coupe / remet l'IA (`Enemy.ai_enabled`).
- Face à un archer (> ~4 m) : il voit les flèches (`AI_REACTION_TIME`), lève la garde (`AI_ARROW_GUARD_CHANCE`), et se met à couvert derrière un pilier / une grande caisse (`AI_COVER_CHANCE`, `ENEMY_COVER_MAX_TIME`) ou charge en zigzag. Les obstacles de moins de 1,2 m ou trop fins ne doivent PAS être des abris (`Arena.cover_objects`), sinon le test « il se cache vraiment » échoue.

## Combat à distance
- Arme : Tab / molette. Avec arc ou arbalète le héros fait toujours face à la caméra, pas de garde.
- Arc : clic gauche maintenu → tension 0→1 en `BOW_DRAW_TIME` ; relâcher tire (X annule). Vitesse, dégâts et précision dépendent de la tension ; tenir la corde fatigue. Arbalète : tir immédiat puis `CROSSBOW_RELOAD_TIME` de rechargement.
- Visée (clic droit) : zoom (`AIM_FOV_FACTOR_*`), caméra rapprochée (`TPS_AIM_DISTANCE`) passée du côté de l'arme (`CameraRig.aim_side` ← `AIM_CAMERA_SIDE_BOW/XBOW`, épaule droite pour les deux), souris moins sensible, déplacement lent, tir plus précis. Le tir part de la main vers le point visé par le réticule ; gravité (`ARROW_GRAVITY`). Tir à la tête (> `HEAD_HEIGHT`) ×1,5.
- Se protéger avec l'épée : la garde de face arrête les tirs ; garde levée au dernier moment = tir renvoyé.

## Personnage, animations et armes en main
- Corps : `assets/base/base_rig.tscn` (squelette du Mannequin Mixamo, os `mixamorig_*`, sans maillage) + `body.glb` (9 régions) ; pièces `assets/armor/*.glb` rattachées au squelette PAR NOM d'os (`scripts/character/rig_mesh.gd`) — jamais avec le squelette du .glb, dont les orientations d'os diffèrent et casseraient les animations. Voir `docs/AJOUTER_UNE_PIECE.md`. Le chevalier Paladin (`assets/hero/`) n'est plus utilisé.
- `hero_model.gd` : AnimationTree = Loco (BlendSpace2D, trois jeux : épée / arc / arbalète, fondus par `WeaponBlend`, `WeaponBlend2`) → haut du corps (filtre Spine et enfants : attaque / parade / coup reçu / bandage) → corps entier (esquive / saut). Les attaques et le bandage sont « scrubbés » par TimeSeek au rythme du Combatant (contact visuel = début du coup).
- `tools/bake_animations.gd` fabrique `assets/anims/hero_library.res` : noms clairs, déplacement de la racine retiré (« sur place », vitesse d'origine gardée dans la méta `root_speed`), boucles, instants du geste (`start_time`, `peak_time`, `end_time`, forçables par `spec[6]`). À relancer si on change un pack : `godot --headless --path . -s tools/bake_animations.gd`. Packs utilisés (sources dans `assets/anims/*.fbx`) : Pro Sword and Shield, Pro Melee Axe, Pro Longbow, Pro Rifle (voir `CREDITS.md`).
- Correspondance : haut = axe « backhand », droite = axe « horizontal », gauche = sword&shield « slash_3 » (attack_2 faisait un tourbillon de 400° ; `tools/analyze_spin*.gd` mesurent la rotation du corps de chaque clip), estoc = axe « combo attack ver. 3 », garde = sword&shield idle + IK du bras, coups reçus = impact 1-3 et réactions du pack hache, esquive = strafe_3/4 ou run_2 accélérés. Immobile (< `ATTACK_FULLBODY_SPEED`) l'attaque joue sur TOUT le corps ; en mouvement, seulement le haut.
- Déplacement : en 3e personne le héros regarde TOUJOURS dans la direction de la caméra (marche arrière = à reculons, côtés = pas chassés).
- PIÈGE AnimationTree : un TimeScale à 0 placé après un nœud Transition (attaques pilotées par TimeSeek) fige le fondu de la Transition. Les Transition de HeroModel ont donc `xfade_time` = 0 (le lissage se fait via `blend_amount`).
- Cinématique inverse : bras droit (`ik` : coup d'en haut, estoc, parade, arbalète), bras gauche (`ik_l` : arc, arbalète, écu en parade, armes à deux mains, parade sans écu), jambes (`FootIK`). Points demandés aux mains calculés par `_compute_grips` à partir des épaules et de la direction visée, jamais des os animés. `HandAimModifier` oriente la lame. Constantes `IK_*` (repère du personnage : +X droite, +Y haut, −Z devant). ATTENTION : les os animés par IK ne se lisent PAS en mode sans fenêtre ; les tests vérifient les cibles et la portée des bras, le rendu se juge sur captures.
- Armes : `WeaponData` / `AttackStep` / `WeaponCategory` / `AmmoData` (voir `docs/AJOUTER_UNE_ARME.md`). `HeroModel.apply_weapons` (3e personne), `WeaponVisual.set_weapon_model` et `RangedVisual.set_weapons` (1re personne : épée à poses codées), `Arrow` lit le modèle de la munition. Arc : porté dans le dos (`BOW_BACK_*`) tant qu'on ne vise pas ; arc et arbalète tournent visuellement le corps (`AIM_YAW_BOW/XBOW`, mesurés par `tools/aim_yaw.gd`) car les postures Mixamo sont de profil ; l'arme pointe vers le réticule (`HeroModel.aim_point`). L'écu est un nœud top_level posé devant l'avant-bras gauche.
- Animations naturelles : voir `docs/ANIMATIONS_NATURELLES.md`.

## Tests « comme un joueur » et captures
- Envoyer des `InputEventMouseMotion` / `InputEventMouseButton` avec `root.push_input(...)` dans une fenêtre placée hors écran (`--position 6000,3000`) : la vraie souris ne perturbe pas.
- Les tests fenêtrés peuvent capter la souris / la manette du propriétaire pendant qu'il joue : `tests/real_input_attacks.gd` retire les commandes réelles et ne capture pas la souris.
- Captures de contrôle : `tests/aim_look.gd` (vraie caméra de visée), `side_look.gd`, `parry_look.gd`, `weapons_look.gd`, `diag_look.gd`, `outfit_look.gd`, `armor_look.gd`, `arena_look.gd`, `polish_look.gd`, `hud_look.gd`, `perf_look.gd` (images dans `user://`).
- Comprendre un défaut vu par le propriétaire : un enregistrement `.mp4` (Outil Capture de Windows) ; pas de ffmpeg : extraire les images avec Blender (`blender -b -P script.py` : sequencer + `new_movie` + `render.write_still`) puis assembler une planche avec Godot (`Image.blit_rect`).
