# Crédits

Toutes les ressources doivent être gratuites (CC0 ou licence libre) et notées ici.

| Ressource | Auteur | Licence | Source | Utilisée pour |
|-----------|--------|---------|--------|---------------|
| *(étapes 1 à 4 : formes simples générées en code, aucune ressource externe)* | | | | |
| Personnage « Paladin J Nordstrom » | Mixamo / Adobe | Gratuit avec compte Adobe, usage libre dans un jeu | https://www.mixamo.com | héros et ennemi (`assets/hero/hero.fbx`) |
| Animations « Pro Sword and Shield Pack » (51 animations, 22 utilisées) | Mixamo / Adobe | Gratuit avec compte Adobe, usage libre dans un jeu | https://www.mixamo.com | marche, course, attaques, parade, coups reçus, mort… (`assets/anims/`) |
| Animations « Pro Melee Axe Pack » (47 animations, 4 attaques utilisées) | Mixamo / Adobe | Gratuit avec compte Adobe, usage libre dans un jeu | https://www.mixamo.com | attaques haut / droite / gauche / estoc (`assets/anims/axe_*.fbx`) |
| Animations « Pro Longbow Pack » (27 animations, 12 utilisées) | Mixamo / Adobe | Gratuit avec compte Adobe, usage libre dans un jeu | https://www.mixamo.com | marche/course à l'arc, bandage, relâchement (`assets/anims/bow_*.fbx`) |
| Animations « Pro Rifle Pack » (50 animations, 10 utilisées) | Mixamo / Adobe | Gratuit avec compte Adobe, usage libre dans un jeu | https://www.mixamo.com | marche/course/visée de l'arbalète (`assets/anims/rifle_*.fbx`) |
| Modèles d'armes lot 1 : épée longue, épée courte, hache de guerre, masse d'armes, lance, épée à deux mains, écu, arc long, arbalète, flèche, carreau | Créés pour ce projet (Claude, via Blender en ligne de commande, `tools/blender/make_weapons.py`) | Libres de droits (aucune ressource externe ; matériaux unis, pas de texture) | — | `assets/weapons/*.glb` |
| Personnage « Mannequin » (corps de base nu, squelette) | Mixamo / Adobe | Gratuit avec compte Adobe, usage libre dans un jeu | https://www.mixamo.com | corps de base de tous les personnages (`assets/base/base_rig.tscn`, `body.glb` en dérive) |
| Pièces d'armure et d'habits lot 1 (17 pièces : chemise, braies, gambison, haubert, cuirasse, spalières, canons, gantelets, tassettes, grèves, solerets, bassinet, heaume, capuchon, tabard, gants et bottes de cuir) | Créées pour ce projet (Claude, Blender en ligne de commande, `tools/blender/make_armor.py`), coques du corps de base | Libres de droits (aucune ressource externe ; matériaux unis) | — | `assets/armor/*.glb` |
| Ciel HDRI « Kloofendal 48d Partly Cloudy (Pure Sky) » 1k | Greg Zaal / Poly Haven | CC0 | https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky | ciel et éclairage ambiant (`assets/sky/ciel_nuageux_1k.hdr`) |
| Texture PBR « Cobblestone Floor 01 » 1k (diffuse, normale, ARM) | Poly Haven | CC0 | https://polyhaven.com/a/cobblestone_floor_01 | sol de l'arène (`assets/textures/pave/`) |
| Texture PBR « Rustic Stone Wall » 1k | Poly Haven | CC0 | https://polyhaven.com/a/rustic_stone_wall | murs, piliers, plateforme, rampe (`assets/textures/pierre/`) |
| Texture PBR « Rough Wood » 1k | Poly Haven | CC0 | https://polyhaven.com/a/rough_wood | caisses, tonneaux, râtelier, poteaux (`assets/textures/bois/`) |
| Accessoires de l'arène : caisses, tonneau, râtelier, poteau d'entraînement | Créés pour ce projet (Claude, Blender en ligne de commande, `tools/blender/make_props.py`) | Libres de droits | — | `assets/props/*.glb` |
| Textures PBR « Brown Leather », « Rough Linen », « Poly Wool Herringbone » 1k (couleur, normale, ARM) | Poly Haven | CC0 | https://polyhaven.com/a/brown_leather · https://polyhaven.com/a/rough_linen · https://polyhaven.com/a/poly_wool_herringbone | cuir, tissus et tabards des armures (`assets/textures/cuir`, `lin`, `laine`) ; script `tools/fetch_polyhaven.py` |
| Acier, mailles, peau, cheveux | Générés par code (bruit, `scripts/character/armor_materials.gd`) et dans Blender (`tools/blender/make_armor.py`) | Libres de droits | — | rayures d'acier, anneaux de mailles, tête sculptée (`assets/armor/armure_tete_homme.glb`, `armure_barbe.glb`) |
| Universal Animation Library (Standard) 1 et 2, ~120 animations (épée, parade, écu, coups reçus, déplacements…), transférées sur le squelette Mixamo (`assets/anims/ual_library.res`, script `tools/retarget_ual.gd`) | Quaternius | CC0 1.0 | https://quaternius.itch.io/universal-animation-library · https://quaternius.itch.io/universal-animation-library-2 (copies : https://opengameart.org/content/universal-animation-library · https://opengameart.org/content/universal-animation-library-2) | animations de combat candidates (étape 9) |

Moteur : [Godot Engine](https://godotengine.org) (licence MIT).
