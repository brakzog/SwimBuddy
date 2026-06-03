# SwimTracker — Flutter

App de suivi de natation en mer. Cross-platform iOS + Android.

## Stack

| Couche | Technologie |
|---|---|
| UI | Flutter 3.19+ |
| State | Riverpod 2 |
| Backend | Firebase (Auth + Firestore) |
| Santé | package `health` (HealthKit iOS / Health Connect Android) |
| Océan | Open-Meteo Marine API |
| Méduses | JellyWatch / iNaturalist API |
| i18n | flutter_localizations (FR + EN) |

---

## Setup — à faire UNE SEULE FOIS

### 1. Cloner et installer les dépendances

```bash
flutter pub get
```

### 2. Configurer Firebase

Installe la CLI Firebase si ce n'est pas déjà fait :

```bash
npm install -g firebase-tools
firebase login

# Installe FlutterFire CLI
dart pub global activate flutterfire_cli
```

Crée un projet sur https://console.firebase.google.com, puis :

```bash
flutterfire configure
```

Cette commande va :
- Te demander de choisir ton projet Firebase
- Générer `lib/firebase_options.dart` automatiquement
- Ajouter `google-services.json` dans `android/app/`
- Ajouter `GoogleService-Info.plist` dans `ios/Runner/`

### 3. Activer les services Firebase

Dans la console Firebase :
- **Authentication** → Sign-in methods → activer "Anonymous"
- **Firestore** → Créer une base de données en mode "production"

Règles Firestore à configurer (console → Firestore → Règles) :

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }
  }
}
```

### 4. Permissions iOS

Dans `ios/Runner/Info.plist`, ajouter :

```xml
<key>NSHealthShareUsageDescription</key>
<string>SwimTracker reads your heart rate, distance and calories from Apple Watch.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>SwimTracker writes swim sessions to your Health app.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>SwimTracker uses your location to check sea temperature and jellyfish alerts.</string>
```

Dans Xcode → Signing & Capabilities → ajouter **HealthKit**.

### 5. Permissions Android

Dans `android/app/src/main/AndroidManifest.xml` :

```xml
<uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
<uses-permission android:name="android.permission.health.READ_DISTANCE"/>
<uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

### 6. Lancer l'app

```bash
flutter run
```

---

## Structure du projet

```
lib/
├── main.dart                    # Entry point, Firebase init, AuthGate
├── firebase_options.dart        # Généré par flutterfire configure
├── l10n/
│   ├── app_en.arb               # Traductions anglaises
│   └── app_fr.arb               # Traductions françaises
├── core/
│   ├── models/
│   │   └── swim_session.dart    # Modèle de session + sérialisation Firestore
│   └── services/
│       ├── auth_service.dart    # Firebase Auth
│       └── firestore_service.dart # CRUD sessions
├── features/
│   ├── session/                 # Étape 2 : démarrer / arrêter une session
│   ├── health/                  # Étape 3 : FC, calories, distance (montre)
│   ├── ocean/                   # Étape 4 : température eau
│   └── jellyfish/               # Étape 5 : alertes méduses
└── shared/
    ├── theme/
    │   └── app_theme.dart       # Couleurs, typographie
    └── widgets/
        └── app_shell.dart       # Navigation bas de page
```

---

## Roadmap

- [x] **Étape 1** — Initialisation : projet, Firebase, Riverpod, i18n, navigation
- [ ] **Étape 2** — Feature Session : chrono, démarrer/terminer, résumé
- [ ] **Étape 3** — Feature Health : FC, calories, distance depuis la montre
- [ ] **Étape 4** — Feature Ocean : température eau via Open-Meteo Marine
- [ ] **Étape 5** — Feature Jellyfish : alertes méduses via JellyWatch
