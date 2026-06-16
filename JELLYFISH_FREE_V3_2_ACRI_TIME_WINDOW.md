# SwimBuddy — Méduses ACRI + fenêtre temporelle

Cette version garde l'architecture gratuite sans Cloud Functions :

- ACRI Méduse comme source principale externe.
- Firestore/SwimBuddy pour les signalements communautaires.
- iNaturalist uniquement en fallback si ACRI ne renvoie rien.

Améliorations ajoutées :

- Préférence utilisateur `jellyfish_time_window_hours`.
- Choix de période dans les paramètres : 24 h, 48 h, 72 h, 7 jours.
- Requête ACRI filtrée avec `observation_date ge <date>` selon la période choisie.
- iNaturalist utilise aussi la même période.
- La carte méduses affiche maintenant l'ancienneté des signalements.
- Résumé enrichi : nombre d'alertes, période, distance du plus proche, ancienneté.
- Affichage des 3 signalements les plus proches avec distance, âge et source.

Valeur par défaut : 72 h.
