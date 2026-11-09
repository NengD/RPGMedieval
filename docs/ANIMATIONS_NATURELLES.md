# Animations plus naturelles (étape 6)

Aucune de ces couches ne modifie la préparation, le coup ou la récupération : l'animation s'adapte au `Combatant`, jamais l'inverse.
Chaque option se coupe dans `game_config.gd` (section « Animations plus naturelles »).

| Fonction | Comment | Réglages |
|---|---|---|
| **Pieds qui ne glissent plus** | Le bake (`tools/bake_animations.gd`) mesure la vitesse d'origine de chaque clip (`root_speed`). La cadence = vitesse réelle / vitesse du clip (`HeroModel.stride_scale`). Les points de marche et de course des espaces de mélange sont placés à la vraie vitesse des clips. | `ANIM_STRIDE_MATCH`, `ANIM_STRIDE_MAX` |
| **Départs, arrêts, demi-tours plus doux** | La position dans les espaces de mélange est lissée (constante de temps ≈ 70 ms) : on passe par le repos au lieu de basculer. | `ANIM_LOCO_SMOOTH` |
| **Pieds sur le terrain** | `FootIK` : une chaîne `TwoBoneIK3D` par jambe, cible = hauteur du sol sous le pied (lancer de rayon). Pied posé = suit le terrain, pied en l'air = presque pas. Le bassin descend avec le pied le plus bas. Sol plat : aucun changement. | `FOOT_IK_ENABLED`, `FOOT_IK_MAX_OFFSET` |
| **Tête et buste vers la cible** | Deux `LookAtModifier3D` (tête, haut du dos). Cible = adversaire le plus proche devant (< 14 m), sinon le point visé à l'arc / arbalète. | `LOOK_AT_ENABLED`, `LOOK_RANGE`, `LOOK_*_INFLUENCE` |
| **Coups reçus selon la direction** | Gauche / droite / face léger / face fort (« ventre ») / tir à la tête : 5 clips choisis d'après la position de l'agresseur (`HeroModel._pick_hit_anim`). | `KNOCKBACK_BIG_HIT` |
| **Recul physique** | `Combatant.knockback` : vitesse selon les dégâts, le type (contondant ×1,5, perforant ×0,7) et le poids porté (plates : jusqu'à −40 %). Appliqué par `move_and_collide`, sans toucher à la vitesse voulue. | `KNOCKBACK_SPEED`, `KNOCKBACK_DECAY` |
| **Petit pas en avant en attaquant** | Décalage VISUEL du modèle (le corps réel et la portée du coup ne bougent pas). | `ATTACK_LUNGE` (0 = désactivé) |
| **Poids → cadence** | Plus on porte, plus la cadence des animations de marche baisse (le déplacement ne change pas). | `ANIM_WEIGHT_AFFECTS_SPEED`, `ANIM_WEIGHT_EFFECT` |
| **Mort en ragdoll** | `Ragdoll` : un `PhysicalBoneSimulator3D` (16 capsules, collisions avec le monde seulement). Armures et armes suivent : ce sont des maillages skinnés / `BoneAttachment3D` sur le même squelette. | `RAGDOLL_ON_DEATH`, `RAGDOLL_PUSH` |
| **Main gauche** | Arc, arbalète, écu en parade, et maintenant **armes à deux mains** (lance, épée à deux mains : la main gauche suit le repère `Grip_L` du modèle). | — |

## Vérifier
- `tests/rpg_tests.gd`, section « Animations plus naturelles » (cadence, direction des coups, recul, pas en avant, regard, deux mains, ragdoll).
- Captures : `godot --path . --resolution 960x540 --position 6000,3000 -s tests/polish_look.gd` (images `user://polish_*.png`).
- Les os animés par IK ne se lisent pas en mode sans fenêtre : les tests vérifient les valeurs et les cibles ; le rendu se juge sur captures ou en jeu.

## Limites connues
- Les pieds sont posés en hauteur mais **pas inclinés** (la cheville ne suit pas la pente).
- Les réactions « de la gauche / de la droite » viennent du pack hache : elles sont plus ouvertes que les impacts de l'épée.
- Ragdoll : capsules simples, joints coniques sans limites fines ; le corps peut parfois se plier de façon peu naturelle. Réglable dans `scripts/character/ragdoll.gd`.
- Les cinq clips de réaction durent plus longtemps que l'étourdissement (0,35 s) : seul leur début est joué.
