# Tests manuels — backlog

## À tester (récents en haut)

### feat: répondre, traduire les posts des autres, image en grand — v0.15.0 — 2026-09-08

- [ ] **Où** : écran d'un post, bouton *Répondre* en bas
  - **Étape** : écrire une réponse et l'envoyer
  - **Attendu** : elle apparaît dans la liste au bout de quelques secondes, et
    aussi sur pubky.app sous le post d'origine.

- [ ] **Où** : une réponse qui porte elle-même un compteur de réponses
  - **Étape** : la toucher
  - **Attendu** : son propre fil s'ouvre, avec le post parent au-dessus sous
    « EN RÉPONSE À ». Nexus ne rend que les enfants **directs** : c'est
    normal de descendre écran par écran.

- [ ] **Où** : n'importe quelle carte, icône de traduction à droite des
    compteurs
  - **Étape** : toucher un post en anglais
  - **Attendu** : le texte passe en français, une ligne le signale, et
    l'icône devient une flèche de retour. Les mentions et liens sont
    intacts. Sans clé DeepL, un message dit où en ajouter une.

- [ ] **Où** : un post avec image
  - **Étape** : toucher l'image
  - **Attendu** : plein écran, zoomable au pincement, croix pour fermer.
    L'image chargée est la variante `main`, pas la vignette.

- [ ] **Où** : fenêtre d'écriture
  - **Étape** : compter les boutons d'action
  - **Attendu** : **cinq** sont visibles (Mentionner, Jeb, Image, Traduire,
    et Annuler après une traduction), sur deux lignes si besoin. Avant, la
    rangée débordait et Traduire était hors écran.

- [ ] **Où** : flux, bouton *Demander à Jeb* au-dessus du bouton d'écriture
  - **Étape** : le toucher
  - **Attendu** : le champ affiche **`@Jeb`**, pas la clé. Ce raccourci
    passait à côté du mécanisme d'alias.

- [ ] **Où** : un fil de discussion
  - **Étape** : regarder sous chaque réponse
  - **Attendu** : plus d'encart « post d'origine indisponible » — le post
    parent est déjà affiché au-dessus.

### feat: images dans un post, fil de discussion, pastille — v0.14.0 — 2026-09-08

- [ ] **Où** : fenêtre d'écriture, bouton *Image*
  - **Étape** : choisir une photo, vérifier l'aperçu, puis publier
  - **Attendu** : une barre de progression pendant l'envoi, puis le post
    apparaît. Quelques secondes plus tard l'image s'affiche dans la carte.
    ⚠️ Chemin non éprouvé de mon côté : je ne peux pas publier depuis ton
    compte. C'est le test le plus important de cette version.

- [ ] **Où** : même fenêtre
  - **Étape** : choisir une image **sans écrire de texte**, publier
  - **Attendu** : le bouton Publier est actif — une image est un contenu.

- [ ] **Où** : le post publié avec image, sur pubky.app
  - **Étape** : ouvrir le post depuis un navigateur
  - **Attendu** : l'image s'affiche là aussi. C'est ce qui prouve que
    l'identifiant du blob a été calculé juste — un mauvais identifiant est
    accepté par le homeserver et **ignoré en silence** par l'indexeur.

- [ ] **Où** : flux, sur n'importe quelle carte
  - **Étape** : toucher la carte (pas un lien ni une mention)
  - **Attendu** : l'écran du post s'ouvre, avec les **libellés en toutes
    lettres** et les réponses. Sur ton post mentionnant Jeb : 5 libellés et
    1 réponse.

- [ ] **Où** : même carte
  - **Étape** : toucher une **mention** ou un **lien** dans le texte
  - **Attendu** : la fiche du profil, ou le navigateur — pas l'écran du post.
    C'est le témoin que le clic de la carte ne vole pas les autres.

- [ ] **Où** : barre du haut
  - **Étape** : attendre une notification, regarder la cloche
  - **Attendu** : une pastille chiffrée. Elle disparaît dès l'ouverture de la
    liste. ⚠️ Le décompte est **local à l'appareil** : Nexus n'a aucune
    notion de lu/non-lu.

- [ ] **Où** : liste des notifications
  - **Étape** : toucher une notification qui concerne un post
  - **Attendu** : le post s'ouvre. Celles sans post (un abonnement, par
    exemple) restent inertes et gardent leur icône.

- [ ] **Où** : juste après avoir publié
  - **Étape** : laisser la carte « en attente d'indexation » sans rien toucher
  - **Attendu** : elle se remplace toute seule en quelques secondes par le
    vrai post, avec sa date, ses compteurs et son image.

### fix: la traduction passe à DeepL — v0.13.0 — 2026-09-07

ML Kit est retiré : il échouait sur téléphone réel
(`MissingPluginException`) et pesait 19 Mo. MyMemory, essayé ensuite, répondait
504 par intermittence. La traduction demande maintenant **une clé DeepL**.

- [ ] **Où** : Réglages → section *Traduction*
  - **Étape** : créer une clé gratuite sur deepl.com (plan API Free), la coller
  - **Attendu** : sous le champ, « Clé acceptée — N caractères utilisés sur
    500000 » apparaît en vert au bout d'une seconde.

- [ ] **Où** : même champ
  - **Étape** : y coller n'importe quoi qui ne soit pas une clé
  - **Attendu** : « DeepL a refusé cette clé » en rouge. C'est le témoin qui
    prouve que la vérification vérifie quelque chose.

- [ ] **Où** : fenêtre d'écriture, **sans** clé renseignée
  - **Étape** : toucher *Traduire*
  - **Attendu** : un message dit d'ajouter une clé dans les réglages. Aucune
    erreur réseau, aucune tentative d'appel.

- [ ] **Où** : fenêtre d'écriture, **avec** clé
  - **Étape** : écrire une phrase contenant `@Jeb`, toucher *Traduire*,
    laisser *Détecter automatiquement* en source
  - **Attendu** : le texte est traduit et `@Jeb` est **inchangé**.
    ✅ Validé le 2026-09-08 : « j'ai fait deepl ça marche nickel ».

### feat: découverte publique, notifications en haut, @Nom — v0.12.0 — 2026-09-07

- [ ] **Où** : barre du bas
  - **Étape** : repérer l'onglet **Découverte** à la place de Notifications
  - **Attendu** : quatre onglets — Flux, Découverte, PM (WIP), Profil.

- [ ] **Où** : barre du haut, icône cloche à gauche des autres
  - **Étape** : la toucher
  - **Attendu** : l'écran Notifications s'ouvre en page, avec un bouton retour.
    Le contenu est le même qu'avant.

- [ ] **Où** : onglet Découverte
  - **Étape** : regarder le haut de la liste, puis toucher un avatar
  - **Attendu** : une rangée de comptes à découvrir ; toucher l'un d'eux ouvre
    sa fiche, avec le bouton Suivre.

- [ ] **Où** : onglet Découverte, bandeau de libellés
  - **Étape** : toucher `#bitcoin`, puis revenir sur *Populaire*
  - **Attendu** : la liste ne montre que des posts portant ce libellé, et
    *Populaire* rend une liste différente du flux chronologique.

- [ ] **Où** : fenêtre d'écriture, bouton *Ask Jeb*
  - **Étape** : le toucher
  - **Attendu** : le champ affiche **`@Jeb`**, pas une clé de 52 caractères.
    Le compteur de caractères compte tout de même les 57 réels.

- [ ] **Où** : même fenêtre, après avoir inséré `@Jeb`
  - **Étape** : publier, puis ouvrir le post dans le flux
  - **Attendu** : la mention est bien active — c'est le contrôle qui prouve
    que la substitution à la publication a fonctionné. ⚠️ Non éprouvé de mon
    côté : je ne peux pas publier depuis ton compte.

- [ ] **Où** : même fenêtre, bouton *Traduire*
  - **Étape** : écrire une phrase contenant `@Jeb`, toucher *Traduire*
  - **Attendu** : une fiche s'ouvre avec **deux menus** (source détectée et
    cible) et un **bouton Traduire** — rien ne part avant qu'on le touche.
    Après traduction, `@Jeb` est **inchangé** au milieu du texte traduit.

### feat: traduction du brouillon, onglet PM inerte, articles cités — v0.11.0 — 2026-09-07

- [ ] **Où** : fenêtre d'écriture d'un post
  - **Étape** : taper trois phrases en français, toucher l'icône de traduction,
    choisir « English »
  - **Attendu** : le texte est remplacé par sa traduction, et un bouton
    *Annuler* revient au texte d'origine. La toute première fois, un modèle se
    télécharge — quelques secondes d'attente, sur Wi-Fi de préférence.

- [ ] **Où** : même fenêtre, hors ligne (mode avion)
  - **Étape** : traduire vers une langue déjà utilisée une fois
  - **Attendu** : la traduction fonctionne quand même — le modèle est sur
    l'appareil. Vers une langue jamais utilisée, un message dit que le
    téléchargement a échoué, sans perdre le texte saisi.

- [ ] **Où** : barre d'onglets du bas
  - **Étape** : toucher l'onglet **PM**
  - **Attendu** : l'écran s'affiche et annonce que la messagerie n'existe pas
    encore. Rien n'est cliquable, rien ne part sur le réseau.

- [ ] **Où** : flux, sur un repost qui cite un **article** (kind `long`)
  - **Étape** : regarder le bloc cité, pas seulement le post principal
  - **Attendu** : le titre et le début du texte, jamais du JSON brut.
    Post témoin : `pubky.app/post/w3ase343…/0035NP925DNX0`.

### feat: écriture, suivre, mentions, Ask Jeb, notifications — v0.9.0 et v0.10.0 — 2026-09-07

Livré sans entrée de test à l'époque ; à reprendre ici.

- [ ] **Où** : profil de quelqu'un d'autre
  - **Étape** : toucher *Suivre*, quitter l'écran, y revenir
  - **Attendu** : l'état reste « Abonné ». Nexus a du retard : compter
    quelques secondes avant que le compteur du profil bouge.

- [ ] **Où** : fenêtre d'écriture
  - **Étape** : taper `@` puis deux lettres d'un nom connu
  - **Attendu** : une liste de comptes apparaît ; en choisir un insère la
    mention. Une fois publié, le nom s'affiche à la place de la clé, et le
    toucher ouvre le profil.

- [ ] **Où** : au-dessus du bouton d'écriture
  - **Étape** : toucher *Ask Jeb*, poser une question, publier
  - **Attendu** : le post part avec la mention de Jeb, et sa réponse arrive
    dans le flux **Abonnements** quelques minutes plus tard. ⚠️ Non éprouvé
    de mon côté : je ne peux pas publier depuis ton compte.

- [ ] **Où** : Réglages
  - **Étape** : activer *Inclure mes posts dans Abonnements*, revenir au flux
  - **Attendu** : tes propres posts s'intercalent dans l'onglet Abonnements.

- [ ] **Où** : Réglages → notifications
  - **Étape** : activer le rappel toutes les 15 minutes, verrouiller l'écran
  - **Attendu** : une notification locale arrive s'il y a du nouveau.
    ⚠️ Android peut retarder fortement une tâche périodique quand l'appareil
    économise la batterie — un retard n'est pas une panne.

### build: distribution par Obtainium — v0.8.0 — 2026-09-07

Release : https://github.com/PastaGringo/flutky/releases/tag/v0.8.0
`fr.delvops.flutky` · versionCode **8** · signé `CN=Flutky, OU=Delvops`
MD5 `c4a8b3e5db5d53bd3eee06e350dd0798`.

**⚠️ Désinstaller l'app avant cette version.** Elle passe de la clé de débogage
à un keystore de release : Android refuse une mise à jour dont la signature
diffère. C'est la dernière fois — les suivantes se mettront à jour toutes
seules. La session Pubky sera à refaire une fois via Ring.

- [ ] **Où** : GitHub → Settings → Developer settings → Fine-grained tokens
  - **Étape** : générer un jeton, *Only select repositories* → `flutky`,
    *Repository permissions* → **Contents : Read-only**
  - **Attendu** : le jeton s'affiche une seule fois — le copier tout de suite.

- [ ] **Où** : Obtainium → ☰ Settings → Source-specific → GitHub
  - **Étape** : coller le jeton dans *Personal Access Token*
  - **Attendu** : rien de visible, mais sans lui l'étape suivante rendra
    « aucune release » — un dépôt privé répond 404 à un appel anonyme, ce qui
    ne ressemble pas à un refus d'accès.

- [ ] **Où** : Obtainium → onglet *Add App*
  - **Étape** : saisir `https://github.com/PastaGringo/flutky`, puis *Add*
  - **Attendu** : Obtainium trouve **v0.8.0** et propose de l'installer.

- [ ] **Où** : Obtainium, après une future publication
  - **Étape** : rafraîchir la liste
  - **Attendu** : la nouvelle version est détectée et s'installe **sans
    désinstallation** — c'est ce qui valide la stabilité de la signature.

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
