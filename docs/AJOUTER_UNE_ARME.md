# Ajouter une arme

Une arme = **un modèle 3D** (`.glb`) + **un fichier de données** (`.tres`). Aucun code à toucher.

## 1. Le modèle (`assets/weapons/<id>.glb`, ex. `arme_epee_longue.glb`)

Le lot 1 est fabriqué par `tools/blender/make_weapons.py` (Blender en ligne de commande, scène vierge, ne touche à aucun de tes `.blend`) :

```
blender -b --factory-startup -P tools/blender/make_weapons.py -- "E:/_jeu perso/rpgmedieval/assets/weapons" <dossier_aperçus>
```

Pour une nouvelle arme, ajoute une fonction `build_xxx(root)` dans ce script et une ligne dans `ITEMS`, ou modélise-la à ta façon, tant que tu respectes ces règles (repère Blender, Z vers le haut) :

| Règle | Détail |
|---|---|
| Origine | la prise de la **main principale** (main arrière pour une arme à deux mains) |
| Direction | l'arme pointe vers **+Z** (lame, fer de lance, tête de hache…) |
| Taille | mètres réels ; moins de **2 000 triangles** ; fichier < 1 Mo |
| Matériaux | PBR simples (couleur, métal, rugosité). Pas d'image obligatoire |
| Repères (objets vides) | `Grip_L` = où la main gauche se pose (deux mains, lance, bouclier) · `Tip` = pointe |
| Arc | branches le long de Z, côté archer = −Y ; `Nock_Top`, `Nock_Bottom`, `Arrow_Rest` |
| Arbalète | canon vers +Y ; `Grip_L`, `Bolt_Rest`, `Muzzle`, `Nock_Left`, `Nock_Right` |
| Munition | pointe à l'origine, hampe vers −Y ; repère `Nock` à la queue |

Export glTF : `export_yup=True` (Blender Z-haut → Godot Y-haut). Puis `godot --headless --path . --import`.

## 2. Les données (`data/weapons/<id>.tres`)

Le plus simple : ajouter une ligne dans `tools/make_data.gd` (tableau `melee`) puis lancer
`godot --headless --path . -s tools/make_data.gd` (⚠ régénère aussi les autres fichiers de données : ne le relance pas si tu as édité des `.tres` à la main — dans ce cas, copie un `.tres` existant et modifie-le dans l'éditeur Godot).

Champs de `WeaponData` :

| Champ | Rôle |
|---|---|
| `id` | identifiant stable `arme.nom` (**ne jamais le renommer**, les sauvegardes l'utilisent) |
| `display_name` | **clé de traduction** (ajoute la ligne dans `locale/translations.csv`) |
| `category` | `data/categories/*.tres` : épée une main, hache, masse, lance, deux mains, bouclier, arc, arbalète |
| `model` | le `.glb` |
| `hands` | 1 ou 2 (une arme à deux mains retire l'écu) |
| `weight` | kg (compté dans la charge portée) |
| `damage_mix` | répartition des dégâts, ex. `{TRANCHANT: 0.8, CONTONDANT: 0.2}` |
| `attacks` | 4 coups (`AttackStep`) : `windup` préparation, `strike` coup, `recovery` récupération, `stamina`, `damage`, `reach` portée en plus, `arc_deg` cône |
| `combo_order` | ordre des gestes quand on clique : 0 haut, 1 droite, 2 estoc, 3 gauche |
| `guard_cost_factor` | bouclier : 0,7 = parer coûte 30 % de moins |
| `stat_requirements` | ex. `{force: 11}` : chaque point manquant ralentit les attaques de 3 % |
| `stat_bonuses` | modificateurs de stats appliqués tant que l'arme est tenue |
| `ammo` | arc / arbalète : `data/ammo/*.tres` (flèche ou carreau) |

L'arme apparaît toute seule : le registre scanne `data/`, et la touche **G** parcourt toutes les armes de mêlée.

## 3. Vérifier

```
godot --headless --path . --fixed-fps 120 -s tests/rpg_tests.gd
godot --path . --resolution 960x540 --position 6000,3000 -s tests/weapons_look.gd   # captures dans user://arme_*.png
```

Le test vérifie : modèle qui se charge, moins de 2 000 triangles, repères présents, id unique, nom traduit, chiffres de combat lus dans les données.

## Ce qui n'est pas encore fait pour les armes (étape 6)

- La **main gauche n'est pas encore posée** sur le repère `Grip_L` (lance, deux mains, arc, arbalète) : elle suit l'animation de l'épée. C'est le travail d'IK de l'étape 6.
- Toutes les catégories jouent encore les animations de l'épée (voir `docs/GUIDE_MIXAMO.md`, section « Lot 3 »).
