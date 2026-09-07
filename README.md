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
| ✅ | Lit le profil (avatar, nom, statut, bio, liens, compteurs, tags) |
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
  main.dart                    machine à états : attente, chargement, profil
  theme.dart                   palette et blocs partagés
  pubky/ring_session.dart      construction du lien et lecture du callback
  pubky/nexus.dart             client Nexus + modèle de profil
  screens/                     écran de connexion, écran de profil
test/
  pubky_test.dart              hors ligne — parsing du callback et du profil
  network_test.dart            en ligne — contre nexus.pubky.app
  fixtures/nexus_user.json     réponse réelle de GET /v0/user/{id}
```

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
