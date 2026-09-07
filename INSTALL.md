# Installing Flutky

**Android only.** There is no iOS build — the project is developed on Windows,
and building for iOS requires macOS.

Flutky is a proof of concept, not a finished app. It signs you in with your
real Pubky account and can publish real posts to your homeserver. Read
[What it does](#what-it-does) before connecting an account you care about.

## Requirements

| | |
|---|---|
| Android | 7.0 or later (API 24) |
| [Pubky Ring](https://play.google.com/store/apps/details?id=to.pubky.ring) | installed, with at least one pubky in it |
| A Pubky account | already known to the network — see [Nothing in the feed](#nothing-in-the-feed) |

Pubky Ring holds your keys and approves the connection. Flutky never sees your
recovery phrase or private key.

## Install with Obtainium

[Obtainium](https://github.com/ImranR98/Obtainium) installs apps straight from
their source and keeps them updated. Flutky publishes each version as a GitHub
release, so Obtainium picks up new ones on its own.

1. Install Obtainium, if you have not already.
2. Open it and go to the **Add App** tab.
3. Paste this URL:

   ```
   https://github.com/PastaGringo/flutky
   ```

4. Tap **Add**, then **Install**. Android will ask you to allow installation
   from an unknown source — Obtainium, in this case.

Updates then show up in Obtainium's **Apps** tab. No token or account is
needed: the repository is public.

### Verifying what you install

Flutky is signed with a key that will not change. If you want to check that an
APK really comes from this project:

```
Certificate DN:     CN=Flutky, OU=pastalabs.dev, O=pastalabs.dev, C=FR
SHA-256 digest:     7422979ad28b3f5b7d4bc840cd1a9c59231ba3911cb529a10e777feca2ca0d2a
```

Android enforces this for you on every update: an APK signed with a different
key is rejected outright, so a tampered build cannot silently replace the app.

## First run

1. Open Flutky and tap **Se connecter avec Pubky Ring**.
   *(The interface is in French for now.)*
2. Pubky Ring comes to the front. Pick the pubky you want to use, check that
   the requesting app is shown as **Flutky**, and approve.
3. Ring sends you back to Flutky automatically. Your profile loads.

Nothing is typed, copied or pasted — the two apps talk over Android deep links.

## What it does

| | |
|---|---|
| ✅ | Signs in through Pubky Ring, keeping the session in the Android keystore |
| ✅ | Shows your profile: avatar, name, status, bio, links, counters, tags |
| ✅ | Shows the feed: following, friends, global, bookmarks — with images |
| ✅ | Renders `@mentions`, tap one to open that person's profile |
| ✅ | **Discover**: popular posts, the labels in use, accounts to follow |
| ✅ | Translates a draft before you post it, with your own DeepL key |
| ✅ | Publishes short posts to your homeserver |
| ❌ | Cannot yet follow, tag, reply, or attach an image |
| ❌ | Cannot delete a post from the interface |

**Posts are real.** Anything you publish lands on your homeserver and shows up
on [pubky.app](https://pubky.app) once the indexer catches up — usually within
seconds. There is no draft mode and no undo.

## Privacy and what the app holds

The session secret Ring hands over is **bearer-equivalent**: whoever holds it
can act as you, within the granted capabilities. Flutky keeps it in the Android
keystore, never displays it, never logs it, and never includes it in the
built-in diagnostics report — that report shows only its length and shape.

Signing out deletes it from the device.

The app talks to two servers and nothing else: `nexus.pubky.app` for reading
and `homeserver.pubky.app` for writing. No analytics, no crash reporting, no
third party.

⚠️ Ring signs the session with **its own** application id. On the homeserver
side, Flutky's session is indistinguishable from Ring's and cannot be revoked
separately.

## Troubleshooting

### Ring does not open

Tap the small link below the button to try the alternative URL form. If nothing
happens at all, Pubky Ring is probably not installed — Flutky says so instead
of failing silently.

### Ring comes back but nothing loads

The exchange succeeded but carried no session. The screen shows the exact link
sent and received; tap the copy icon and include it in a bug report — it
contains the diagnosis.

### Nothing in the feed

The **Abonnements** (following) tab only shows accounts you follow. Try
**Global**. If your profile itself is empty, the indexer has probably never
seen your key: it only learns about an account once it is wired into the social
graph. Post something or follow someone from pubky.app, then reload.

### Publishing fails

Open the **diagnostics** page — the microscope icon at the top. It runs eight
probes side by side, two of which use no authentication at all and must
succeed. Copy the report with the icon in the corner and attach it to a bug
report. It never contains your secret.

### An update refuses to install

That means the signature differs from the installed app. Do not force it —
report it instead. A legitimate update always keeps the same key.

## Reporting a problem

Open an issue at
[github.com/PastaGringo/flutky/issues](https://github.com/PastaGringo/flutky/issues)
with the app version (from Obtainium), your Android version, and the
diagnostics report if the problem touches sign-in or publishing.
