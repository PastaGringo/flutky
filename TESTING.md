# Tests manuels — backlog

## À tester (récents en haut)

### feat: flux Nexus et session persistante — v0.3.0 — 2026-09-07

APK : `fr.delvops.flutky` · versionCode **3** · signé avec la clé de débogage.

**Session persistante** — c'est le point qui demande de tuer l'app, pas
seulement de la mettre en arrière-plan :

- [ ] **Où** : n'importe quel écran, après s'être connecté
  - **Étape** : fermer complètement Flutky (balayer depuis les applications
    récentes), puis la rouvrir
  - **Attendu** : elle revient directement sur le flux, **sans repasser par
    Pubky Ring**. Un bref indicateur de chargement est normal.

- [ ] **Où** : bouton de déconnexion, en haut à droite
  - **Étape** : appuyer, lire la confirmation, valider
  - **Attendu** : retour à l'écran de connexion. Refermer et rouvrir l'app :
    elle doit redemander Ring — la session ne doit pas ressusciter.

- [ ] **Où** : redémarrage complet du téléphone
  - **Étape** : redémarrer, rouvrir Flutky
  - **Attendu** : la session tient toujours (le secret est dans le keystore
    Android, pas en mémoire).

**Flux** :

- [ ] **Où** : onglet « Flux », filtre « Abonnements » (par défaut)
  - **Étape** : comparer avec le fil de pubky.app
  - **Attendu** : les mêmes publications, avec avatar et nom d'auteur résolus
    (pas une clé de 52 caractères).

- [ ] **Où** : onglet « Flux »
  - **Étape** : faire défiler jusqu'en bas
  - **Attendu** : la page suivante se charge toute seule, sans doublon ni
    saut. L'indicateur apparaît en bas pendant le chargement.

- [ ] **Où** : filtres « Amis », « Global », « Favoris »
  - **Étape** : passer de l'un à l'autre
  - **Attendu** : le contenu change à chaque fois ; « Abonnements » et
    « Global » ne doivent pas afficher la même liste.

- [ ] **Où** : un post portant une ou plusieurs images
  - **Étape** : repérer un post marqué `image`
  - **Attendu** : la ou les images s'affichent ; plusieurs images défilent
    horizontalement.

- [ ] **Où** : onglet « Flux », puis « Profil », puis retour au flux
  - **Étape** : faire défiler le flux, passer sur le profil, revenir
  - **Attendu** : le flux a gardé sa position et ses pages déjà chargées.

- [ ] **Où** : onglet « Flux », mode avion
  - **Étape** : activer le mode avion et tirer pour rafraîchir
  - **Attendu** : un message d'erreur lisible au-dessus de la liste, pas un
    écran vide ni un plantage.

**Reste du parcours initial, non encore éprouvé** :

- [ ] **Où** : Pubky Ring, écran de confirmation
  - **Étape** : relancer une connexion et lire l'écran avant d'approuver
  - **Attendu** : Ring affiche « Flutky » comme application demandeuse.

- [ ] **Où** : Pubky Ring, écran de confirmation
  - **Étape** : annuler au lieu d'approuver
  - **Attendu** : « Connexion annulée dans Pubky Ring. »

- [ ] **Où** : onglet « Profil », bas de page
  - **Étape** : dérouler jusqu'aux sections « Liens », « Tags reçus » et
    « Session Ring »
  - **Attendu** : les liens s'ouvrent ; la carte Session n'affiche **que la
    longueur** du secret, jamais sa valeur.

- [ ] **Où** : version de Pubky Ring installée
  - **Étape** : Ring → À propos, relever le numéro
  - **Attendu** : information à consigner — elle dira si le blocage de la
    v0.1.0 venait du renommage `session_secret` → `grant_secret` (Ring ≤ 1.18)
    ou de l'hôte du lien de retour. Les deux corrections ayant été livrées
    ensemble, on ne sait pas encore laquelle a débloqué.

## ✅ Validés

### feat: parcours principal du POC — v0.2.0 — validé le 2026-09-07

- [x] **Où** : accueil, bouton « Se connecter avec Pubky Ring » →
  **Attendu** : Ring passe au premier plan (validé le 2026-09-07)
- [x] **Où** : Ring, après approbation →
  **Attendu** : Flutky revient au premier plan tout seul, sans manip de retour
  (validé le 2026-09-07)
- [x] **Où** : écran de profil →
  **Attendu** : avatar, nom, statut, clé publique et bio du compte réel
  (validé le 2026-09-07)
- [x] **Où** : écran de profil, bloc « Activité » →
  **Attendu** : les six compteurs portent les valeurs réelles du compte, non
  nulles et conformes à ce qu'affiche pubky.app (validé le 2026-09-07)
- [x] **Où** : avatar → **Attendu** : l'image se charge, pas l'initiale de
  repli (validé le 2026-09-07)

### fix: accepter `session_secret` en plus de `grant_secret` — v0.2.0 — validé le 2026-09-07

Ring ≤ 1.18 renvoie `session_secret` ; le nom est devenu `grant_secret` au
commit `4f2798a` du 2026-09-03, livré en v1.19. La v0.1.0 n'acceptait que le
second et rejetait le retour de Ring comme malformé.

- [x] **Où** : parcours complet de connexion → **Attendu** : plus de
  `MALFORMED_CALLBACK`, le profil s'affiche (validé le 2026-09-07)
