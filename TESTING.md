# Tests manuels — backlog

## À tester (récents en haut)

### feat: POC connexion Pubky Ring + profil Nexus — v0.2.0 — 2026-09-07

Reste à éprouver après la validation du parcours principal :

- [ ] **Où** : Pubky Ring, écran de confirmation
  - **Étape** : relancer une connexion et lire l'écran avant d'approuver
  - **Attendu** : Ring affiche « Flutky » comme application demandeuse
    (paramètre `x-source`) et la destination du rappel.

- [ ] **Où** : Pubky Ring, écran de confirmation
  - **Étape** : refuser / annuler au lieu d'approuver
  - **Attendu** : Flutky affiche « Connexion annulée dans Pubky Ring. » et
    reste sur l'écran d'accueil.

- [ ] **Où** : écran de profil, bas de page
  - **Étape** : faire défiler jusqu'aux sections « Liens », « Tags reçus » et
    « Session Ring »
  - **Attendu** : les liens s'ouvrent dans le navigateur ; les tags portent
    leur nombre de tagueurs ; la carte Session n'affiche **que la longueur**
    du secret, jamais sa valeur.

- [ ] **Où** : écran de profil
  - **Étape** : tirer vers le bas pour rafraîchir, puis appuyer sur l'icône de
    déconnexion
  - **Attendu** : rechargement du profil ; la déconnexion ramène à l'accueil
    et oublie la session.

- [ ] **Où** : écran d'accueil, mode avion activé
  - **Étape** : se connecter, approuver dans Ring
  - **Attendu** : un message d'erreur lisible, pas un écran figé.

- [ ] **Où** : quelle version de Pubky Ring est installée
  - **Étape** : Ring → À propos, relever le numéro
  - **Attendu** : information à consigner — elle dira si le blocage de la
    v0.1.0 venait bien du renommage `session_secret` → `grant_secret`
    (Ring ≤ 1.18) ou de l'hôte du lien de retour. Les deux corrections ont été
    livrées ensemble, on ne sait pas encore laquelle a débloqué.

## ✅ Validés

### feat: parcours principal du POC — v0.2.0 — validé le 2026-09-07

APK : `fr.delvops.flutky` · versionCode 2 · 46,6 Mo
(arm64-v8a, armeabi-v7a, x86_64) · MD5 `1eb9c8fee297f41b5943e49036f13b17`.

- [x] **Où** : accueil, bouton « Se connecter avec Pubky Ring » →
  **Attendu** : Ring passe au premier plan (validé le 2026-09-07)
- [x] **Où** : Ring, après approbation →
  **Attendu** : Flutky revient au premier plan tout seul, sans manip de retour
  (validé le 2026-09-07)
- [x] **Où** : écran de profil →
  **Attendu** : avatar, nom, statut, clé publique et bio du compte réel
  (validé le 2026-09-07)
- [x] **Où** : écran de profil, bloc « Activité » →
  **Attendu** : les six compteurs (publications, réponses, abonnés,
  abonnements, amis, fois taggé) portent les valeurs réelles du compte, non
  nulles et conformes à ce qu'affiche pubky.app (validé le 2026-09-07)
- [x] **Où** : avatar →
  **Attendu** : l'image se charge, pas l'initiale de repli
  (validé le 2026-09-07)

### fix: accepter `session_secret` en plus de `grant_secret` — v0.2.0 — validé le 2026-09-07

Ring ≤ 1.18 renvoie `session_secret` ; le nom est devenu `grant_secret` au
commit `4f2798a` du 2026-09-03, livré en v1.19. La v0.1.0 n'acceptait que le
second et rejetait le retour de Ring comme malformé.

- [x] **Où** : parcours complet de connexion → **Attendu** : plus de
  `MALFORMED_CALLBACK`, le profil s'affiche (validé le 2026-09-07)
