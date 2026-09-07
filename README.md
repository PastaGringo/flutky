# Flutky

Preuve de concept Flutter : se connecter à un compte **Pubky** en passant par
**Pubky Ring**, puis afficher son profil.

Elle répond à une seule question : *une application Flutter peut-elle ouvrir
Pubky Ring, obtenir une session, et afficher les informations du compte ?*

## Ce qu'elle fait — et ne fait pas

| | |
|---|---|
| ✅ | Ouvre Pubky Ring par un lien `pubkyring://session` |
| ✅ | Reçoit en retour la clé publique et un secret de session |
| ✅ | Garde la session dans le keystore — un seul passage par Ring |
| ✅ | Lit le profil (avatar, nom, statut, bio, liens, compteurs, tags) |
| ✅ | Lit le flux : abonnements, amis, global, favoris — avec images |
| ❌ | N'écrit rien — pas de publication, pas de suivi, pas de tag |

**Aucune ligne de Rust.** La lecture passe par Nexus, l'indexeur public
derrière pubky.app, dont l'API v0 ne demande aucune authentification. Écrire,
en revanche, exigerait un pont FFI vers le crate `pubky` : le `grant_secret`
rendu par Ring n'est pas un jeton `Bearer` utilisable tel quel, il doit être
échangé contre un jeton court via une preuve de possession signée.

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

Le `grant_secret` est un **jeton porteur** : qui le détient agit comme
l'utilisateur. Cette preuve de concept le garde **en mémoire seulement**, ne
l'affiche jamais, ne le journalise pas, et le perd à la fermeture. Une vraie
application le placerait dans le keystore Android ou la Keychain iOS.

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
  screens/home_shell.dart      onglets Flux / Profil
  screens/                     connexion, flux, profil
test/
  pubky_test.dart              hors ligne — callback Ring et profil
  feed_test.dart               hors ligne — flux, pièces jointes, keystore
  network_test.dart            en ligne — contre nexus.pubky.app
  fixtures/                    réponses réelles de Nexus
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

L'APK est signé avec la clé de débogage : il s'installe directement, il n'est
pas publiable en l'état.

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
