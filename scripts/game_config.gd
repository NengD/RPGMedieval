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

# --- Héros : esquive / roulade ---
const DODGE_SPEED := 9.0             # vitesse de départ de la roulade
const DODGE_DURATION := 0.55
const DODGE_COOLDOWN := 0.25         # pause avant de pouvoir rouler à nouveau
const DODGE_IFRAME_START := 0.05     # début de l'invulnérabilité (s depuis le début)
const DODGE_IFRAME_END := 0.40       # fin de l'invulnérabilité

# --- Caméra ---
const MOUSE_SENSITIVITY := 0.0025    # radians par pixel de souris
const STICK_SENSITIVITY := 3.2       # radians par seconde, stick à fond
const INVERT_Y := false
const TPS_DISTANCE := 3.6            # distance caméra - héros (3e personne)
const TPS_SHOULDER := 0.45           # décalage d'épaule (3e personne)
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
