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
const DIR_NAMES := ["haut", "droite", "bas", "gauche"]

# Une attaque = préparation (on peut feinter) -> coup (touche) -> récupération.
const ATTACK_WINDUP   := [0.50, 0.34, 0.42, 0.34]   # préparation (s)
const ATTACK_STRIKE   := [0.14, 0.12, 0.14, 0.12]   # durée où le coup peut toucher (s)
const ATTACK_RECOVERY := [0.45, 0.35, 0.40, 0.35]   # récupération (s)
const ATTACK_DAMAGE   := [28.0, 20.0, 22.0, 20.0]   # dégâts
const ATTACK_STAMINA  := [22.0, 16.0, 18.0, 16.0]   # endurance consommée en lançant l'attaque
const ATTACK_BUFFER := 0.20          # un clic pendant la récupération est mémorisé (s)
const FEINT_RECOVERY := 0.18         # temps de récupération après une feinte
const FEINT_STAMINA := 6.0
const MELEE_RANGE := 2.3             # portée de l'épée (m, depuis le centre du corps)
const MELEE_ARC_DEG := 110.0         # largeur du cône de frappe
const AIM_ASSIST_RANGE := 4.0        # (3e personne) le héros se tourne vers un ennemi proche
const AIM_ASSIST_ANGLE_DEG := 40.0
const COMBAT_TURN_SPEED := 30.0      # vitesse à laquelle le corps se tourne vers la caméra en combat

# Choix de la direction à la souris / au stick droit
const AIM_THRESHOLD := 25.0          # mouvement (pixels) nécessaire pour changer de direction
const AIM_DECAY := 5.0               # oubli du mouvement de souris (plus haut = plus court)
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
