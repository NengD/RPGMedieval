class_name GameConfig
extends RefCounted
## TOUTES les valeurs de réglage du jeu sont ici.
## Modifie un nombre, enregistre, relance le jeu : c'est tout.
## (Unités : mètres, secondes, degrés sauf mention contraire.)

# --- Couches de collision (ne pas toucher) ---
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4

# --- Arène ---
const ARENA_HALF_SIZE := 15.0        # l'arène fait 30 m x 30 m
const WALL_HEIGHT := 6.0
const RAMP_ANGLE_DEG := 20.0         # pente de la rampe
const PLATFORM_HEIGHT := 1.5

# --- Héros : corps ---
const PLAYER_RADIUS := 0.4
const PLAYER_HEIGHT := 1.8
const EYE_HEIGHT := 1.65             # hauteur des yeux (vue 1re personne)
const MAX_SLOPE_DEG := 45.0          # pente maximale que le héros peut monter

# --- Héros : déplacement ---
const WALK_SPEED := 3.5              # marche (m/s)
const RUN_SPEED := 6.5               # course, touche Maj (m/s)
const ACCELERATION := 40.0           # vitesse de mise en mouvement
const DECELERATION := 50.0           # vitesse d'arrêt
const AIR_CONTROL := 0.35            # contrôle en l'air (0 = aucun, 1 = total)
const TURN_SPEED := 14.0             # vitesse de rotation du corps (3e personne)
const GRAVITY := 20.0
const JUMP_VELOCITY := 6.5           # force du saut
const COYOTE_TIME := 0.10            # saut encore possible juste après avoir quitté le bord
const JUMP_BUFFER := 0.12            # saut mémorisé si pressé juste avant l'atterrissage

# --- Héros : esquive (pas de côté rapide, touche C) ---
const DODGE_SPEED := 7.0             # vitesse de départ du pas (m/s)
const DODGE_DURATION := 0.32         # durée du pas (distance ~ 1,5 m)
const DODGE_COOLDOWN := 0.20         # pause avant de pouvoir esquiver à nouveau
const DODGE_IFRAME_START := 0.03     # début de l'invulnérabilité (s depuis le début)
const DODGE_IFRAME_END := 0.22       # fin de l'invulnérabilité
const DODGE_LEAN := 0.35             # inclinaison du corps pendant le pas (radians)

# --- Caméra ---
const MOUSE_SENSITIVITY := 0.0025    # radians par pixel de souris
const STICK_SENSITIVITY := 3.2       # radians par seconde, stick à fond
const INVERT_Y := false
const TPS_DISTANCE := 3.6            # distance caméra - héros (3e personne)
const TPS_SHOULDER := 0.55           # décalage de la caméra par-dessus l'épaule (3e personne)
const TPS_AIM_SHOULDER_FACTOR := 0.3   # en visée à l'arc / arbalète : décalage d'épaule multiplié par ça (1 = comme hors visée, 0 = caméra derrière la tête)
const TPS_PITCH_MIN_DEG := -60.0
const TPS_PITCH_MAX_DEG := 35.0
const FPS_PITCH_LIMIT_DEG := 85.0
const FOV_TPS := 70.0
const FOV_FPS := 82.0
const CAMERA_SWITCH_TIME := 0.25     # durée de la transition V
const CAMERA_FOLLOW_RATE := 30.0     # lissage du suivi (plus haut = plus rigide)
const CAMERA_WALL_MARGIN := 0.25     # distance gardée avec les murs

# --- Mannequin d'entraînement ---
const DUMMY_RADIUS := 0.45
const DUMMY_HEIGHT := 1.8

# ============================================================
# COMBAT CORPS À CORPS (étape 2)
# Les 4 directions, toujours dans cet ordre : 0 haut, 1 droite, 2 bas, 3 gauche.
# "droite/gauche" = côté d'où part le coup, du point de vue de celui qui frappe.
# Pour parer, il faut garder le côté opposé du point de vue de l'attaquant
# = le côté d'où le coup t'arrive à l'écran (haut/bas restent haut/bas).
# ============================================================
const DIR_NAMES := ["DIR_UP", "DIR_RIGHT", "DIR_STAB", "DIR_LEFT"]   # clés de traduction (l'estoc = coup pointé droit devant)

# Une attaque = préparation -> coup (touche) -> récupération.
const ATTACK_WINDUP   := [0.65, 0.48, 0.45, 0.48]   # préparation (s)
const ATTACK_STRIKE   := [0.14, 0.12, 0.12, 0.12]   # durée où le coup peut toucher (s)
const ATTACK_RECOVERY := [0.55, 0.45, 0.45, 0.45]   # récupération (s)
const ATTACK_DAMAGE   := [28.0, 20.0, 24.0, 20.0]   # dégâts
const ATTACK_STAMINA  := [30.0, 24.0, 24.0, 24.0]   # endurance consommée en lançant l'attaque (les coups plus longs laissent plus de temps pour récupérer : coûts relevés)
const ATTACK_REACH    := [0.0, 0.0, 0.7, 0.0]        # portée en plus (l'estoc porte plus loin)
const ATTACK_ARC_DEG  := [110.0, 110.0, 45.0, 110.0] # largeur du cône (l'estoc est étroit : il faut viser)
const ATTACK_BUFFER := 0.20          # un clic pendant la récupération est mémorisé (s)
const MELEE_RANGE := 2.3             # portée de l'épée (m, depuis le centre du corps)
const AIM_ASSIST_RANGE := 4.0        # (3e personne) le héros se tourne vers un ennemi proche
const AIM_ASSIST_ANGLE_DEG := 40.0
const COMBAT_TURN_SPEED := 30.0      # vitesse à laquelle le corps se tourne vers la caméra en combat

# Choix de la direction à la souris / au stick droit

# Parade
const PERFECT_PARRY_WINDOW := 0.20   # parade parfaite : garde levée depuis moins de X s à l'impact
const PARRY_STAGGER := 1.10          # durée de déséquilibre de l'attaquant après une parade parfaite
const BLOCK_STAMINA_FACTOR := 1.0    # endurance perdue en parant = dégâts du coup x ce facteur
const GUARD_BREAK_STAGGER := 1.30    # déséquilibre quand la garde se brise
const GUARD_BREAK_DAMAGE_FACTOR := 0.4   # part des dégâts subis quand la garde se brise
const HIT_STUN := 0.35               # étourdissement quand on est touché
const STAGGER_DAMAGE_BONUS := 1.5    # un adversaire déséquilibré prend plus de dégâts
const ATTACK_MOVE_FACTOR := 0.45     # vitesse de déplacement pendant une attaque
const GUARD_MOVE_FACTOR := 0.55      # vitesse de déplacement en gardant

# Endurance (même règles pour le héros et les ennemis)
const STAMINA_MAX := 100.0
const STAMINA_REGEN := 30.0          # points par seconde
const STAMINA_REGEN_DELAY := 0.7     # pause avant que l'endurance remonte (s)
const EXHAUSTED_DELAY := 1.4         # pause plus longue quand on tombe à 0
const EXHAUSTED_RECOVER := 25.0      # il faut remonter à cette valeur pour agir de nouveau
const DODGE_STAMINA := 18.0

# Santé
const PLAYER_MAX_HEALTH := 100.0
const RESPAWN_DELAY := 2.0

# Mannequin agressif (touche T) : sert à s'entraîner à parer
const PRACTICE_INTERVAL := 2.6       # secondes entre deux attaques
const PRACTICE_SPEED_SCALE := 0.7    # < 1 = attaques plus lentes (plus faciles à lire)
const PRACTICE_DIRECTION := -1       # -1 = au hasard, 0 haut, 1 droite, 2 bas, 3 gauche
const PRACTICE_DAMAGE_SCALE := 0.6   # le mannequin frappe moins fort

# ============================================================
# ENNEMI (étape 3) — IA et difficulté
# Les listes ont 3 valeurs : [Facile, Normal, Difficile].
# Touches en jeu : F1 facile · F2 normal · F3 difficile.
# ============================================================
const DIFFICULTY_NAMES := ["DIFF_EASY", "DIFF_NORMAL", "DIFF_HARD"]   # clés de traduction
const DEFAULT_DIFFICULTY := 1
const ENEMY_AI_ENABLED_AT_START := true   # false = l'ennemi reste immobile et inoffensif au départ (touche F4 en jeu)
const AI_REACTION_TIME := [0.40, 0.28, 0.18]          # délai avant de réagir à ton coup (s) : plus c'est long, moins il pare
const AI_PARRY_CHANCE := [0.08, 0.17, 0.32]       # chance de parer un coup (il n'y a plus de mauvais côté : valeurs réduites pour garder une parade faible)
const AI_PERFECT_PARRY_CHANCE := [0.0, 0.04, 0.12]    # parmi les parades : tentative de parade parfaite
const AI_ATTACK_INTERVAL := [2.4, 1.6, 0.9]           # pause moyenne entre deux attaques (s)
const AI_SPEED_SCALE := [0.75, 0.90, 1.05]            # vitesse de ses attaques (1 = comme toi)
const AI_DAMAGE_SCALE := [0.6, 0.8, 1.0]              # force de ses coups
const AI_MAX_HEALTH := [70.0, 100.0, 130.0]           # points de vie

const ENEMY_RADIUS := 0.4
const ENEMY_HEIGHT := 1.8
const ENEMY_WALK_SPEED := 3.0
const ENEMY_CIRCLE_SPEED := 2.2
const ENEMY_RETREAT_SPEED := 3.2
const ENEMY_ACCELERATION := 20.0
const ENEMY_ENGAGE_DISTANCE := 3.0        # il s'approche jusqu'à cette distance
const ENEMY_CIRCLE_DISTANCE := 2.6        # distance gardée quand il tourne autour de toi
const ENEMY_RETREAT_DISTANCE := 5.5       # distance où il se met en sécurité quand il est fatigué
const ENEMY_RETREAT_STAMINA := 20.0       # il recule sous cette endurance
const ENEMY_RESUME_STAMINA := 65.0        # il revient au combat au-dessus de cette endurance
const ENEMY_MIN_ATTACK_STAMINA := 30.0    # endurance minimale pour lancer une attaque

# ============================================================
# COMBAT À DISTANCE (étape 4) — arc et arbalète
# Changer d'arme : Tab ou molette de la souris (D-pad droit sur manette).
# ============================================================
const WEAPON_NAMES := ["WEAPON_SWORD", "WEAPON_BOW", "WEAPON_CROSSBOW"]   # clés de traduction

# Arc : maintenir le clic gauche pour bander, relâcher pour tirer (clic droit = annuler)
const BOW_DRAW_TIME := 1.1              # temps pour bander à fond (s)
const BOW_MIN_TENSION := 0.15           # en dessous, la corde est relâchée sans tirer
const BOW_SPEED_MIN := 14.0             # vitesse de la flèche corde à peine tendue (m/s)
const BOW_SPEED_MAX := 42.0             # vitesse à pleine tension
const BOW_DAMAGE_MIN := 8.0             # dégâts à peine tendu
const BOW_DAMAGE_MAX := 40.0            # dégâts à pleine tension
const BOW_SPREAD_DEG_MIN := 0.15        # imprécision à pleine tension (degrés)
const BOW_SPREAD_DEG_MAX := 4.0         # imprécision à peine tendu
const BOW_STAMINA_COST := 8.0           # endurance consommée au tir (x tension)
const BOW_HOLD_DRAIN := 12.0            # endurance perdue par seconde quand on tient la corde à fond
const BOW_MOVE_FACTOR := 0.5            # vitesse de déplacement en bandant
const BOW_RELEASE_COOLDOWN := 0.30      # pause après un tir

# Arbalète : clic gauche = tir immédiat, puis rechargement lent
const CROSSBOW_SPEED := 62.0
const CROSSBOW_DAMAGE := 52.0
const CROSSBOW_RELOAD_TIME := 2.4       # temps de rechargement (s)
const CROSSBOW_SPREAD_DEG := 0.25
const CROSSBOW_STAMINA_COST := 12.0
const CROSSBOW_MOVE_FACTOR := 0.8
const CROSSBOW_GRAVITY := 3.5           # le carreau tombe très peu : tir presque droit

# Flèches
const ARROW_GRAVITY := 12.0             # chute de la flèche (m/s²) : plus haut = trajectoire plus courbe
const ARROW_LIFETIME := 8.0
const MAX_STUCK_ARROWS := 80            # nombre de flèches gardées plantées (les plus anciennes disparaissent)
const HEADSHOT_MULTIPLIER := 1.5        # tir à la tête
const HEAD_HEIGHT := 1.45               # hauteur au-dessus des pieds à partir de laquelle c'est la tête

# Se protéger des tirs avec l'épée
const GUARD_ARC_DEG := 120.0            # la garde protège des tirs venant de face (cône)
const PROJECTILE_BLOCK_FACTOR := 0.6    # parer un tir coûte moins d'endurance qu'un coup d'épée
const PROJECTILE_STUN := 0.25           # étourdissement quand on est touché par un tir

# Cibles d'entraînement
const TARGET_RADIUS := 0.6
const TARGET_BULLSEYE := 0.12           # rayon du centre (10 points)
const TARGET_INNER := 0.30              # anneau du milieu (5 points) ; le reste = 2 points

# Ennemi face aux tirs (listes [Facile, Normal, Difficile])
const AI_ARROW_GUARD_CHANCE := [0.5, 0.75, 0.95]   # chance de lever la garde contre un tir qu'il voit venir
const AI_COVER_CHANCE := [0.35, 0.55, 0.75]        # chance de se mettre à couvert quand tu tires de loin
const ENEMY_COVER_MAX_TIME := 4.0                  # temps passé à couvert avant de ressortir (s)
const ENEMY_CHARGE_SPEED_FACTOR := 1.5             # vitesse de sa charge en zigzag
const ENEMY_ZIGZAG_SPEED := 3.0                    # amplitude latérale du zigzag

# ============================================================
# VISÉE (clic droit maintenu avec l'arc ou l'arbalète)
# ============================================================
const AIM_BLEND_TIME := 0.2             # durée de la transition vers la visée (s)
const AIM_FOV_FACTOR_BOW := 0.70        # zoom de l'arc : plus petit = plus de zoom
const AIM_FOV_FACTOR_CROSSBOW := 0.55   # zoom de l'arbalète
const TPS_AIM_DISTANCE := 2.0           # distance de la caméra en visée (3e personne)
const AIM_SENSITIVITY_FACTOR := 0.5     # la souris / le stick sont moins sensibles en visée
const AIM_MOVE_FACTOR := 0.4            # vitesse de déplacement en visée
const AIM_SPREAD_FACTOR := 0.3          # imprécision multipliée par ça en visée (plus précis)
const HIPFIRE_SPREAD_FACTOR := 1.6      # imprécision multipliée par ça quand on tire sans viser
const AIM_SHOW_DROP_MARKER := false     # true = affiche le repère orange (où le tir tombe vraiment) ; retiré par défaut

# ============================================================
# ANIMATIONS (étape 5)
# ============================================================
const ANIM_CONTACT_OFFSET := 0.05       # l'épée touche un peu après la vitesse maximale de la main (s d'animation)
const ANIM_WINDUP_CURVE := 1.8          # > 1 : la préparation est lente puis le geste accélère juste avant le coup (plus lisible)
const ANIM_FOLLOW_THROUGH := 0.25       # durée (s d'animation) du geste qui suit le contact
const ATTACK_FULLBODY_SPEED := 1.2      # sous cette vitesse (m/s), l'attaque joue sur tout le corps (plus naturel) ; au-dessus, seul le haut du corps attaque

# Coups d'en haut et estoc : la main est dirigée par cinématique inverse (positions de la main, en mètres,
# dans le repère du personnage : +X = sa droite, +Y = haut, -Z = devant).
const IK_REST        := Vector3(0.35, 1.05, -0.30)   # main au repos
const IK_UP_RAISED   := Vector3(0.40, 1.80, 0.20)    # coup d'en haut : main levée au-dessus et en arrière de l'épaule droite, coude plié
const IK_UP_CONTACT  := Vector3(0.40, 1.00, -0.85)   # ... et abattue devant, sur le côté du corps (visible de dos)
const IK_UP_FOLLOW   := Vector3(0.40, 0.80, -0.90)   # ... fin du geste
const IK_STAB_COCKED := Vector3(0.45, 1.20, 0.05)    # estoc : main ramenée en arrière, à l'extérieur du corps (sinon le bras traverse le torse)
const IK_STAB_CONTACT:= Vector3(0.42, 1.30, -1.00)   # ... bras tendu devant, sur le côté du corps
const IK_STAB_FOLLOW := Vector3(0.42, 1.30, -1.05)
const IK_POLE        := Vector3(1.10, 1.20, 0.50)    # direction du coude (vers l'extérieur et un peu l'arrière)
const IK_UP_RAISE_SHARE := 0.55                      # coup d'en haut : part de la préparation passée à lever (le reste = la descente, bien visible)
const IK_RAISE_SHARE := 0.72                         # part de la préparation passée à lever / armer ; le reste = le geste rapide
# Direction de la lame (repère du personnage, -Z = devant) pendant ces deux attaques
const IK_BLADE_UP_RAISED  := Vector3(0.0, 0.60, 0.80)    # lame inclinée vers l'arrière, au-dessus de l'épaule
const IK_BLADE_UP_CONTACT := Vector3(0.0, -0.55, -1.0)  # lame abattue vers l'avant et le bas
const IK_BLADE_STAB       := Vector3(0.0, 0.05, -1.0)   # estoc : lame droit devant
const IK_REST_BLADE := Vector3(0.0, 0.8, -0.6)       # direction de la lame au repos (vers le haut et l'avant)

# Parade : la main et la lame prennent une pose par direction (comme en 1re personne).
# Ordre : 0 haut, 1 droite, 2 bas, 3 gauche. Repère du personnage : +X = sa droite, +Y = haut, -Z = devant.
const IK_GUARD_HAND  := [Vector3(0.22, 1.88, -0.38), Vector3(0.16, 1.32, -0.55), Vector3(0.28, 0.98, -0.52), Vector3(-0.08, 1.38, -0.58)]
const IK_GUARD_BLADE := [Vector3(-1.0, 0.10, 0.0), Vector3(-0.35, 0.90, -0.30), Vector3(-0.75, -0.65, -0.15), Vector3(0.12, 1.0, -0.25)]
const IK_GUARD_SPEED := 10.0    # vitesse à laquelle la main rejoint la pose de garde (plus bas = geste plus doux, plus haut = plus vif)
const IK_GUARD_BLEND := 8.0    # vitesse à laquelle le bras passe de l'animation à la pose de garde

# Arc tenu en main (3e personne) : l'arc est placé dans la main gauche, vertical, la flèche droit devant
const BOW_GRIP_FORWARD := 0.05   # décalage de l'arc vers l'avant par rapport au poignet (m)


# Enchaînement (combo) : plus de choix de direction, chaque clic enchaîne le coup suivant
# (0 haut, 1 droite, 2 estoc, 3 gauche). Sans attaque pendant COMBO_RESET_TIME s, on repart du premier coup.
const COMBO_ORDER := [1, 3, 0, 2]
const COMBO_RESET_TIME := 1.1
# Une seule parade, quel que soit le coup : pose de garde utilisée (0 haut, 1 droite, 2 bas, 3 gauche)
const GUARD_POSE := 1

# Armes tenues (modèles .glb) : placement dans la main / sur l'avant-bras (3e personne)
const MELEE_GRIP_OFFSET := Vector3(0.0, 0.07, 0.0)       # décalage de la prise par rapport au poignet (repère de l'os de la main)
const FIRST_PERSON_WEAPON_SCALE := 1.2                   # l'arme est un peu agrandie en 1re personne (lisibilité)

# Arc porté dans le dos quand on ne vise pas
const BOW_BACK_TILT := 0.5     # inclinaison de l'arc (0 = vertical, 1 = 45°)
const BOW_BACK_DEPTH := 0.2    # distance derrière la colonne vertébrale (m)
const BOW_BACK_SIDE := 0.05    # décalage latéral (m)

# --- Prises à deux mains par cinématique inverse (bras gauche et droit) ---
const AIM_YAW_BOW := -0.12          # rotation du corps en visée à l'arc (rad) ; mesurée par tools/aim_yaw.gd
const AIM_YAW_XBOW := -0.53         # idem arbalète
const BOW_ARM_REACH := 0.43         # le bras de l'arc est tendu droit devant l'épaule gauche (m)
const BOW_ARM_SIDE := 0.10          # et un peu vers le centre (m)
const XBOW_GRIP_R_FWD := 0.30       # main arrière de l'arbalète : devant l'épaule droite (m)
const XBOW_GRIP_R_DOWN := 0.08      # sous le niveau de l'épaule (m)
const XBOW_GRIP_R_SIDE := -0.07     # vers le centre (négatif) (m)
# --- Écu : posé devant l'avant-bras gauche, face vers l'avant ---
const SHIELD_GUARD_HAND := Vector3(-0.20, 1.28, -0.42)   # où l'avant-bras gauche amène l'écu en parade (repère du personnage)
const SHIELD_FORWARD := 0.10        # l'écu est décalé devant l'avant-bras (m)
const SHIELD_SIDE := 0.08           # et vers l'extérieur (m)
# --- Caméra en visée : du côté de l'arme, pour voir l'arme et le réticule alignés ---
const AIM_CAMERA_SIDE_BOW := 0.30     # arc : par-dessus l'épaule DROITE comme l'arbalète (standard des RPG à la 3e personne) ; négatif = gauche
const AIM_CAMERA_SIDE_XBOW := 0.30    # arbalète : par-dessus l'épaule droite (m)
# --- Parade sans écu : le bras libre reste bas devant le ventre (sinon l'animation lève le bras comme pour tenir un écu) ---
const FREE_GUARD_HAND := Vector3(-0.22, 1.02, -0.30)
const AIM_CAMERA_RAISE := 0.0        # en visée à l'arc / arbalète la caméra monte un peu : on voit le dessus de l'arme et les mains (m)

# === Animations plus naturelles (étape 6) ===
# Toutes ces options sont indépendantes ; les passer à false redonne le comportement d'avant.
const ANIM_STRIDE_MATCH := true       # cadence de marche/course calée sur la vitesse réelle (les pieds ne glissent plus)
const ANIM_STRIDE_MAX := 2.8          # accélération maximale de l'animation de marche (x)
const ANIM_LOCO_SMOOTH := 14.0        # douceur des départs, arrêts et demi-tours (plus haut = plus réactif)
const ANIM_WEIGHT_AFFECTS_SPEED := true   # le poids porté ralentit un peu la cadence des animations (pas le déplacement)
const ANIM_WEIGHT_EFFECT := 0.25      # ralentissement maximal à pleine charge (0,25 = -25 %)
const ATTACK_LUNGE := 0.30            # petit pas en avant visuel pendant une attaque (m) ; ne change PAS la portée du coup
const FOOT_IK_ENABLED := true         # pieds posés sur le terrain (pente, rampe)
const FOOT_IK_MAX_OFFSET := 0.35      # correction maximale de hauteur d'un pied (m)
const LOOK_AT_ENABLED := true         # la tête (et un peu le buste) suivent l'adversaire ou le point visé
const LOOK_RANGE := 14.0              # distance maximale à laquelle on regarde l'adversaire (m)
const LOOK_HEAD_INFLUENCE := 0.9
const LOOK_SPINE_INFLUENCE := 0.3
const KNOCKBACK_SPEED := 3.2          # recul de départ quand on est touché (m/s), selon la force et le type du coup
const KNOCKBACK_DECAY := 14.0         # décélération du recul (m/s²)
const KNOCKBACK_BIG_HIT := 26.0       # à partir de ces dégâts on joue la grande réaction (« ventre »)
const RAGDOLL_ON_DEATH := true        # mort en ragdoll (false = animation de mort)
const RAGDOLL_PUSH := 3.0             # vitesse donnée au corps par le coup fatal (m/s)
