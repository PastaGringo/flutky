#!/usr/bin/env python3
"""Rejoue contre le mypubky en ligne les hypotheses sur lesquelles Flutky ecrit.

Flutky edite un fichier appartenant a une autre application, dont le format
n'est ecrit nulle part : il a ete releve sur des cartes reelles et dans le
bundle du site. Si mypubky.com change, rien dans Flutky ne le signalerait --
il continuerait a ecrire l'ancienne forme, et la carte publique s'afficherait
mal sans que personne ne le sache.

Cette sonde tourne toutes les semaines et transforme ce silence en alerte.

    python tool/mypubky_canary.py            # rend 0 si tout tient, 1 sinon
    python tool/mypubky_canary.py --selftest # prouve que la sonde sait echouer

Aucune dependance hors bibliotheque standard : elle doit tourner sans SDK.
"""

import argparse
import json
import re
import sys
import urllib.error
import urllib.request

SITE = "https://mypubky.com"
HOMESERVER = "https://homeserver.pubky.app"
CARD_PATH = "/pub/mypubky.com/card.json"

# Un agent explicite : plusieurs services refusent celui d'urllib par defaut,
# et un refus ressemble alors a une panne du service lui-meme.
AGENT = "flutky-canary/1 (+https://github.com/PastaGringo/flutky)"

# Des cartes reelles relevees sur le reseau. Elles servent de temoins : si
# TOUTES disparaissent, c'est le chemin du fichier qui a bouge, pas cinq
# personnes qui ont efface leur carte le meme jour.
KNOWN_CARDS = [
    "operrr8wsbpr3ue9d4qj41ge1kcc6r7fdiy6o3ugjrrhi4y77rdo",
    "b8pf41opxrtgwjox7a49u6d677snmutyukzdy5wdueet5sne4q8o",
    "c5nr657md9g8mut1xhjgf9h3cxaio3et9xyupo4fsgi5f7etocey",
    "owoickyrwfakar33zdpmwonswhkysxbmi7xntdqwrmt8mr4f64xo",
    "4snwyct86m383rsduhw5xgcxpw7c63j3pq8x4ycqikxgik8y64ro",
]

# Ce que Flutky sait lire et reecrire, releve sur ces memes cartes. Une cle en
# plus n'est pas une panne -- Flutky la repasse telle quelle -- mais elle
# signale que le format a bouge et merite un coup d'oeil.
KNOWN_KEYS = {
    "pubky",
    "backgroundId",
    "backgroundType",
    "backgroundUrl",
    "bitcoinAddress",
    "cardBackgroundMode",
    "cardPosition",
    "donateEnabled",
    "donateEndpoint",
    "extraLinks",
    "extraSocials",
    "showLatestPost",
    "showTags",
}

LINK_KEYS = {"title", "url", "mailto"}
SOCIAL_KEYS = {"key", "title", "url"}

BUILT_IN_BACKGROUNDS = ["back1", "back2", "back3"]

problems = []
notes = []


def fail(message):
    problems.append(message)


def note(message):
    notes.append(message)


def get(url, limit=4_000_000):
    request = urllib.request.Request(url, headers={"User-Agent": AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.status, dict(response.headers), response.read(limit)


def head(url):
    request = urllib.request.Request(
        url, headers={"User-Agent": AGENT}, method="HEAD"
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.status, dict(response.headers)


def check_cards():
    """Le fichier est-il toujours la, et toujours de la meme forme ?"""
    found = []
    for pubky in KNOWN_CARDS:
        url = "%s%s?pubky-host=%s" % (HOMESERVER, CARD_PATH, pubky)
        try:
            status, _, body = get(url)
        except urllib.error.HTTPError as error:
            if error.code != 404:
                note("carte %s... : HTTP %d" % (pubky[:8], error.code))
            continue
        except Exception as error:  # reseau, TLS, delai
            note("carte %s... : %s" % (pubky[:8], error))
            continue
        if status != 200:
            continue
        try:
            found.append((pubky, json.loads(body.decode("utf-8"))))
        except ValueError:
            fail("carte %s... : le contenu n'est plus du JSON" % pubky[:8])

    if not found:
        fail(
            "aucune des %d cartes temoins n'est servie a %s -- le chemin du "
            "fichier a probablement change" % (len(KNOWN_CARDS), CARD_PATH)
        )
        return

    note("%d cartes temoins sur %d toujours servies"
         % (len(found), len(KNOWN_CARDS)))

    seen = set()
    for pubky, card in found:
        if not isinstance(card, dict):
            fail("carte %s... : ce n'est plus un objet" % pubky[:8])
            continue
        seen |= set(card)

        for link in card.get("extraLinks") or []:
            extra = set(link) - LINK_KEYS
            if extra:
                fail("un lien porte des champs inconnus : %s"
                     % ", ".join(sorted(extra)))
        for social in card.get("extraSocials") or []:
            extra = set(social) - SOCIAL_KEYS
            if extra:
                fail("un compte social porte des champs inconnus : %s"
                     % ", ".join(sorted(extra)))

    added = seen - KNOWN_KEYS
    if added:
        fail("champs inconnus sur les cartes : %s -- Flutky les repasse tels "
             "quels, mais n'en cree aucun sur une carte neuve"
             % ", ".join(sorted(added)))

    # Une cle que Flutky ecrit et que plus personne ne porte : soit elle a ete
    # renommee, soit elle a disparu. Les deux valent un coup d'oeil.
    missing = KNOWN_KEYS - seen - {"backgroundUrl"}
    if missing:
        fail("champs absents de toutes les cartes : %s"
             % ", ".join(sorted(missing)))


def find_bundle():
    status, _, body = get(SITE + "/")
    if status != 200:
        fail("%s repond HTTP %d" % (SITE, status))
        return None
    match = re.search(r"/assets/[A-Za-z0-9._-]+\.js", body.decode("utf-8", "replace"))
    if not match:
        fail("aucun script trouve dans la page de %s -- le site a change de "
             "forme, la resolution des fonds est a revoir" % SITE)
        return None
    return match.group(0)


def check_backgrounds(bundle_path):
    """Les fonds livres sont-ils toujours nommes et servis de la meme facon ?

    Le controle porte sur le TYPE et la TAILLE, pas sur le code de statut :
    le site sert son index.html pour tout ce qu'il n'a pas, donc n'importe
    quel nom sous /assets/ repond 200.
    """
    status, _, body = get(SITE + bundle_path)
    if status != 200:
        fail("le bundle %s repond HTTP %d" % (bundle_path, status))
        return
    text = body.decode("utf-8", "replace")

    # Le temoin negatif, indispensable : un nom sans hachage NE DOIT PAS
    # passer le controle. Sans lui, un controle qui accepterait tout rendrait
    # exactement le meme resultat qu'un controle bien regle.
    decoy = "%s/assets/back1.png" % SITE
    try:
        _, decoy_headers = head(decoy)
        decoy_type = decoy_headers.get("Content-Type", "")
        decoy_length = int(decoy_headers.get("Content-Length") or 0)
        if decoy_type.startswith("image/") and decoy_length > 100_000:
            fail("temoin negatif casse : %s passe pour une image (%s, %d o). "
                 "Le controle ci-dessous ne prouve plus rien."
                 % (decoy, decoy_type, decoy_length))
        else:
            note("temoin negatif ok : back1.png rend %s, %d o"
                 % (decoy_type or "sans type", decoy_length))
    except Exception as error:
        note("temoin negatif injoignable : %s" % error)

    for name in BUILT_IN_BACKGROUNDS:
        match = re.search(
            r"assets/%s-[A-Za-z0-9_-]+\.(?:png|jpg|jpeg|webp)" % name, text
        )
        if not match:
            fail("fond %s : plus aucun fichier a ce nom dans le bundle -- "
                 "Flutky ne saura plus quelle URL ecrire" % name)
            continue
        url = "%s/%s" % (SITE, match.group(0))
        try:
            _, headers = head(url)
        except Exception as error:
            fail("fond %s : %s injoignable (%s)" % (name, url, error))
            continue
        media = headers.get("Content-Type", "")
        length = int(headers.get("Content-Length") or 0)
        if not media.startswith("image/") or length <= 100_000:
            fail("fond %s : %s ne rend pas une image (%s, %d o)"
                 % (name, url, media or "sans type", length))
        else:
            note("fond %s ok : %s, %d o" % (name, media, length))


def check_folder(bundle_path):
    """Le dossier que Flutky lit, et que son grant demande, est-il le bon ?

    Le chemin litteral n'apparait PAS dans le bundle : le site le construit
    par gabarit, /pub/${APP_NAME}/card.json, et APP_NAME est minifie. Un grep
    sur "/pub/mypubky.com/" rendait donc un faux positif -- il criait au
    changement alors que rien n'avait bouge. La variable est resolue a la
    place, ce qui mesure vraiment ce dont Flutky depend.
    """
    status, _, body = get(SITE + bundle_path)
    if status != 200:
        return
    text = body.decode("utf-8", "replace")

    template = re.search(r"/pub/\$\{([A-Za-z_$][\w$]*)\}/card\.json", text)
    if not template:
        fail("le bundle ne construit plus un chemin de la forme "
             "/pub/<app>/card.json -- le fichier a peut-etre bouge")
        return

    variable = re.escape(template.group(1))
    values = set(re.findall(r'\b%s\s*=\s*"([^"]{1,60})"' % variable, text))
    if not values:
        note("dossier : gabarit trouve, valeur de %s non resolue"
             % template.group(1))
        return

    expected = CARD_PATH.split("/")[2]   # mypubky.com
    if expected not in values:
        fail("le dossier du site vaut %s, Flutky ecrit dans %s -- le chemin "
             "et la capacite du grant sont a changer"
             % (", ".join(sorted(values)), expected))
    else:
        note("dossier : %s, conforme a ce que Flutky ecrit" % expected)


def run(label=""):
    """Un passage complet. Rend la liste des points releves."""
    global problems, notes
    problems, notes = [], []

    check_cards()
    bundle = find_bundle()
    if bundle:
        note("bundle : %s" % bundle)
        check_backgrounds(bundle)
        check_folder(bundle)

    if label:
        print("--- %s" % label)
    for line in notes:
        print("  -", line)
    if problems:
        print()
        for line in problems:
            print("  FAIL", line)
    print()
    return list(problems)


def selftest():
    """Prouve que chaque controle sait echouer, en lui donnant de fausses
    attentes -- et en DEUX passages, parce qu'un chemin casse arrete le
    premier controle avant que les suivants ne soient atteints. Un seul
    passage laisserait croire que tout discrimine alors qu'une partie n'aurait
    jamais tourne.
    """
    global KNOWN_KEYS, BUILT_IN_BACKGROUNDS, CARD_PATH

    print("AUTOTEST -- des echecs sont ATTENDUS ci-dessous.\n")
    missed = []

    # 1. le chemin du fichier a bouge, et un fond a disparu du bundle
    kept_path, kept_backgrounds = CARD_PATH, list(BUILT_IN_BACKGROUNDS)
    CARD_PATH = "/pub/mypubky.invalid/card.json"
    BUILT_IN_BACKGROUNDS = BUILT_IN_BACKGROUNDS + ["back9000"]
    caught = run("scenario 1 : chemin deplace, fond absent, dossier renomme")
    for wanted in ("cartes temoins", "back9000", "le dossier du site vaut"):
        if not any(wanted in line for line in caught):
            missed.append("scenario 1 : rien sur %r" % wanted)
    CARD_PATH, BUILT_IN_BACKGROUNDS = kept_path, kept_backgrounds

    # 2. le format de la carte a gagne un champ
    kept_keys = set(KNOWN_KEYS)
    KNOWN_KEYS = KNOWN_KEYS - {"showTags"}
    caught = run("scenario 2 : un champ inconnu sur les cartes")
    if not any("showTags" in line for line in caught):
        missed.append("scenario 2 : le champ inconnu n'a pas ete vu")
    KNOWN_KEYS = kept_keys

    if missed:
        print("AUTOTEST RATE -- la sonde est aveugle sur :")
        for line in missed:
            print("  FAIL", line)
        return 1
    print("AUTOTEST OK -- chaque controle a signale le changement fabrique.")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()

    if args.selftest:
        return selftest()

    found = run()
    if found:
        print("MYPUBKY A CHANGE -- %d point(s). Ce que Flutky ecrit dans %s "
              "repose sur ces constats : a revoir avant que la carte publique "
              "de quelqu'un ne s'affiche de travers." % (len(found), CARD_PATH))
        return 1

    print("Rien n'a bouge : Flutky ecrit toujours ce que mypubky sait lire.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
