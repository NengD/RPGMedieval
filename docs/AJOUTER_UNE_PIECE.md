# Ajouter une pièce d'armure ou d'habit

Le personnage est **modulaire** : un corps de base unique (le Mannequin Mixamo) + des pièces qui s'enfilent dessus.
Tous les personnages (héros, ennemi, futurs PNJ) partagent le même squelette, donc **toutes les animations** existantes
fonctionnent sur toutes les tenues.

## Comment ça marche

- `assets/base/base_rig.tscn` : le squelette (65 os `mixamorig_*`), sans maillage. Fabriqué par `tools/make_base_rig.gd`
  à partir du téléchargement Mixamo (le FBX source est rangé hors du projet, dans `E:\_jeu perso\sources_mixamo\`).
- `assets/base/body.glb` : le corps nu découpé en **9 régions** (`corps_head`, `corps_torso`, `corps_hips`, `corps_upper_arm`,
  `corps_forearm`, `corps_hand`, `corps_thigh`, `corps_shin`, `corps_foot`).
- `assets/armor/*.glb` : une pièce par fichier. Seuls les **maillages** servent : `scripts/character/rig_mesh.gd` les rattache
  au squelette du jeu **par nom d'os** (le squelette du .glb est ignoré, ce qui garde les animations valides).
- `data/armor/*.tres` (`ArmorData`) et `data/outfits/*.tres` (`OutfitData`) décrivent les pièces et les tenues.
- `EquipmentComponent` (commun au héros, à l'ennemi, au mannequin) équipe / retire, applique protection, poids et modificateurs,
  et signale `changed` ; `HeroModel.apply_armor()` met l'affichage à jour et **cache les régions du corps recouvertes**.

## Fabriquer une pièce dans Blender

`tools/blender/make_armor.py` crée toutes les pièces du lot 1 en ligne de commande (scène vierge, ne touche pas à tes `.blend`) :

```
blender -b --factory-startup -P tools/blender/make_armor.py -- <corps.fbx> <assets/base> <assets/armor>
```

Chaque pièce est une **coque du corps** (mêmes sommets, mêmes poids de peau) décalée le long des normales : elle épouse le corps
et suit le squelette sans réglage. Pour une nouvelle pièce, ajoute un appel `piece(...)` dans `build_pieces()` :

```python
piece("armure.cotte_cuir", lambda f: R(f) in ("torso", "upper_arm"), 0.015, MATS["cuir"](),
      weights=None)                       # poids naturels = pièce souple
piece("armure.plastron", lambda f: R(f) == "torso", 0.036, MATS["acier"](),
      weights=("limit", ["Spine", "Spine1", "Spine2"]))   # poids limités = pièce rigide
```

- `R(f)` donne la région d'une face ; `Z(f)` sa hauteur (m) ; filtre = quelles faces du corps la pièce couvre.
- Décalage (m) : vêtement 0,006 · gambison 0,02 · mailles 0,03 · plaques 0,035-0,045 · surcot 0,07 (le surcot passe **au-dessus** des plaques).
  Une couche plus haute doit avoir un décalage plus grand, sinon les couches se traversent.
- Poids : `None` = naturels (souple, suit la déformation) ; `("rigid", "Spine2")` = un seul os ; `("limit", [...])` = quelques os (`{S}` = côté Left/Right).
- Matériaux « teinte_* » : la couleur peut être changée en jeu (variantes). Les autres gardent leur couleur.
- Casques et objets qui ne sont pas des coques : voir `helmet()` (maillage libre, poids 100 % sur l'os `Head`).

Pièces qui ne suivent pas le corps (cape, pans de tissu) : prévues avec `SpringBoneSimulator3D` à l'étape 6 (voir « Limites »).

## Les données (`data/armor/<id>.tres`)

Le plus simple : ajouter une ligne dans `tools/make_data.gd` (`_armor_table()`), puis `godot --headless --path . -s tools/make_data.gd`
(⚠ régénère aussi les autres `.tres`) — ou copier un `.tres` existant et le modifier dans l'éditeur Godot.

| Champ | Rôle |
|---|---|
| `id` | `armure.nom` — stable, **ne jamais le renommer** (sauvegardes) |
| `display_name` | clé de traduction (ligne à ajouter dans `locale/translations.csv`) |
| `slot` | tête, cou, torse, épaules, bras, mains, taille, jambes, pieds, cape |
| `layer` | couche : vêtement → gambison → mailles → plaques → surcot. Un seul objet par (emplacement, couche) |
| `material` | `data/materials/*.tres` : tissu, cuir, gambison, mailles, plaques → protection par type de dégâts |
| `coverage` | part de protection de la matière (0-1) |
| `weight` | kg (compte dans la charge portée) |
| `stat_modifiers` | bonus / malus de stats tant que la pièce est portée |
| `hidden_body_regions` | régions du corps à cacher dessous (`torso`, `hand`…) |
| `model` | le `.glb` |
| `color_variants` | couleurs du tissu (matériaux `teinte_*`) |

Une **tenue** (`OutfitData`) liste des identifiants de pièces et la variante de couleur de chacune.

## Vérifier

```
godot --headless --path . --fixed-fps 120 -s tests/rpg_tests.gd          # section « Personnage modulaire »
godot --path . --resolution 700x900 --position 6000,3000 -s tests/armor_look.gd -- armure.chemise,armure.gambison guard:0.5,run_f:0.2
godot --path . --resolution 960x540 --position 6000,3000 -s tests/outfit_look.gd    # les trois tenues dans l'arène
```

Le test contrôle : os présents dans le squelette, moins de 12 000 triangles, pièces qui ne traversent pas la peau en pose de repos,
protection (plates > mailles > cuir), régions cachées, poids, affichage, variantes de couleur.

## Dans le jeu

**K** : tenue suivante (aucune → chevalier en plates → homme d'armes → archer léger) · **L** : couleur du tabard ·
**G** : arme · **H** : écu. La ligne « Protection … Poids … Vitesse d'attaque » du HUD donne l'effet de la tenue.

## Limites connues (lot 1)

- Les pièces sont des coques lisses à bas nombre de polygones : le rendu est propre mais sobre (pas de rivets, de plis ni d'orfèvrerie).
  Pas de texture image (Poly Haven n'était pas disponible) : couleurs, métal et rugosité seulement.
- Les plaques « rigides » gardent les poids de plusieurs os : elles suivent le corps sans se détacher, mais peuvent se déformer un peu aux articulations.
- Cape et pans de tissu animés : pas encore faits.
- Les bords des coques laissent parfois un petit anneau de peau visible (poignets, cou).
