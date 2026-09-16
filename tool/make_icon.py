#!/usr/bin/env python3
"""Dessine l'icone de Flutky, et les deux fichiers que le generateur attend.

    python tool/make_icon.py
    dart run flutter_launcher_icons

Pourquoi un script plutot qu'un PNG pose la : l'icone se re-derive. Changer
l'epaisseur du corps ou l'inclinaison est une ligne, et la version suivante
reste identique a la precedente au pixel pres partout ou on n'a pas touche.

Deux defauts mesures sur l'icone d'origine, et corriges ici.

**Elle etait trop maigre pour sa taille d'usage.** Corps a 11,5 % de la
largeur, trous a 19 % de cette epaisseur : a 48 px cela fait un trait de 5,5 px
et des trous de 1 px. Les trous disparaissent, il ne reste qu'une bavure
diagonale. Ici le corps fait 18,5 % et les trous 25 % de l'epaisseur.

**Elle etait minuscule dans le lanceur.** L'avant-plan n'occupait que 47 % de
sa toile, et `ic_launcher.xml` lui applique encore un retrait de 16 % : la
flute finissait a environ un tiers de l'icone. Android veut que le sujet
remplisse le cercle de securite, 61 % du cadre. Le dessin ci-dessous occupe
environ 82 % de sa toile, ce qui retombe dessus une fois le retrait applique.

Les trous sont **transparents** et non peints en couleur de fond : c'est
l'arriere-plan de l'icone adaptative qui doit apparaitre au travers, quoi
qu'il devienne.
"""

import os

from PIL import Image, ImageDraw

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(RACINE, "assets", "icon")

S = 1024
K = 4                      # surechantillonnage : PIL ne lisse pas les formes
N = S * K

FOND = (5, 7, 10, 255)     # kBackground #05070A
VERT = (59, 231, 182, 255)  # kAccent    #3BE7B6
VIDE = (0, 0, 0, 0)

ANGLE = -38                # la diagonale remplit le cadre carre
# 66 dp de cercle de securite sur 108 dp de toile, dont le retrait de
# ic_launcher.xml garde 68 % : la flute ne peut pas depasser 66/(0,68*108),
# soit 0,90 du cote. On s'arrete un peu en dessous.
LONGUEUR = 0.87
EPAISSEUR = 0.179

# On dessine sur une toile plus large que la finale, puis on recadre au centre.
# Sans cela un corps plus long que la toile serait rogne AVANT la rotation, et
# le rognage ne se verrait pas : la flute sortirait simplement a bouts carres.
MARGE = 1.35
W = int(N * MARGE)


def flute():
    """Le corps seul, sur fond transparent, trous perces."""
    calque = Image.new("RGBA", (W, W), VIDE)
    d = ImageDraw.Draw(calque)
    cx = cy = W / 2
    long_, e = N * LONGUEUR, N * EPAISSEUR
    x0 = cx - long_ / 2

    # le tube
    d.rounded_rectangle([x0, cy - e / 2, x0 + long_, cy + e / 2],
                        radius=e / 2, fill=VERT)
    # le pavillon, legerement evase
    ep = e * 1.26
    d.rounded_rectangle([x0 + long_ - e * 1.2, cy - ep / 2, x0 + long_,
                         cy + ep / 2], radius=ep * 0.34, fill=VERT)
    # la plaque de bouche, en saillie au-dessus du tube : c'est elle qui fait
    # lire une traversiere plutot qu'un tuyau perce
    px = x0 + long_ * 0.145
    pw, ph = e * 1.7, e * 0.72
    d.rounded_rectangle([px - pw / 2, cy - e / 2 - ph * 0.78, px + pw / 2,
                         cy + e * 0.08], radius=ph * 0.5, fill=VERT)

    # le trou d'embouchure, ovale, dans la plaque. ImageDraw ecrase les pixels
    # au lieu de les composer : peindre en (0,0,0,0) perce donc vraiment.
    rw, rh = e * 0.38, e * 0.27
    d.ellipse([px - rw, cy - e * 0.38 - rh, px + rw, cy - e * 0.38 + rh],
              fill=VIDE)
    # les trous de doigts
    r = e * 0.25
    for t in (0.455, 0.60, 0.745, 0.875):
        hx = x0 + long_ * t
        d.ellipse([hx - r, cy - r, hx + r, cy + r], fill=VIDE)

    calque = calque.rotate(ANGLE, resample=Image.BICUBIC, center=(cx, cy))
    m = (W - N) // 2
    return calque.crop((m, m, m + N, m + N))


def main():
    corps = flute()

    avant_plan = corps.resize((S, S), Image.LANCZOS)
    avant_plan.save(os.path.join(DEST, "icon_foreground.png"))

    complete = Image.new("RGBA", (N, N), FOND)
    complete.alpha_composite(corps)
    complete.resize((S, S), Image.LANCZOS).save(
        os.path.join(DEST, "icon.png"))

    bb = avant_plan.getbbox()
    print("icon.png et icon_foreground.png ecrits dans assets/icon/")
    print("boite englobante : %.0f %% x %.0f %% de la toile"
          % (100 * (bb[2] - bb[0]) / S, 100 * (bb[3] - bb[1]) / S))
    # ⚠️ Ce n'est PAS la largeur de la boite qu'il faut comparer au cercle de
    # securite. Pour un objet en diagonale, ses extremites sont aux COINS de la
    # boite : une boite de 64 dp de large a une diagonale de 90 dp, et la flute
    # sortait du cercle par les deux bouts. Le chiffre qui compte est la
    # longueur de l'instrument lui-meme.
    longueur_dp = LONGUEUR * 0.68 * 108
    print("longueur de la flute : %.0f dp, cercle de securite : 66 dp"
          % longueur_dp)
    if longueur_dp > 66:
        print("  ATTENTION : les bouts seront coupes par le masque.")


if __name__ == "__main__":
    main()
