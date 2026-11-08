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
const DIR_NAMES := ["haut", "droite", "estoc", "gauche"]   # "bas" = l'estoc (coup pointé droit devant)

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
const AIM_THRESHOLD := 70.0          # mouvement de souris (pixels) nécessaire pour changer de direction : plus haut = moins sensible
const AIM_DOMINANCE := 1.4           # l'axe dominant doit dépasser l'autre d'au moins ce facteur, sinon la direction ne change pas
const AIM_DECAY := 4.0               # oubli du mouvement de souris (plus haut = il faut bouger plus vite)
const STICK_AIM_GAIN := 700.0        # équivalent pixels/seconde du stick droit à fond

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
const DIFFICULTY_NAMES := ["Facile", "Normal", "Difficile"]
const DEFAULT_DIFFICULTY := 1
const ENEMY_AI_ENABLED_AT_START := true   # false = l'ennemi reste immobile et inoffensif au départ (touche F4 en jeu)
const AI_REACTION_TIME := [0.40, 0.28, 0.18]          # délai avant de réagir à ton coup (s) : plus c'est long, moins il pare
const AI_PARRY_CHANCE := [0.15, 0.30, 0.50]           # chance de tenter une parade
const AI_PERFECT_PARRY_CHANCE := [0.0, 0.04, 0.12]    # parmi les parades : tentative de parade parfaite
const AI_WRONG_SIDE_CHANCE := [0.50, 0.35, 0.20]      # chance de garder du mauvais côté
const AI_ATTACK_INTERVAL := [2.4, 1.6, 0.9]           # pause moyenne entre deux attaques (s)
const AI_SMART_CHANCE := [0.15, 0.45, 0.75]           # chance d'éviter la direction que tu gardes
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
const WEAPON_NAMES := ["Épée", "Arc", "Arbalète"]

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
const IK_UP_RAISED   := Vector3(0.20, 1.78, 0.05)    # coup d'en haut : main levée au-dessus de la tête (bras encore plié, pas tendu à fond)
const IK_UP_CONTACT  := Vector3(0.12, 1.00, -0.85)   # ... et abattue devant, à hauteur de poitrine
const IK_UP_FOLLOW   := Vector3(0.12, 0.80, -0.90)   # ... fin du geste
const IK_STAB_COCKED := Vector3(0.30, 1.25, 0.10)    # estoc : main ramenée en arrière
const IK_STAB_CONTACT:= Vector3(0.10, 1.32, -1.00)   # ... bras tendu droit devant
const IK_STAB_FOLLOW := Vector3(0.10, 1.32, -1.05)
const IK_POLE        := Vector3(0.90, 1.30, 0.60)    # direction du coude (vers l'extérieur et l'arrière)
const IK_RAISE_SHARE := 0.72                         # part de la préparation passée à lever / armer ; le reste = le geste rapide
# Direction de la lame (repère du personnage, -Z = devant) pendant ces deux attaques
const IK_BLADE_UP_RAISED  := Vector3(0.0, 1.0, 0.30)    # lame vers le haut, un peu en arrière
const IK_BLADE_UP_CONTACT := Vector3(0.0, -0.55, -1.0)  # lame abattue vers l'avant et le bas
const IK_BLADE_STAB       := Vector3(0.0, 0.05, -1.0)   # estoc : lame droit devant
const IK_REST_BLADE := Vector3(0.0, 0.8, -0.6)       # direction de la lame au repos (vers le haut et l'avant)
