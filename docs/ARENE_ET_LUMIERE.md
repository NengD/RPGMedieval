# Arène, matériaux, lumière et qualité (étape 5)

## Ce qui a changé
- **Sol, murs, piliers, plateforme, rampe** : matériaux PBR Poly Haven 1k (pavés, pierre) au lieu du damier. Les textures sont en
  projection **triplanaire** à l'échelle du monde (`Arena._pbr`) : 1 tuile = 2,6 m (sol) ou 3 m (murs), quelle que soit la forme, sans UV à régler.
- **Collisions identiques** à avant (mêmes noms, mêmes tailles, couche « monde ») : la jouabilité et l'IA ne changent pas.
- **Accessoires modélisés dans Blender** (`tools/blender/make_props.py` → `assets/props/*.glb`) : caisses (2 tailles), tonneau, râtelier d'armes,
  poteau d'entraînement. Le bois PBR remplace par code les matériaux nommés « bois » (`Arena._add_prop`).
- **Ciel HDRI** (`assets/sky/ciel_nuageux_1k.hdr`) : ambiance et reflets (les armures métalliques reflètent le ciel).
- **Lumière** : soleil avec ombres douces (PCSS), occlusion ambiante (SSAO), brouillard léger, tonemapping filmique.

## Qualité graphique : F10 (Bas / Moyen / Élevé)
Réglée dans `scripts/quality_settings.gd` (tableau `PROFILES`), mémorisée dans `user://reglages.cfg`.

| | Bas | Moyen (défaut) | Élevé |
|---|---|---|---|
| Occlusion ambiante (SSAO) | non | oui | oui, plus forte |
| Brouillard | non | oui | oui |
| Lueur (glow) | non | non | oui |
| Ombres | 1 cascade, 35 m, 2048 | 2 cascades, 50 m, 4096 | 4 cascades, 70 m, 8192 |
| Douceur des ombres | dures | douces | très douces |
| Anti-crénelage (MSAA) | non | 2x | 4x |
| Échelle de rendu | 80 % | 100 % | 100 % |

## Fluidité (mesurée)
`godot --path . --resolution 1280x720 --position 6000,3000 -s tests/perf_look.gd -- 6` : l'arène avec 7 personnages complets
(tenue de plates, épée, écu : ≈ 1 million de sommets), sans limite de synchro verticale. Sur cette machine :

| Qualité | Images/s | ms/image | Appels de dessin |
|---|---|---|---|
| Bas | 395 | 2,5 | 351 |
| Moyen | 161 | 6,2 | 380 |
| Élevé | 161 | 6,2 | 750 |

Très au-dessus de 60 images/s même au niveau Élevé. Les chiffres dépendent de ta carte graphique : refais la mesure chez toi si besoin.

## Remplacer une texture
Dépose `diff.jpg` (couleur), `nor_gl.jpg` (normale OpenGL) et `arm.jpg` (R = occlusion, G = rugosité, B = métal, comme sur Poly Haven)
dans `assets/textures/<dossier>/`, ou change le dossier dans `Arena._build_geometry`. Crédite la ressource dans `CREDITS.md`.

## Ajouter un accessoire
Ajoute une fonction dans `tools/blender/make_props.py` (matériaux « bois », « fer » ou « paille »), exécute le script, puis un appel
`_add_prop(nom, modèle, position, rotation, taille de collision)` dans `Arena._build_props`. Un obstacle d'au moins 1,2 m de haut peut recevoir
un rayon d'abri (dernier argument) pour que l'ennemi se cache derrière ; les objets plus bas ou plus fins ne cachent personne.
