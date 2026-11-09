# Architecture — du prototype de combat vers le futur RPG

> Document de l'**étape 1** (diagnostic + proposition). **Rien n'a été modifié dans le jeu.**
> Il attend ta validation avant l'étape 2. Les points à trancher sont listés en bas (§ 9).

---

## 1. Diagnostic : ce qui fait « faux », par impact

Captures de référence (générées par `tests/side_look.gd`, `parry_look.gd`, `aim_look.gd`, `bow_look.gd`, `xbow_look.gd`, dossier `user://`).

| # | Défaut | Où | Pourquoi ça se voit | Traité à l'étape |
|---|--------|----|---------------------|------------------|
| 1 | **Armes = boîtes colorées** (épée à 3 cubes, arc = 3 bâtons + 2 traits, flèche = fût + cube) | `hero_model._build_attachments/_build_bow_prop/_build_xbow_prop`, `weapon_visual.gd`, `ranged_visual.gd`, `arrow.gd` | L'objet le plus regardé du jeu est le moins réaliste ; l'arc n'a aucune courbure ni poignée | 3 |
| 2 | **Une seule tenue**, texture peinte unique (Paladin) ; l'ennemi = même modèle teinté en rouge | `hero_model.gd` (`tint`) | Impossible de lire « qui est armé de quoi » ; aucune différence mailles / plates / tissu | 4 |
| 3 | **Arène = damier gris + ciel procédural** | `arena.gd` (`_CHECKER_SHADER`, `ProceduralSkyMaterial`) | Aucune matière, aucune échelle, ombres dures, pas d'ambiance | 5 |
| 4 | **Pieds qui glissent**, pas d'IK de pied (rampe, sol), départs/arrêts/demi-tours abrupts | `hero_model.drive` (vitesse d'anim = `horizontal / 2`) | Le plus visible en marche/recul/pas chassés | 6 |
| 5 | **Main gauche non posée** sur l'arc / l'arbalète / l'épée à deux mains ; l'arme est calée sur une main ou sur la ligne main-main (`_place_props`) | `hero_model._place_props` | Bras qui « flottent » autour de l'arme ; l'arc est un bâton | 3 + 6 |
| 6 | **Réactions et mort génériques** : coup reçu = anim aléatoire (impact 1-3), pas de recul physique, mort = anim fixe | `hero_model._on_hit`, `_on_died` | Pas de rapport entre la force/direction du coup et la réaction | 6 |
| 7 | **Parade = une pose IK** + bras libre inerte ; garde sans bouclier | `IK_GUARD_*`, `hero_model._update_ik` | Lisible mais raide | 3 (bouclier) + 6 |
| 8 | **Tête et buste ne suivent pas la cible** | — | Le héros regarde « droit devant » même quand il vise | 6 |
| 9 | **Pas de sons, pas de hit-stop / secousse** | — | Les coups manquent de poids (hors périmètre ici, prévu « étape 6 » du plan d'origine) | plus tard |

**Dette technique qui bloquerait le RPG** (c'est le cœur de l'étape 2) :

- `Combatant` lit **34 constantes globales** de `game_config.gd` (`ATTACK_DAMAGE[dir]`, `STAMINA_MAX`, `PLAYER_MAX_HEALTH`…) : impossible d'avoir deux personnages ou deux armes différents.
- Les **dégâts sont un simple nombre** (aucun type, aucune armure).
- Les **textes français sont écrits en dur** (HUD, messages, `DIR_NAMES`, noms d'armes/difficultés : ~40 endroits).
- **Aucun identifiant** d'objet, **aucune sauvegarde**.
- `hero_model.gd` (≈ 660 lignes) mélange squelette, AnimationTree, IK, armes, arc/arbalète : à découper.
- `attack_dir` (0 haut, 1 droite, 2 estoc, 3 gauche) sert à la fois d'**index d'animation**, de **ligne de tableau de chiffres** et de **pose de garde** : à transformer en « coups du combo » décrits par les données d'arme.

---

## 2. Principes

1. **Données d'abord** : tout ce qui varie (arme, armure, matière, jeu d'animations, stats de base) est une `Resource` `.tres`. Ajouter un objet = ajouter un fichier, **sans toucher au code**.
2. **Valeurs par défaut = comportement actuel** : `game_config.gd` reste la source des valeurs par défaut ; `Stats`/`WeaponData` les reprennent. Un test « équivalence » vérifie que les chiffres du combat sont identiques à ceux d'aujourd'hui.
3. **Réalisme jamais au détriment de la lisibilité** : aucune durée de coup/parade n'est lue dans l'animation ; le `Combatant` reste le « chef d'orchestre » (les animations sont scrubbées sur lui, comme aujourd'hui).
4. **Squelette Mixamo conservé** : toutes les animations et `hero_library.res` restent valides.
5. **Tout est sauvegardable et traduisible** dès la conception.

---

## 3. Dossiers

```
assets/
  hero/            (existant) corps de base Mixamo
  anims/           (existant) FBX + hero_library.res
  weapons/         NOUVEAU  *.glb  (origine = prise en main, repères Grip_R / Grip_L / Tip)
  armor/           NOUVEAU  *.glb  (pièces souples skinnées / rigides)
  textures/        NOUVEAU  PBR Poly Haven 1k (arène, tissus, métaux)
data/                NOUVEAU  (les .tres : ce qu'on édite pour équilibrer / ajouter)
  weapons/arme.epee_longue.tres …
  armor/armure.cuirasse_plates.tres …
  materials/materiau.mailles.tres …        (coefficients de protection)
  outfits/tenue.chevalier_plates.tres …    (liste de pièces)
  categories/categorie.epee_une_main.tres  (jeu d'animations, enchaînement du combo)
locale/translations.csv   NOUVEAU  clés → fr | en
scripts/
  rpg/            NOUVEAU : stats, dégâts, registre, sauvegarde, équipement, données
  combat/         (déplacement futur de combatant.gd, enemy.gd…)
  character/      (découpage de hero_model.gd)
docs/             ARCHITECTURE.md, FONDATIONS_RPG.md, AJOUTER_UNE_ARME.md, AJOUTER_UNE_PIECE.md
```

Déplacer les scripts existants se fera **à la fin** (Godot gère les UID ; on évite de casser des chemins en pleine étape).

---

## 4. Étape 2 — Fondations RPG

### 4.1 Stats (`scripts/rpg/stats.gd`, nœud enfant du personnage)

```
Stats (Node)
  base: Dictionary            # attributs : force, endurance, agilité, vigueur  (valeurs entières, défaut = 10)
  modifiers: Array[StatModifier]
  signal changed(stat_id)
  get_value(stat_id) -> float # = (base + Σ plats) × (1 + Σ %)   [somme des % d'une même couche, pas de produit]
  add_modifier(m) / remove_modifier(m) / remove_by_source(source_id) / tick(delta)  # durée optionnelle
```

`StatModifier` (Resource légère) : `stat_id`, `flat`, `percent`, `source` (« equipement:armure.gambison », « effet:… », « blessure:… »), `duration` (−1 = permanent).

**Valeurs dérivées** (recalculées, jamais stockées comme vérité) : `vie_max`, `endurance_max`, `recuperation_endurance`, `vitesse_attaque` (multiplie `speed_scale`), `charge_portee`, `charge_max`.
Avec les attributs par défaut et sans modificateur, **chaque dérivée = la constante actuelle** (`PLAYER_MAX_HEALTH`, `STAMINA_MAX`, `STAMINA_REGEN`, vitesse = 1,0) → combat identique. Les attributs agissent ensuite par écart à 10 (ex. vie_max = 100 × (1 + 0,03 × (vigueur − 10))) : formules dans `data/stats_formulas.tres`, faciles à équilibrer.

`Combatant` reçoit `stats: Stats` et lit `stats.get_derived(&"vie_max")` etc. à la place des constantes. Les constantes de `game_config.gd` deviennent les **valeurs de repli** des données.

### 4.2 Types de dégâts

- `enum DamageType { TRANCHANT, CONTONDANT, PERFORANT }`.
- `DamagePacket` (RefCounted) : `amount_by_type: Dictionary` (permet un mélange, ex. masse à pointes 70 % contondant / 30 % perforant), `attacker`, `source_id` (arme), `is_projectile`, `is_headshot`.
- `Combatant.receive_hit(attacker, dir, damage)` devient `receive_hit(attacker, dir, packet)` ; l'ancien appel avec un `float` reste accepté (emballé en `TRANCHANT` pur sans armure → mêmes chiffres).
- **Protection** : chaque `ArmorData` a `protection: {tranchant, contondant, perforant}` (0–1 = part absorbée). Les pièces de la même zone se combinent par **couches** (on prend la meilleure par type + 25 % du reste, cf. § 6) ; la zone touchée dépend de la hauteur/direction du coup (coup d'estoc → torse, tir à la tête → tête).
- **Matières** (`MaterialData`, coefficients dans `.tres`) — valeurs de départ réalistes :

| Matière | Tranchant | Contondant | Perforant | Remarque |
|---|---|---|---|---|
| tissu | 0,10 | 0,05 | 0,05 | |
| cuir | 0,30 | 0,15 | 0,20 | |
| gambison | 0,40 | 0,35 | 0,25 | bon contre le contondant |
| mailles | 0,65 | 0,15 | 0,25 | arrêtent le tranchant, pas la pointe ni l'impact |
| plaques | 0,80 | 0,45 | 0,70 | transmettent une partie du contondant |

  L'endurance consommée en parant et les dégâts de garde brisée restent calculés comme aujourd'hui (le type de dégâts n'agit que sur ce qui **passe**).
- **Chiffres flottants** : couleur par type (tranchant blanc-rouge, contondant orange, perforant jaune) + petit pictogramme (texte `†` `●` `▲`) ; `FloatingText` reçoit un `damage_type`.

### 4.3 Identifiants et registre

- **ID de type** : `StringName` stable et lisible, préfixe de catégorie : `arme.epee_longue`, `armure.haubert_mailles`, `materiau.mailles`, `tenue.chevalier_plates`. Champ `id` de chaque Resource ; **jamais renommé** une fois publié (le nom affiché passe par la traduction).
- **ID d'instance** : `String` unique et stable `"<type>#<n>"` généré par le registre (compteur sauvegardé), pour chaque personnage / objet posé (`hero#1`, `ennemi#1`, `arme.epee_longue#7`).
- **Registre** (autoload `Registry`) : au démarrage scanne `data/**/*.tres`, refuse les **doublons** d'ID (test), expose `Registry.get_data(id)`, `Registry.create_instance(id)`, `Registry.find_instance(instance_id)`.

### 4.4 Sauvegarde (autoload `SaveService`)

- Interface **par convention** (pas de classe abstraite lourde) : tout nœud dans le groupe `saveable` expose `save_id() -> String`, `capture_state() -> Dictionary` (données pures : ids, nombres, tableaux — jamais de nœuds), `restore_state(d: Dictionary)`.
- Sauvegardent : `Stats` (base + modificateurs + durées), `EquipmentComponent` (id des objets équipés + variante de couleur), `Combatant` (vie, endurance, épuisement), position/orientation, état du registre (compteur d'instances).
- **Fichier** : `user://saves/slot_0.json` (+ `autosave.json`), JSON lisible : `{ "version": N, "date": …, "objets": { "<instance_id>": {…} } }`. Entiers convertis explicitement (`int()`), ID en chaînes.
- **Écriture atomique** : écriture dans `.tmp`, fermeture, ancien fichier renommé en `.bak`, renommage `.tmp → .json` ; chargement : essai du `.json` puis du `.bak`.
- **Versions** : `SAVE_VERSION` courant, table `MIGRATIONS[v] → fonction(dict) → dict` appliquée en chaîne ; un fichier plus récent que le jeu est refusé avec un message clair. Test : une sauvegarde « v1 » écrite à la main se recharge après migration.
- **F5** = sauvegarde rapide, **F9** = chargement rapide (affichés dans l'aide). Attention : F5 est aussi « lancer le jeu » dans l'éditeur — en jeu fenêtré c'est sans conflit, mais à confirmer (§ 9).

### 4.5 Traduction

- `locale/translations.csv` (colonnes `keys,fr,en`), importé par Godot en `.translation`, déclaré dans les paramètres du projet ; locale par défaut `fr`, colonne `en` vide pour vérifier le repli.
- **Convention de clés** : `HUD_STATE_IDLE`, `MSG_PARRY_PERFECT`, `ARME_EPEE_LONGUE`, `STAT_FORCE`… Les noms des données (`display_name`) sont des **clés**, jamais du texte.
- Tous les `Label.text`, messages, `DIR_NAMES`, `DIFFICULTY_NAMES`, `WEAPON_NAMES`, `_STATE_NAMES` passent par `tr()` (texte avec paramètres : `tr("MSG_DAMAGE") % valeur`).
- **Test** : (a) toute clé utilisée existe dans le CSV avec une valeur `fr` non vide ; (b) analyse statique : aucun littéral contenant un caractère accentué ou un mot français courant dans un `.text =`/`show_message(`.

### 4.6 Tests de l'étape 2 (en plus des existants, qui ne sont pas modifiés)

équivalence des chiffres (même séquence de coups → mêmes vie/endurance qu'aujourd'hui), modificateurs plats/%/durée/retrait par source, matrice type de dégâts × matière, unicité des identifiants + registre, aller-retour de sauvegarde, migration depuis une ancienne version, sauvegarde corrompue → retour au `.bak`, traduction.

---

## 5. Étape 3 — Armes extensibles

### 5.1 Données

```
WeaponData (Resource)
  id, display_name (clé), category (-> WeaponCategory)
  model: PackedScene (.glb)  — origine = prise main droite ; marqueurs Grip_L (2e main), Tip, Guard
  hands: 1 | 2 ; offhand_allowed: bool
  length, reach_bonus, weight
  damage: Dictionary (type → valeur)      # remplace ATTACK_DAMAGE[]
  combo: Array[AttackStep]                # remplace ATTACK_WINDUP/STRIKE/RECOVERY/STAMINA/REACH/ARC par coup
  stamina_cost_factor, stat_requirements, stat_bonuses : Array[StatModifier]
  sounds: Dictionary (vide pour l'instant)

AttackStep (Resource)   # un « coup du combo »
  animation: StringName (ex. &"attack_right"), windup, strike, recovery, stamina, damage_mult, reach, arc_deg, damage_type_mix

WeaponCategory (Resource)  # jeu d'animations partagé
  id, anim_set: { idle, walk_*, run_*, guard, hit_*, … }, guard_kind, uses_shield_slot, ranged: bool
```

Le combo actuel (droite, gauche, haut, estoc) devient le `combo` de l'**épée longue** : mêmes durées/dégâts/endurance qu'aujourd'hui (test d'équivalence). `attack_dir` reste utilisé en interne comme **index d'animation** le temps de la transition, puis est remplacé par `AttackStep`.

### 5.2 Exécution

- `WeaponController` (remplace `WeaponVisual` + `RangedVisual` + accessoires de `HeroModel`) : instancie le `.glb`, l'accroche à la main (BoneAttachment3D, ou nœud `top_level` placé par `_place_props` pour arc/arbalète/deux mains), gère le **marqueur `Grip_L`** pour poser la main gauche par IK, la corde de l'arc (os ou lignes), la flèche encochée.
- **1re personne** : même `.glb` sur un pivot de caméra, poses issues des `AttackStep` (comme `weapon_visual.gd` aujourd'hui) ; on masque tout ce qui traverserait le corps via la distance de plan proche + échelle de l'arme.
- Projectiles : `ArrowData` (flèche, carreau) = petit `WeaponData`-like avec `.glb` et type de dégâts perforant.
- **Catégories prévues** : épée une main, hache, masse, lance, deux mains, bouclier (main gauche, parade), arc, arbalète. Celles sans animations Mixamo (bouclier, lance, deux mains, masse) réutilisent provisoirement le jeu de l'épée, et je fournirai la **liste exacte des packs Mixamo** à télécharger avec les réglages du guide.

### 5.3 Modèles Blender (lot 1 : 11 objets)

Épée longue, épée courte, hache de guerre, masse d'armes, lance, épée à deux mains, écu, arc long, arbalète, flèche, carreau. < 2 000 faces chacun, un matériau PBR (Poly Haven 1k) ou matériaux unis métal/bois/cuir, export `.glb` avec origine = poignée.

---

## 6. Étape 4 — Personnage modulaire et équipement

### 6.1 Principe

Un seul `Skeleton3D` Mixamo (celui de `hero.fbx`). Chaque pièce d'équipement est **soit** :

- **souple** : `MeshInstance3D` **skinné sur ce squelette** (propriété `skeleton` pointant vers le `Skeleton3D` du héros ; les poids sont transférés du corps de base dans Blender) ;
- **rigide** : mesh enfant d'un `BoneAttachment3D` (plaques, heaume, gantelets).

La cape et les pans de tissu sont des meshes souples avec chaînes d'os supplémentaires pilotées par `SpringBoneSimulator3D`.

### 6.2 Emplacements et couches

Emplacements : tête, cou, torse, épaules, bras, mains, taille, jambes, pieds, cape.
Couches par emplacement : `0 vêtement → 1 gambison → 2 mailles → 3 plaques → 4 surcot/tabard`.
Règle : **un objet par (emplacement, couche)** ; la pièce de couche supérieure peut déclarer `hides_below` (ex. plaques cachent les mailles aux endroits couverts) et `hidden_body_regions`.

### 6.3 Corps de base et parties cachées

Le corps de base est **découpé dans Blender en régions** (tête, torse, bras, mains, hanches, jambes, pieds) gardant les mêmes poids. Cacher une région = cacher ce mesh (aucun shader, aucun coût). Les pièces `ArmorData.hidden_body_regions` indiquent lesquelles masquer.

### 6.4 Données et composant

```
ArmorData (Resource)  id, display_name(clé), slot, layer, material (-> MaterialData), model, rigid: bool, bone (si rigide)
                      protection: {tranchant, contondant, perforant}   # défaut = coefficients de la matière × couverture
                      weight, stat_modifiers: Array[StatModifier], hidden_body_regions, color_variants: Array[Color]

OutfitData (Resource) id, pieces: Array[id]       # tenue complète (3 tenues de départ)

EquipmentComponent (Node, enfant du personnage ; commun héros / ennemi / mannequin)
  equip(id) / unequip(slot, layer) / equip_outfit(id)
  -> met à jour Stats (modificateurs « source = equipement:<id> »), la protection par zone, le poids porté,
     l'affichage (instancie/retire les meshes, masque les régions), émet changed
  capture_state() / restore_state()  (sauvegarde : ids + variantes)
```

### 6.5 Corps de base à choisir (action de ta part)

Le `hero.fbx` actuel (Paladin) est **un chevalier déjà en armure** (armure peinte dans la texture) : il ne peut pas servir de « corps nu + pièces ». Il faut un personnage Mixamo **en vêtements simples, proportions naturelles** (le squelette `mixamorig` est le même pour tous, donc **toutes les animations restent valides**). Je te guiderai sur Mixamo pour en choisir un (je te donnerai la marche exacte et les réglages) ; en attendant, le Paladin reste en place.

### 6.6 Trois tenues de départ

Chevalier en plates (héros), homme d'armes en mailles et gambison (ennemi), archer léger cuir et tissu. L'ennemi n'est donc plus un « héros teinté ».

### 6.7 Contrôle de non-traversée

Test visuel automatisé (captures face/profil/dos dans marche, course, attaques, parade, esquive, coups reçus, mort) + test géométrique : à chaque pose, distance entre sommets des pièces et surface du corps ≥ seuil (ou ratio de pénétration), pour repérer les pièces qui se traversent.

---

## 7. Étapes 5 et 6 (aperçu — détaillées après validation des étapes 2-4)

**Étape 5 — Matériaux, arène, lumière** : matériaux PBR Poly Haven (terre battue/pavés, pierre), accessoires Blender (caisses, tonneaux, râtelier, poteaux), mêmes collisions/piliers ; ciel HDRI, SSAO, brouillard léger, tonemapping filmique ; réglage Bas/Moyen/Élevé (`QualitySettings` dans les données) et mesure de fluidité avec 4-6 personnages équipés.

**Étape 6 — Animations plus naturelles** : vitesse d'animation = vitesse réelle (stride matching), IK de pieds (`SkeletonIK`/`TwoBoneIK3D` + lancers de rayon), transitions de départ/arrêt/demi-tour, `LookAtModifier3D` pour tête/buste, réactions selon direction/force (clips « react large from left/right/gut »), recul physique léger, pas en avant pendant les attaques (réglable, la portée du coup ne change pas), poids d'arme/armure → vitesse d'animation (désactivable), mort en ragdoll (`PhysicalBoneSimulator3D`, équipement suivant le corps), main gauche par IK sur arc/arbalète/deux mains/bouclier.
Règle : aucune de ces couches ne modifie `windup/strike/recovery` ; l'animation s'adapte au `Combatant`, jamais l'inverse.

---

## 8. Risques et choix honnêtes

- **Qualité de la modélisation** : je modélise par script Python dans Blender (formes + biseaux + subdivision + matériaux PBR). On obtient un low-poly propre et cohérent, pas de la sculpture haute qualité ; je te montrerai des aperçus de chaque pièce avant de l'intégrer. Pour une pièce délicate (heaume, haubert) je pourrai aussi proposer la génération 3D du MCP Blender (peut consommer un crédit : je demanderai avant).
- **Transfert de poids** : réaliste pour les vêtements/plaques proches du corps ; les mailles et tabards (larges) demandent un nettoyage manuel des poids — je le fais par script et je vérifie en pose.
- **Charge de travail** : 4 étapes denses. Je m'arrête à la fin de chacune pour ton avis.
- **Travail en arrière-plan** : Godot en `--headless` ; captures dans une fenêtre placée hors écran, sans capturer souris/clavier/manette (comme `tests/real_input_attacks.gd`) ; Blender uniquement dans une **nouvelle scène**, sans toucher à tes `.blend` ouverts.
- **Non-régression** : les tests existants (`run_tests.gd`, `combat_tests.gd`) ne sont **pas modifiés** ; si une nouvelle donnée les casse, c'est la donnée qui est corrigée.

---

## 9. Points à valider avant l'étape 2

1. **Ordre/découpage** proposé (stats → dégâts/armures → IDs/registre → sauvegarde → traduction) : OK ?
2. **Sauvegarde rapide F5 / F9** : F5 est aussi « lancer » dans l'éditeur Godot, ce qui est sans conflit en jeu ; sinon je prends une autre touche. OK ?
3. **Valeurs de départ des protections** (tableau § 4.2) : OK comme base d'équilibrage ?
4. **Corps de base** (§ 6.5) : on choisit ensemble un personnage Mixamo en vêtements simples à l'étape 4 (je te guiderai) ?
5. **Modélisation** : OK pour du low-poly par script avec aperçus à valider, et pour que je te demande avant tout crédit de génération 3D ?
