# Jellyfish Firebase Free V1

Cette version ne dépend pas de Cloud Functions / Blaze.

## Déploiement

```powershell
cd C:\SwimBuddy
flutter analyze
firebase deploy --only firestore:rules --project swimbuddy-app
```

## Fonctionnement

- Flutter lit la collection `jellyfish_reports`.
- Les utilisateurs connectés peuvent ajouter un signalement :
  - `none` : pas de méduse observée
  - `few` : quelques méduses
  - `many` : beaucoup de méduses
  - `sting` : piqûre / brûlure constatée
- Les alertes sont calculées côté Flutter selon le rayon paramétré dans l'application.
- Les signalements expirent automatiquement côté logique app via le champ `expiresAt`.

## Plus tard

Si le projet passe un jour en Blaze, il sera possible de réactiver un dossier `functions` pour importer iNaturalist / Méduseo / ACRI côté backend.
