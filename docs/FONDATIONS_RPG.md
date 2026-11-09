# Fondations RPG (étape 2) — expliquées simplement

Tout le code est dans `scripts/rpg/`, les données dans `data/`, les textes dans `locale/translations.csv`.
**Règle respectée** : avec les valeurs par défaut, le combat donne exactement les mêmes chiffres qu'avant (vérifié par `tests/rpg_tests.gd`, section « Équivalence », et par les anciens tests, non modifiés).

## 1. Statistiques (`stats.gd`)

Chaque personnage (`Combatant`) a un `stats`.

- **4 attributs** : force, endurance, agilité, vigueur (10 = neutre).
- **Valeurs dérivées**, recalculées à chaque lecture (jamais stockées comme « vérité ») : vie max, endurance max, récupération d'endurance, vitesse d'attaque, charge max.
  Exemple : vigueur 20 → +30 % de vie. Les coefficients sont dans `data/stats_formulas.tres`.
- **Modificateurs** (`stat_modifier.gd`) : un bonus plat et/ou un pourcentage, avec une **source** (`equipement:armure.gambison`, `effet:potion`, `blessure:bras`) et une **durée** facultative.
  - Plats additionnés, pourcentages additionnés (deux +10 % donnent +20 %, pas +21 %).
  - Retirer une source retire tous ses modificateurs d'un coup : `stats.remove_by_source("effet:potion")`.
- Le `Combatant` lit ses valeurs ici. `game_config.gd` garde les valeurs **par défaut** (PLAYER_MAX_HEALTH, STAMINA_MAX…).

Ajouter un bonus : `combatant.stats.add_modifier(StatModifier.make(&"force", 3, 0, "effet:test"))`.

## 2. Types de dégâts et armures

- 3 types : **tranchant, contondant, perforant** (`damage_type.gd`). Une attaque est un `DamagePacket` (`damage_packet.gd`) : des dégâts répartis par type (ex. masse à pointes 70 % contondant / 30 % perforant). Un simple nombre reste accepté (tranchant pour un coup, perforant pour un tir).
- 5 **matières** (`data/materials/*.tres`) : tissu, cuir, gambison, mailles, plaques. Chacune absorbe une part de chaque type :

| Matière | Tranchant | Contondant | Perforant |
|---|---|---|---|
| tissu | 10 % | 5 % | 5 % |
| cuir | 30 % | 15 % | 20 % |
| gambison | 40 % | 35 % | 25 % |
| mailles | 65 % | 15 % | 25 % |
| plaques | 80 % | 45 % | 70 % |

- Une pièce d'armure (`ArmorData`) a un emplacement, une couche, une matière, un poids, des modificateurs de stats. Plusieurs pièces dans un même emplacement : la meilleure compte en entier, les autres pour 25 %. Chaque emplacement pèse selon la surface du corps qu'il représente (torse 30 %, jambes 22 %…, voir `EquipmentComponent.SLOT_SHARE`).
- L'armure ne réduit que ce qui **passe** : coût d'une parade et garde brisée se calculent comme avant.
- Les chiffres flottants prennent la couleur du type (tranchant jaune, contondant orange, perforant bleu clair).

## 3. Identifiants et registre (`registry.gd`)

- **Type d'objet** : identifiant stable et lisible « type.nom » (`materiau.mailles`, plus tard `arme.epee_longue`). Écrit dans le champ `id` de chaque fichier de données, **ne jamais le renommer** une fois utilisé (les sauvegardes le contiennent).
- **Instance** : « type#numéro » (`hero#1`, `ennemi#1`, `mannequin#1`), attribué au lancement (`Registry.new_instance_id`).
- `Registry.get_data(&"materiau.mailles")` retrouve n'importe quelle donnée ; `Registry.find_instance("hero#1")` n'importe quelle instance. Les données sont trouvées automatiquement : tout `.tres` dans `data/` qui a un `id` est enregistré ; un doublon est signalé et testé.

## 4. Sauvegarde (`save_service.gd`)

- **F5** : sauvegarde rapide, **F9** : chargement rapide (`user://saves/quick.json`, dossier `%APPDATA%\Godot\app_userdata\RPG Médiéval - Prototype de combat\saves\`).
- Format **JSON lisible** : `{ "version", "date", "registre", "objets": { "hero#1": {…} } }`.
- Sont sauvegardés : position et orientation, vie, endurance, épuisement, stats (attributs et modificateurs avec leur durée restante), équipement.
- **Écriture atomique** : écrite dans `.tmp`, ancien fichier gardé en `.bak`, puis renommage. Si le fichier principal est abîmé, la copie `.bak` est utilisée.
- **Versions** : chaque fichier porte son numéro. `SaveService.migrations[v]` transforme une version v en v+1 ; plusieurs migrations s'enchaînent. Un fichier plus récent que le jeu est refusé proprement.
- Rendre un élément sauvegardable : l'ajouter au groupe `saveable` et lui donner `save_id()`, `capture_state()`, `restore_state(d)` (données simples : nombres, textes, tableaux — jamais de nœuds).

## 5. Textes traduisibles (`locale/translations.csv`)

- Colonnes `keys,fr,en`. Le français est rempli ; l'anglais est vide pour l'instant (le jeu retombe sur le français, jamais sur la clé brute).
- Dans le code : `tr("MSG_HIT") % valeur`. Les listes de noms (difficultés, armes, modes de l'ennemi…) contiennent des **clés**, traduites à l'affichage.
- Ajouter un texte : une ligne dans le CSV, puis lancer l'import (`godot --headless --path . --import`).
- `tests/rpg_tests.gd` vérifie que toutes les clés utilisées existent et qu'aucun texte français n'est écrit en dur dans les scripts.
- La langue est forcée à « fr » dans les paramètres du projet (`internationalization/locale/test`) tant qu'il n'y a pas de menu de langue.

## Tests

`godot --headless --path . --fixed-fps 120 -s tests/rpg_tests.gd` — équivalence des chiffres, stats et modificateurs, matrice type de dégâts × matière, identifiants, équipement, sauvegarde (aller-retour, copie de secours, migration, version trop récente), traduction.

## Données de départ

`godot --headless --path . -s tools/make_data.gd` régénère les matières et les formules (à ne relancer que pour repartir de zéro : ça écrase les `.tres` édités).
