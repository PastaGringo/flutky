# Flutky

Preuve de concept Flutter : se connecter à un compte **Pubky** en passant par
**Pubky Ring**, puis afficher son profil.

Elle répond à une seule question : *une application Flutter peut-elle ouvrir
Pubky Ring, obtenir une session, et afficher les informations du compte ?*

## Installer et mettre à jour

**Android uniquement** — pas de build iOS.

Pour installer et tester : **[INSTALL.md](INSTALL.md)** *(in English)*. Les
mises à jour passent par [Obtainium](https://github.com/ImranR98/Obtainium),
qui lit les *releases* de ce dépôt. Côté publication, le keystore et la
procédure sont dans [RELEASING.md](RELEASING.md).

## Ce qu'elle fait — et ne fait pas

| | |
|---|---|
| ✅ | Ouvre Pubky Ring par un lien `pubkyring://session` |
| ✅ | Reçoit en retour la clé publique et un secret de session |
| ✅ | Garde la session dans le keystore — un seul passage par Ring |
| ✅ | Lit le profil (avatar, nom, statut, bio, liens, compteurs, tags) |
| ✅ | Lit le flux : abonnements, amis, global, favoris — avec images |
| ✅ | Rend les mentions cliquables et ouvre le profil de la personne citée |
| ✅ | Publie un post court sur le homeserver |
| ✅ | Embarque une page de diagnostic pour l'authentification |
| ❌ | Pas encore : suivre, taguer, répondre, envoyer une image |

**Aucune ligne de Rust**, y compris pour écrire. La lecture passe par Nexus,
l'indexeur public derrière pubky.app, dont l'API v0 ne demande aucune
authentification. L'écriture s'authentifie soit par cookie, soit — pour une
session *grant* — en signant une preuve de possession Ed25519 et en
l'échangeant contre un jeton porteur, ce que fait `lib/pubky/grant_auth.dart`.

## Le flux, tel qu'il est implémenté dans Ring

Décrit en tête de `src/utils/actions/sessionAction.ts` du dépôt `pubky-ring`,
et publié dans la version **1.19** (2026-09-04) :

```
1. Flutky ouvre  pubkyring://session?x-success=flutky://session&x-error=…&x-cancel=…&x-source=Flutky
2. Ring demande quel pubky utiliser
3. Ring affiche un écran d'approbation
4. Ring rouvre  flutky://session?pubky=…&grant_secret=…&capabilities=…
```

⚠️ **Le nom du secret dépend de la version de Ring** : `session_secret`
jusqu'à la 1.18, `grant_secret` depuis la 1.19 (commit `4f2798a` du
2026-09-03). Flutky accepte les deux, et se fie à la présence de la charge
utile plutôt qu'à l'hôte du lien de retour — plusieurs gestionnaires de Ring
rappellent l'URL de succès sans y ajouter le moindre paramètre.

Ring déclare les schémas `pubkyring` et `pubkyauth` sur Android comme sur iOS ;
Flutky déclare `flutky`. Le retour se fait donc d'application à application,
sans relais HTTP ni scrutation.

## Sécurité

Le secret de session vaut mot de passe : qui le détient agit comme
l'utilisateur. Il est gardé dans le **keystore de la plateforme**, n'est jamais
affiché, journalisé, ni inclus dans le rapport de diagnostic — celui-ci n'en
donne que la longueur, la forme et le nombre de segments.

⚠️ **Le secret exporté n'est pas la valeur du cookie.** `export_secret()` du
SDK rend `<clé>:<secret>` ; envoyer la chaîne entière donne
`No authenticated session found`, qui ressemble à s'y méprendre à une session
expirée. Voir `lib/pubky/cookie_auth.dart`.

À savoir : Ring signe la session avec **son propre** identifiant applicatif.
Côté homeserver, la session est donc indiscernable de celle de Ring et ne peut
pas être révoquée séparément.

## Structure

```
lib/
  main.dart                    machine à états : restauration, attente, app
  theme.dart                   palette et blocs partagés
  pubky/ring_session.dart      construction du lien et lecture du callback
  pubky/session_store.dart     session dans le keystore de la plateforme
  pubky/nexus.dart             client Nexus + modèles profil et post
  pubky/cookie_auth.dart       découpage du secret exporté
  pubky/grant_auth.dart        preuve de possession et échange de jeton
  pubky/crockford.dart         identifiants horodatés des ressources
  pubky/mentions.dart          découpage du contenu : texte, mentions, liens
  pubky/homeserver.dart        écriture sur le homeserver
  pubky/diagnostics.dart       sondes d'authentification
  screens/home_shell.dart      onglets Flux / Profil
  screens/                     connexion, flux, profil, composition, diagnostic
test/                          67 tests — hors ligne et contre le réseau réel
  fixtures/                    réponses réelles de Nexus, non retouchées
```

### Points mesurés sur l'API de flux

- `limit` est borné à 50 (`BoundedLimit_10_50`), `skip` pagine.
- `observer_id` est ce qui personnalise : sans lui, `following` retombe
  silencieusement sur la chronologie globale. Un test réseau vérifie que deux
  observateurs obtiennent bien deux flux différents.
- Les sources exposées (`following`, `friends`, `all`, `bookmarks`) sont celles
  qui répondent avec un simple observateur ; `author` et `post_replies` exigent
  des identifiants supplémentaires et rendent 400.
- Une pièce jointe `pubky://<auteur>/pub/pubky.app/files/<id>` se lit à
  `/static/files/<auteur>/<id>/<variante>`, avec trois variantes seulement :
  `main` (149 ko JPEG mesurés), `feed` (7,7 ko WebP) et `small` (2,9 ko). Tout
  autre nom rend 400.

## Développer

```bash
flutter pub get
flutter analyze
flutter test test/pubky_test.dart      # hors ligne, déterministe
flutter test test/network_test.dart    # touche le réseau réel
flutter build apk --release
```

L'APK est signé avec la clé de release quand `android/key.properties` et le
keystore sont présents, et retombe sur la clé de débogage sinon — voir
[RELEASING.md](RELEASING.md).

## Prérequis pour l'essayer

**Pubky Ring ≥ 1.19** installé sur le même téléphone, avec au moins un pubky
enregistré. Une version antérieure ne répond pas au lien `pubkyring://session`.

Un compte que Nexus n'a jamais indexé n'a pas de profil à afficher : l'indexeur
n'apprend l'existence d'une clé qu'une fois celle-ci reliée au graphe social.
L'application le dit explicitement plutôt que d'afficher une erreur brute, et
demande son indexation au passage.

## Points mesurés

- `GET /v0/user/{id}` sur `nexus.pubky.app` : profil complet, sans jeton.
- `GET /static/avatar/{id}` : `200 image/webp`, contre `404` pour une clé
  inconnue — l'avatar n'a pas besoin d'être résolu depuis son URI `pubky://`.
- Nexus publie un OpenAPI 3.1 (`nexus-webapi 0.4.1`) : 43 points d'entrée,
  81 schémas.

---

Réalisé par [Delvops](https://delvops.fr).
