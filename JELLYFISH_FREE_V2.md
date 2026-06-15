# Jellyfish Free V2

Cette version reste sans Cloud Functions / Blaze.

## Sources utilisées

- Firestore `jellyfish_reports` pour les signalements communautaires.
- API officielle iNaturalist v1 en lecture directe depuis Flutter.

## Comportement

- Les signalements utilisateur peuvent indiquer : aucune méduse, quelques méduses, beaucoup de méduses, piqûre.
- Les observations iNaturalist sont ajoutées comme source externe, sans écriture dans Firestore.
- Si iNaturalist ne répond pas, l'application continue de fonctionner avec les signalements communautaires.

## Limites

- iNaturalist est une source naturaliste, pas une source d'alerte plage.
- Une observation iNaturalist ne prouve pas une présence actuelle sur la zone de baignade.
- Pour Meduseo/ACRI, il faudra un accès API documenté ou un accord explicite.
