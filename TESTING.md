# Tests manuels — backlog

## À tester (récents en haut)

### feat: mentions cliquables et écriture de posts — v0.4.0 — 2026-09-07

APK : `fr.delvops.flutky` · versionCode **4** · signé avec la clé de débogage.

**Écrire un post — le point vraiment incertain.** Je n'ai pas pu l'éprouver :
il faut une session valide, donc ton compte. Deux issues possibles, et la
seconde n'est pas un échec du travail mais une limite connue :

- [ ] **Où** : onglet « Flux », bouton flottant en bas à droite
  - **Étape** : écrire quelques mots, appuyer sur « Publier »
  - **Attendu (cas favorable)** : la feuille se ferme, le post apparaît en tête
    du flux avec la mention « en attente d'indexation », et un bandeau confirme.
    Vérifier ensuite sur **pubky.app** que le post y est bien.
  - **Attendu (cas défavorable)** : un message d'erreur détaillé, avec le code
    HTTP et la réponse brute du serveur. **Copie-le moi tel quel** — c'est ce
    qui dira si c'est le type de session ou l'adresse d'écriture.

- [ ] **Où** : feuille de composition
  - **Étape** : coller un texte de plus de 2 000 caractères
  - **Attendu** : le compteur passe en rouge et « Publier » se désactive, sans
    aller déranger le serveur.

**Mentions** :

- [ ] **Où** : onglet « Flux », un post contenant une mention
  - **Étape** : repérer un post du type « Hey @Quelqu'un, … »
  - **Attendu** : la mention s'affiche comme **@Nom** en vert, pas comme une
    suite de 57 caractères. Si le profil n'est pas résolu, une clé abrégée
    (`abc123…wxyz`), jamais le bloc complet.

- [ ] **Où** : une mention @Nom
  - **Étape** : appuyer dessus
  - **Attendu** : une feuille s'ouvre avec l'avatar, le nom, le statut, la bio
    et les compteurs de la personne citée.

- [ ] **Où** : l'avatar ou le nom d'un auteur de post
  - **Étape** : appuyer sur l'avatar
  - **Attendu** : la même feuille de profil s'ouvre.

- [ ] **Où** : un post contenant un lien https
  - **Étape** : appuyer sur le lien
  - **Attendu** : il s'ouvre dans le navigateur ; le lien est souligné dans le
    texte.

**Reste du parcours, non encore éprouvé** :

- [ ] **Où** : session persistante
  - **Étape** : tuer complètement l'app (balayage depuis les récentes), rouvrir
  - **Attendu** : retour direct sur le flux, sans repasser par Ring.

- [ ] **Où** : Pubky Ring, écran de confirmation
  - **Étape** : relancer une connexion, lire l'écran, puis annuler
  - **Attendu** : Ring affiche « Flutky » comme demandeur ; l'annulation donne
    « Connexion annulée dans Pubky Ring. »

- [ ] **Où** : version de Pubky Ring installée
  - **Étape** : Ring → À propos, relever le numéro
  - **Attendu** : information à consigner. Elle dira du même coup si l'écriture
    a une chance de marcher : un Ring **≤ 1.18** rend un `session_secret` de
    type cookie, que cette version sait présenter ; un Ring **≥ 1.19** rend un
    `grant_secret`, qui exige un jeton signé qu'elle ne sait pas produire.

## ✅ Validés

### feat: flux Nexus et session persistante — v0.3.0 — validé le 2026-09-07

- [x] **Où** : onglet « Flux » → **Attendu** : le flux s'affiche avec avatars
  et noms d'auteurs résolus (validé le 2026-09-07)

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
