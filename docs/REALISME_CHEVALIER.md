# Réalisme visuel du chevalier (étape 8)

| Élément | Avant | Après |
|---|---|---|
| Plates | métal lisse bleuté | acier rayé (rugosité et normales générées), bords plus brillants, reflets du ciel HDRI |
| Mailles | gris uni | relief d'anneaux fin, scintillement sur les plis |
| Cuir (gants, bottes) | marron uni | texture Poly Haven `brown_leather` |
| Tissus | blanc / rouge vif uni | lin et laine Poly Haven, tabard avec plis (`pleats`), teintes naturelles (lie-de-vin, indigo, vert mousse, brun-noir) |
| Visage | aucun (mannequin) | tête d'homme modelée : nez, arcades, pommettes, menton, oreilles, yeux, sourcils, cheveux courts ; barbe courte (pièce séparée) |
| Mains | mains lisses | gantelets de plates (chevalier), gants de cuir (homme d'armes, archer) |
| Épée longue | ≈ 1,0 m | ≈ 1,1 m |

Aperçus : `docs/apercu_tenues_apres8.png` (3 tenues, face / profil / dos), `docs/apercu_tetes.png` (tête nue, barbe, capuchon, bassinet, heaume).

## Limites
- Le visage est sobre et un peu allongé (modelage par déplacements sur le crâne du Mannequin) : crédible de loin, moins en gros plan. Autre solution possible : toujours porter une coiffe ou un capuchon.
- Les bords des coques (bassinet, capuchon) sont crénelés de près ; les gantelets sont des moufles sans doigts séparés.
- L'acier reflète fortement le ciel bleu : réglable dans `armor_materials.gd` (`roughness`, `metallic_specular`).
