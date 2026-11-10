# Animations de combat : sources réelles (étape 9, partie B)

## Principe
Plutôt que d'inventer des poses, on part de vrais mouvements (capture / animation professionnelle), transférés sur NOTRE squelette Mixamo, puis retravaillés.
- **Sources** : Universal Animation Library 1 et 2 de Quaternius (CC0) ; la base de capture CMU (mocap.cs.cmu.edu) reste une piste si un geste manque.
- **Transfert** : `tools/retarget_ual.gd`. Pour chaque image (30/s) : rotation globale cible `Gt = (Gs · Rs⁻¹) · Rt` (pose source, repos source, repos cible), reconvertie en rotation locale ; déplacement des hanches mis à l'échelle (×1,09), x/z figés (« sur place »). Résultat : `assets/anims/ual_library.res`, animations nommées `ual_*`.
- **Aperçus** : `tests/anim_preview.gd` (images de face et de profil) → `tools/blender/frames_to_mp4.py` (vidéos MP4 par le montage de Blender) → `docs/anims/<nom>.mp4` et planches `<nom>.png`.

## Ce que les paquets apportent (par rapport à nos clips Mixamo)
| Besoin | Animation Quaternius | Remarque |
|---|---|---|
| Frappes d'épée | `ual_slash_a`, `ual_slash_b` (courtes, avec `_rec` de récupération), `ual_sword_attack`, `ual_combo` | vrais appuis et transfert de poids ; `ual_combo` contient des sauts et des coups de pied : à découper |
| Parade | `ual_sword_block` | garde à l'épée |
| Écu | `ual_shield_idle`, `ual_shield_bash`, `ual_shield_break` | garde et coup d'écu |
| Coups reçus | `ual_hit_chest`, `ual_hit_head`, `ual_hit_knockback` | réactions courtes (0,3 à 0,8 s), mieux adaptées à l'étourdissement que les nôtres |
| Mort | `ual_death` | |
| Déplacements | `ual_walk`, `ual_jog`, `ual_sprint`, `ual_roll`, `ual_sword_dash`, `ual_sword_idle` | |
| Manquent | masse, lance, deux mains, hache | à créer ou à retravailler (voir ci-dessous) |

## État
Les 21 animations transférées sont dans la bibliothèque `ual_library.res` mais **pas encore branchées dans le jeu** : elles attendent ta validation (vidéos dans `docs/anims/`).
Contrôles qualité (pieds plantés, centre de gravité, courbes lissées, mouvement secondaire) : pas encore faits.
