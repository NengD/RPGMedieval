# Guide Mixamo — animations du héros et de l'ennemi

Tout est gratuit (compte Adobe gratuit). Les fichiers vont dans le projet :

- `assets/hero/`   → le personnage (UN seul fichier)
- `assets/anims/`  → toutes les animations (sans personnage)

## Réglages de téléchargement
**Personnage** : Format `FBX Binary (.fbx)` · Pose `T-pose` (le fichier s'appelle comme le personnage).
**Chaque animation** : Format `FBX Binary (.fbx)` · Frames per second `30` · **Skin `Without Skin`** · Keyframe Reduction `none`.
Avant de télécharger une animation, coche **In Place** quand la case existe (marche, course, attaques, esquive…) pour que le personnage ne glisse pas.
Ne renomme rien, sauf les versions « Mirror » : ajoute `_mirror` à la fin du nom du fichier.

## Personnage (étape A)
Un seul : **Paladin J Nordstrom** (chevalier, sans accessoires) ou, à défaut, **Knight D Pelegrini**.
Le même modèle sert au héros et à l'ennemi (l'ennemi sera teinté en rouge sombre).

## Animations — Lot 1 : épée (le plus important)
Cherche ces mots dans la barre de recherche de Mixamo, choisis l'animation qui correspond, vérifie l'aperçu.

| Rôle dans le jeu | Mot à chercher | Remarque |
|---|---|---|
| Immobile | `sword and shield idle` | |
| Marche | `sword and shield walk` | In Place |
| Course | `sword and shield run` | In Place |
| Attaque haut (coup d'en haut) | `melee attack downward` ou `sword and shield slash` | In Place |
| Attaque droite | `melee attack horizontal` | In Place |
| Attaque gauche | la même que « droite », avec **Mirror** coché | fichier `…_mirror` |
| Estoc (coup pointé) | `stab` ou `thrust` ou `sword and shield attack` | In Place |
| Parade (garde) | `sword and shield block` | garde simple, maintenue |
| Parade côté opposé | la même avec **Mirror** | fichier `…_mirror` |
| Coup reçu | `sword and shield impact` ou `hit reaction` | |
| Mort | `sword and shield death` ou `dying` | |
| Pas de côté droite | `dodge right` ou `strafe right` | In Place |
| Pas de côté gauche | `dodge left` ou `strafe left` | In Place |
| Pas en arrière | `dodge backward` ou `walk backward` | In Place |
| Saut | `jump` | In Place |

## Animations — Lot 2 : arc et arbalète
| Rôle | Mot à chercher | Remarque |
|---|---|---|
| Arc : viser / bander | `draw arrow` ou `aim overdraw` | |
| Arc : tirer (relâcher) | `aim recoil` ou `shoot arrow` | |
| Arc : position de visée tenue | `bow aim` ou `standing aim` | |
| Arbalète : viser | `rifle aiming idle` | une arbalète se tient comme un fusil |
| Arbalète : tirer | `firing rifle` | |
| Arbalète : recharger | `reloading` | |

## Si un nom n'existe pas
Pas grave : prends l'animation la plus proche et dis-moi son nom exact. Je règle le reste dans le code
(durées, correspondance des animations, miroir si un côté manque).
