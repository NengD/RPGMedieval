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


## Attaques propres (à télécharger en plus du pack)
Le « Pro Sword and Shield Pack » contient surtout des attaques acrobatiques (sauts, fentes accroupies). Pour de vraies attaques
dans les 4 directions, télécharge ces animations Mixamo seules (Without Skin / No Character, **In Place** coché) :

| Rôle | Mot à chercher | Remarque |
|---|---|---|
| Attaque haut (coup d'en haut) | `standing melee attack downward` | |
| Attaque droite | `standing melee attack horizontal` | |
| Attaque gauche | la même, avec **Mirror** coché | ajoute `_mirror` au nom du fichier |
| Estoc (pointe en avant) | `stab` ou `thrust` ou `lunge` | prends celle qui pousse l'épée droit devant |

> Mise à jour : le « Pro Melee Axe Pack » (No Character) a été téléchargé et fournit finalement les attaques propres
> (fichiers `assets/anims/axe_*.fbx`). Les 4 téléchargements ci-dessus ne sont plus nécessaires.


## Lot 3 — armes (étape 3 du chantier réalisme + RPG)

Toutes les catégories d'armes jouent pour l'instant les animations de l'épée. Pour qu'elles aient les leurs, voici ce qu'il faut chercher
dans Mixamo. **Je n'ai pas pu confirmer les noms exacts des packs** (ma recherche web n'a renvoyé que des packs payants d'autres boutiques) :
cherche donc par **nom d'animation** dans la barre de recherche et dis-moi ce qui existe.

Réglages de téléchargement, toujours les mêmes : Format `FBX Binary (.fbx)` · 30 fps · **Skin = Without Skin** (« No Character » si c'est un pack) ·
Keyframe Reduction `none` · **In Place** coché pour les déplacements et les attaques. Fichiers dans `assets/anims/`, sans les renommer.

| Catégorie | Déjà couvert ? | À chercher dans Mixamo |
|---|---|---|
| Épée une main | oui (Pro Sword and Shield Pack) | — |
| Bouclier (parade) | en partie : le Pro Sword and Shield Pack contient `shield block` / `sword and shield block` (non encore branchées) | rien à télécharger |
| Hache | oui (Pro Melee Axe Pack) | — |
| Masse | utilise les attaques de la hache (même geste) | rien à télécharger |
| Arc | oui (Pro Longbow Pack) | — |
| Arbalète | oui (Pro Rifle Pack) | `rifle firing`, `rifle reload` si tu veux un geste de tir / rechargement |
| Épée à deux mains | non | `great sword idle`, `great sword walk`, `great sword run`, `great sword slash`, `great sword block`, `great sword impact` (ou `two handed sword …`) |
| Lance | non | `spear idle`, `spear walk`, `spear run`, `spear stab`, `spear attack`, `spear block` (ou « pike ») |

Dès que tu as téléchargé un lot, dis-moi lequel : j'ajoute ses clips à `tools/bake_animations.gd` (en m'appuyant sur `WeaponCategory.anim_set`) et je les branche.


## Corps de base (étape 4)

Le personnage de base est le **Mannequin** (Characters → Mannequin → Download → FBX Binary, T-pose). Les os s'appellent `mixamorig1_*`
dans ce fichier : `tools/make_base_rig.gd` les renomme en `mixamorig_*` pour que `hero_library.res` fonctionne sans changement.
Le FBX (35 Mo avec ses textures 4K) est rangé hors du projet. Pour changer de corps de base : télécharger un autre personnage Mixamo
(squelette identique), refaire `make_base_rig.gd`, puis `tools/blender/make_armor.py` (les pièces sont recalculées à sa taille).
