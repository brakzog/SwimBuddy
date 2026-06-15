# SwimBuddy — Jellyfish Free V3 ACRI

V3 gratuite sans Cloud Functions / sans Blaze.

## Sources utilisées

1. ACRI Méduse API publique
   - `https://meduse.acri.fr/api/v1/campaigns/meduse/observations`
   - filtrage par date sur les dernières 72h
   - mapping quantité :
     - `none` -> pas de méduse
     - `one` -> quelques méduses
     - `several` / `many` / `lots` -> beaucoup de méduses

2. Firestore communautaire SwimBuddy
   - conserve les signalements utilisateurs existants.

3. iNaturalist
   - fallback uniquement si ACRI ne renvoie rien ou échoue.

## À tester

```powershell
flutter analyze
flutter build apk --debug
```

Puis push pour CodeMagic iOS.

## Remarque

ACRI devient la source principale car elle est spécialisée méduses, française, géolocalisée, et contient aussi les observations `none`.
