# Tests manuels — backlog

## À tester (récents en haut)

### fix: le secret exporté n'est pas la valeur du cookie — v0.7.0 — 2026-09-07

APK : `fr.delvops.flutky` · versionCode **7** · signé avec la clé de débogage.

Le diagnostic a donné la réponse en une ligne : secret de **79 caractères**,
**2 segments**. Soit 52 (la clé) + 1 (deux-points) + 26 (le vrai secret). Le
SDK exporte `format!("{public_key}:{cookie}")`, et j'envoyais la chaîne
entière comme valeur du cookie — le serveur cherchait le secret et trouvait la
clé collée devant.

- [ ] **Où** : page Diagnostic (icône microscope)
  - **Étape** : la rouvrir et comparer deux sondes
  - **Attendu** : « Session — cookie, hôte en paramètre » en **200**, et
    « Témoin — cookie NON découpé » en **401**. Le contraste entre les deux
    prouve que c'est bien le découpage qui débloque, et rien d'autre.

- [ ] **Où** : feuille de composition
  - **Étape** : l'ouvrir sans écrire
  - **Attendu** : la pastille passe au vert — et cette fois elle a réellement
    interrogé le serveur.

- [ ] **Où** : feuille de composition
  - **Étape** : écrire un message et publier
  - **Attendu** : le post part, apparaît en tête du flux, **et se retrouve sur
    pubky.app**. C'est la seule preuve qui compte.

- [ ] **Où** : pubky.app, le post publié
  - **Étape** : vérifier sa date
  - **Attendu** : l'heure de publication, pas une date absurde — un identifiant
    Crockford mal calculé se verrait là.

### feat: page de diagnostic interne — v0.6.0 — 2026-09-07

APK : `fr.delvops.flutky` · versionCode **6** · signé avec la clé de débogage.

La v0.5.0 affichait « cookie · écriture ouverte » alors que l'écriture était
refusée : pour une session cookie, ma vérification ne faisait **aucun appel
réseau**, elle se contentait de construire l'en-tête. C'était un faux positif,
il est corrigé — le cookie est maintenant présenté à `GET /session`.

Le diagnostic s'ouvre par l'icône microscope, en haut de l'écran.

- [ ] **Où** : icône microscope → page Diagnostic
  - **Étape** : laisser les sondes tourner, puis **copier le rapport** avec
    l'icône en haut à droite et me l'envoyer
  - **Attendu** : c'est ce rapport qui tranche. La valeur du secret n'y figure
    jamais, seulement sa longueur et sa forme.

- [ ] **Où** : page Diagnostic, première sonde « lecture publique existante »
  - **Étape** : regarder son code
  - **Attendu** : **200**. Un 404 voudrait dire que ton compte n'est pas sur
    `homeserver.pubky.app` — et alors toutes mes écritures partaient depuis le
    début à la mauvaise adresse.

- [ ] **Où** : page Diagnostic, les quatre sondes « Session »
  - **Étape** : repérer s'il y en a une en vert
  - **Attendu** : une seule suffit. Celle qui passe désigne le bon format
    d'authentification ; si toutes échouent, la session elle-même est en cause.

- [ ] **Où** : feuille de composition
  - **Étape** : l'ouvrir sans écrire
  - **Attendu** : la pastille ne doit plus mentir. Si l'écriture est refusée,
    elle passe au rouge **avant** que tu rédiges.

### feat: authentification grant — publication débloquée — v0.5.0 — 2026-09-07

APK : `fr.delvops.flutky` · versionCode **5** · signé avec la clé de débogage.

Le 401 de la v0.4.0 était le bon diagnostic : ta session est de type **grant**,
pas cookie. La v0.5.0 implémente l'échange grant → jeton porteur en Dart
(preuve de possession signée en Ed25519), ce que seul le SDK Rust faisait
jusqu'ici.

- [ ] **Où** : onglet « Flux », bouton flottant, en haut à droite de la feuille
  - **Étape** : ouvrir la feuille de composition **sans rien écrire**, et
    regarder la pastille
  - **Attendu** : « vérification… » puis **« grant · écriture ouverte »** en
    vert. Si elle passe au rouge, le message sous le titre donne la réponse
    exacte du serveur — copie-la moi.

- [ ] **Où** : feuille de composition
  - **Étape** : écrire un message, publier
  - **Attendu** : la feuille se ferme, le post apparaît en tête du flux avec
    « en attente d'indexation ». **Vérifier ensuite sur pubky.app** que le post
    y est bien — c'est la seule preuve qui compte.

- [ ] **Où** : pubky.app, le post publié depuis Flutky
  - **Étape** : le regarder de près
  - **Attendu** : contenu intact, date correcte. Une date absurde signalerait
    un identifiant Crockford mal calculé — le cas où l'indexeur jette le post
    en silence.

- [ ] **Où** : feuille de composition, plus d'une heure après la connexion
  - **Étape** : publier de nouveau
  - **Attendu** : ça marche quand même. Le jeton porteur expire au bout d'une
    heure et doit être renouvelé tout seul à partir du grant.

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
