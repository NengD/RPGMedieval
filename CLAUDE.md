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
- `hero_model.gd` — chevalier Mixamo animé (héros ET ennemi) : AnimationTree = Loco (BlendSpace2D) → haut du corps (filtre os Spine et enfants : attaque / parade / coup reçu) → corps entier (esquive / saut / mort). Les attaques sont « scrubbées » par TimeSeek au rythme du Combatant (contact visuel = début du coup). Épée en BoneAttachment3D (main droite).
- `arrow.gd` — flèche/carreau (gravité, rayon balayé, reste planté, max MAX_STUCK_ARROWS). `archery_target.gd` — cibles 10/5/2 pts. `ranged_visual.gd` — arc et arbalète en formes simples (à remplacer par les animations à l'étape 5, lot 2).
- Couches physiques : 1 monde, 2 joueur, 3 ennemis.

## Contrôles
F1/F2/F3 difficulté de l'ennemi (D-pad haut = suivante) · R recommencer le combat · ZQSD/stick G déplacer · souris/stick D regarder + choisir la direction · Maj courir · Espace sauter · C pas de côté · V changer de vue · Tab/molette changer d'arme (épée, arc, arbalète) · clic gauche (RB) attaquer/bander/tirer · clic droit (LB) parer ou annuler la corde · Retour arrière retire les flèches · T mannequin agressif · R reset · Échap libère la souris.

## Avancement
- [x] Étape 1 — Base : arène, héros, caméra 3e/1re personne, mannequin
- [x] Étape 2 — Corps à corps 4 directions, parade directionnelle + parfaite, endurance (animations = poses codées)
- [x] Étape 3 — Ennemi IA (approche, tourne autour, attaque variée, parade imparfaite, recule épuisé, 3 difficultés)
- [x] Étape 4 — Arc / arbalète (trajectoire, tension, flèches plantées, cibles, ennemi qui pare les tirs ou se met à couvert)
- [~] Étape 5 — Animations Mixamo : FAIT = chevalier animé (héros + ennemi teinté), AnimationTree (jambes + haut du corps), épée en main. RESTE = animations arc/arbalète (Pro Longbow Pack, Pro Rifle Pack), armes/bouclier gratuits (Quaternius…), garde par direction
- [ ] Étape 6 — Game feel, sons

## Règles du combat
- 4 directions : 0 haut, 1 droite, 2 estoc (ex-« bas »), 3 gauche. L'estoc = coup pointé droit devant : plus de portée, cône plus étroit (ATTACK_REACH / ATTACK_ARC_DEG). Direction choisie par le mouvement de souris / stick droit récent ; elle reste affichée (chevrons autour du centre). Attaquer / parer utilisent la direction courante.
- Attaque = préparation → coup (touche une fois, cône devant, portée MELEE_RANGE) → récupération. Un clic pendant la récupération est mémorisé.
- Pas de feinte (retirée à la demande du propriétaire).
- Parade : maintenir clic droit, du côté d'où vient le coup *à l'écran* (gauche/droite inversés par rapport à la direction d'attaque : `Combatant.mirror`). Haut/bas identiques.
- Parade parfaite : garde levée (ou direction changée) depuis ≤ PERFECT_PARRY_WINDOW à l'impact → pas de dégâts, attaquant déséquilibré PARRY_STAGGER s (+50 % de dégâts sur lui).
- Parade normale : coûte endurance = dégâts. Pas assez d'endurance → garde brisée (déséquilibre + 40 % des dégâts).
- Endurance : attaque, pas de côté, parade en consomment ; à 0 on est ÉPUISÉ jusqu'à EXHAUSTED_RECOVER (ni attaque, ni garde, ni esquive).
- Pas de côté (C) : invulnérable une courte fenêtre, peut interrompre une récupération.
- Tout est réglable dans game_config.gd (section COMBAT).

## IA de l'ennemi (étape 3)
- Modes : s'approche (> 3,4 m) → tourne autour (rayon ~2,6 m, change de sens au hasard, anti-blocage) → attaque (cooldown AI_ATTACK_INTERVAL, endurance ≥ 30) ; recule quand épuisé ou endurance < 20 jusqu'à 65.
- Direction d'attaque pondérée : évite de répéter les 2 dernières, évite parfois la direction que le joueur garde (AI_SMART_CHANCE), seul l'estoc si trop loin pour une taille.
- Parade imparfaite : à chaque coup du joueur il tire au sort s'il pare (AI_PARRY_CHANCE), met AI_REACTION_TIME à réagir, peut garder du mauvais côté (AI_WRONG_SIDE_CHANCE), peut viser la parade parfaite (lève la garde juste avant l'impact).
- Parade volontairement faible (réglée après retour du propriétaire) : AI_PARRY_CHANCE, AI_REACTION_TIME, AI_WRONG_SIDE_CHANCE.
- Vaincu → "ENNEMI VAINCU" puis combat relancé ; changer de difficulté relance le combat.
- Pas encore : se protéger des flèches / se mettre à couvert (étape 4).

## Combat à distance (étape 4)
- Arme : Tab / molette (D-pad gauche/droite). Avec arc ou arbalète le héros fait toujours face à la caméra (posture de visée), pas de garde.
- Arc : maintenir clic gauche → tension 0→1 en BOW_DRAW_TIME ; relâcher tire (X annule ; touché / pas de côté annule aussi). Vitesse, dégâts et précision dépendent de la tension. Tenir la corde à fond fatigue.
- Arbalète : clic gauche tire tout de suite (presque droit, puissant), puis CROSSBOW_RELOAD_TIME de rechargement.
- Visée : le tir part de la main vers le point visé par le centre de l'écran (réticule) ; la gravité courbe la trajectoire (ARROW_GRAVITY). Tir à la tête (> HEAD_HEIGHT) = x1,5.
- Se protéger avec l'épée : la garde de face arrête les tirs (coût en endurance réduit) ; garde levée au dernier moment = tir renvoyé ; dos tourné ou garde brisée = touché.
- Ennemi face à un archer (> ~4 m) : il voit les flèches (selon AI_REACTION_TIME), lève la garde (AI_ARROW_GUARD_CHANCE), et soit se met à couvert derrière un pilier/une caisse (AI_COVER_CHANCE, max ENEMY_COVER_MAX_TIME), soit charge en zigzag.
- Cibles : 4 dans l'arène (une mobile). Score affiché dans le HUD.
- F4 (D-pad bas) coupe / remet l'IA de l'ennemi (`Enemy.ai_enabled`, valeur de départ : `ENEMY_AI_ENABLED_AT_START` dans game_config.gd). IA coupée = il reste immobile, ne frappe pas, ne pare pas.
- Visée (clic droit maintenu, arc/arbalète) : zoom (AIM_FOV_FACTOR_*), caméra 3e personne rapprochée (TPS_AIM_DISTANCE), souris moins sensible, déplacement lent, tir plus précis (AIM_SPREAD_FACTOR ; sans viser x HIPFIRE_SPREAD_FACTOR), distance affichée et (option AIM_SHOW_DROP_MARKER, désactivée par défaut) repère orange = point où le tir tombe vraiment (gravité). Avec l'épée le clic droit reste la parade.

## Animations (étape 5)
- Sources : `assets/hero/hero.fbx` (Paladin J Nordstrom, avec peau) et `assets/anims/*.fbx` (Pro Sword and Shield Pack, sans personnage). Le modèle regarde vers +Z (on le tourne de 180° dans HeroModel).
- `tools/bake_animations.gd` fabrique `assets/anims/hero_library.res` : noms clairs, déplacement de la racine retiré (« sur place »), boucles, instant du coup (`peak_time` en méta). À relancer si on change le pack : `godot --headless --path . -s tools/bake_animations.gd`.
- Correspondance : haut = axe « backhand » (le passage 1,05-1,85 s est un coup de haut en bas, instants réglés à la main dans le bake), droite = axe « horizontal », gauche = sword&shield « slash_3 » (attack_2 faisait un tourbillon de 400° : à éviter ; `tools/analyze_spin*.gd` mesurent la rotation du corps de chaque clip), estoc = axe « combo attack ver. 3 » (passage de la fente), garde = axe « standing block idle » (parade sans bouclier ; une seule posture pour les 4 directions), coups reçus = sword&shield impact 1-3, esquive = strafe_3/4 ou run_2 accélérés, mort = sword&shield death. Chaque attaque est mesurée au bake (début du geste, instant du coup = main la plus rapide, fin ; `spec[6]` permet de forcer ces 3 instants). Préparation du Combatant = de « début » à « coup », coup = geste qui suit, récupération = retour au repos. Quand le personnage est immobile (< ATTACK_FULLBODY_SPEED) l'attaque joue sur TOUT le corps ; en mouvement, seulement le haut du corps ;
- Réglages : `ANIM_CONTACT_OFFSET`, `ANIM_FOLLOW_THROUGH` dans game_config.gd. Outils de diagnostic : `tools/analyze_anims.gd`, `tools/hand_axes.gd`, `tools/inspect_fbx.gd`.
- En 1re personne le corps est caché : on garde l'épée à poses codées (`weapon_visual.gd`). Arc/arbalète en 3e personne : encore les formes codées en attendant les animations.
- Déplacement : en 3e personne le héros regarde TOUJOURS dans la direction de la caméra (il ne se tourne plus vers sa direction de marche) : marche arrière = à reculons, côtés = pas chassés (animations strafe/walk_b via le BlendSpace2D).
- PIÈGE AnimationTree : quand un TimeScale à 0 est après un nœud Transition (attaques pilotées par TimeSeek), le fondu (xfade) du Transition ne progresse jamais et la pose reste bloquée sur l'ancienne animation. Les Transition de HeroModel ont donc xfade_time = 0 (le lissage se fait via blend_amount).
- Test « comme un joueur » (sans l'éditeur) : envoyer des InputEventMouseMotion / InputEventMouseButton avec `root.push_input(...)` dans une fenêtre placée hors écran (`--position 6000,3000`) pour que la vraie souris ne perturbe pas.
- Choix de la direction (souris / stick) : seuil AIM_THRESHOLD = 70 px et dominance AIM_DOMINANCE = 1.4 (moins sensible : un petit mouvement de caméra ne change plus la direction). La préparation de l'attaque est lente puis accélère (ANIM_WINDUP_CURVE).
- ATTENTION aux tests fenêtrés pendant que le propriétaire joue : une fenêtre de test peut capter sa vraie souris / manette. `tests/real_input_attacks.gd` retire donc les commandes réelles et ne capture pas la souris.
- Coup d'en haut et estoc : la main est dirigée par `TwoBoneIK3D` (bras droit) dans HeroModel (`_build_ik`, `_ik_hand_position`, `_update_ik`) ; les autres attaques jouent l'animation telle quelle. Trajectoires de la main = constantes `IK_*` de game_config.gd (repère du personnage : +X droite, +Y haut, -Z devant) : levée au-dessus de la tête puis abattue devant pour « haut » ; ramenée en arrière puis tendue droit devant pour l'estoc. `IK_RAISE_SHARE` = part de la préparation passée à lever / armer, le reste = geste rapide avant le coup. Le reste du corps garde l'animation du pack.
- La lame est orientée par `HandAimModifier` (scripts/hand_aim_modifier.gd, SkeletonModifier3D placé APRÈS le TwoBoneIK3D) : lame vers le haut puis abattue vers l'avant et le bas pour « haut », droit devant pour l'estoc (constantes IK_BLADE_*). Base de « haut » = posture calme (sword&shield idle) pour que le corps ne se cambre pas ; la base de l'estoc reste la fente du pack hache.
- Pour comprendre un défaut vu par le propriétaire : il peut envoyer un enregistrement .mp4 (Outil Capture de Windows). Pas de ffmpeg sur sa machine : extraire les images avec Blender (`blender -b -P script.py`, voir l'historique : sequencer + new_movie + render.write_still) puis assembler une planche avec Godot (Image.blit_rect).
