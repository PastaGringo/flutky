# Publier une version

Flutky se met à jour par **Obtainium**, qui lit les *releases* du dépôt GitHub.
Le dépôt reste **privé** : Obtainium envoie `Authorization: Token …` sur ses
appels d'API et `Accept: application/octet-stream` pour télécharger l'APK, et
il préfère l'URL d'API de l'asset à `browser_download_url` — c'est exactement
ce qu'exige un dépôt privé.

## Configurer Obtainium, une seule fois

1. **Créer un jeton GitHub** — [Fine-grained
   tokens](https://github.com/settings/personal-access-tokens) :
   - *Repository access* → **Only select repositories** → `flutky`
   - *Repository permissions* → **Contents : Read-only** (c'est ce qui donne
     accès aux releases et à leurs fichiers)
   - une date d'expiration, et le noter : GitHub ne le réaffichera pas
2. **Le coller dans Obtainium** : ☰ → *Settings* → *Source-specific* →
   *GitHub* → *Personal Access Token*
3. **Ajouter l'app** : onglet *Add App* → URL du dépôt →
   `https://github.com/PastaGringo/flutky` → *Add*

Sans le jeton, Obtainium ne verra rien : un dépôt privé répond 404 à un appel
anonyme, ce qui ressemble à « aucune release » plutôt qu'à un refus d'accès.

## La signature ne doit jamais changer

Android refuse d'installer une mise à jour dont la signature diffère de celle
de l'app installée. Le keystore de Flutky est donc unique et permanent :

| | |
|---|---|
| Fichier | `~/.android/keystores/flutky-release.jks` — **hors du dépôt** |
| Alias | `flutky` |
| Clé | RSA 4096, valable 10 000 jours |
| Mot de passe | Infisical, projet `flutky`, environnement `prod` |

`android/key.properties` porte les mots de passe sur la machine de build ; il
est ignoré par git, comme `*.jks`. Un clone sans ces fichiers **compile quand
même** — le build retombe sur la clé de débogage — mais l'APK produit ne peut
pas servir de mise à jour.

⚠️ **Sauvegarder le fichier `.jks` ailleurs que sur la machine de build.** Le
perdre oblige chaque utilisateur à désinstaller puis réinstaller l'app, en
perdant sa session.

## Publier

```bash
# 1. incrémenter la version dans pubspec.yaml — versionName+versionCode
#    Android ignore une réinstallation dont le versionCode n'a pas bougé.
# 2. vérifier, puis construire
flutter analyze && flutter test
flutter build apk --release

# 3. confirmer que le binaire est neuf ET signé avec la bonne clé
md5sum build/app/outputs/flutter-apk/app-release.apk
"$ANDROID_HOME/build-tools/37.0.0/apksigner" verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk

# 4. publier
VERSION=$(grep '^version:' pubspec.yaml | cut -d' ' -f2 | cut -d+ -f1)
cp build/app/outputs/flutter-apk/app-release.apk "flutky-$VERSION.apk"
gh release create "v$VERSION" "flutky-$VERSION.apk" \
  --title "v$VERSION" --notes "…"
rm "flutky-$VERSION.apk"
```

**Le contrôle de l'étape 3 n'est pas décoratif.** Un build qui échoue laisse en
place l'APK précédent, avec une date et une taille plausibles : sans comparer
l'empreinte, on publie l'ancien binaire en croyant publier le nouveau. Et le
certificat doit afficher `CN=Flutky`, jamais `CN=Android Debug`.

## Vérifier ce qu'Obtainium voit

```bash
gh release list --limit 5
gh release view v0.8.0 --json assets --jq '.assets[].name'
```

Obtainium retient le premier asset dont le nom ressemble à un APK. Un seul
`.apk` par release évite d'avoir à régler un filtre de son côté.
