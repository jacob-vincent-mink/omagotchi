# Omagotchi — Roadmap & design de référence

Document de travail (fr). Les chiffres « actuels » sont extraits du code au
2026-08-20. Deadline concours : **lundi 24/08, 9h CEST**.

---

## 1. Stades d'évolution — état actuel

L'âge compte les **minutes de shell actif** (machine éteinte = pause).
Le « soin » = moyenne du bonheur échantillonné chaque minute, **remis à zéro à
chaque évolution**.

| Stade | Forme(s) | Évolue à (âge total) | Durée du stade | Condition de branche |
| --- | --- | --- | --- | --- |
| Œuf | `egg` | 5 min | 5 min | — |
| Bébé | `baby` | 70 min | 65 min | — |
| Enfant | `child` | 550 min | 480 min (8 h) | soin ≥ 55 → ado propre, sinon ado crado |
| Ado | `teen_neat` / `teen_scruffy` | 1510 min | 960 min (16 h) | voir tableau adultes |
| Adulte | `adult_ace` / `adult_ok` / `adult_gremlin` | — | ∞ | — |

Branches adulte (hommage au chart Gen1 : l'ado crado plafonne un cran plus bas) :

| Soin moyen de l'ado | Depuis ado propre | Depuis ado crado |
| --- | --- | --- |
| ≥ 75 | `adult_ace` | `adult_ok` |
| ≥ 40 | `adult_ok` | `adult_gremlin` |
| < 40 | `adult_gremlin` | `adult_gremlin` |

**Plus tard (post-concours ?)** : arbre complet façon chart Gen1
(`~/PROJECTS/omagotchiPlugin/P1 GC 2.png`) — plus de formes adultes + un
« special » caché. Bloqué par : sprites supplémentaires.

---

## 2. Besoins — état actuel

Tous montent de 0 (bien) à 100 (critique) par tick de minute active. Le pet
se plaint (humeur + gigote dans la barre) à partir de **60**.

| Besoin | Vitesse actuelle | 0 → 100 | Modulateurs actuels | Se soigne par |
| --- | --- | --- | --- | --- |
| Faim | +0,33/min | ~5 h 03 | updates en attente → +0,5/min (~3 h 20) | bouton Feed |
| Hygiène | +0,21/min | ~7 h 56 | orphelins pacman → +0,33/min (~5 h 03) | bouton Clean |
| Énergie (fatigue) | +0,28/min éveillé | ~6 h (s'endort à 90, soit ~5 h 21) | balade → +0,55/min (dodo après ~2 h 44) | sieste auto : −2,2/min, réveil à ≤ 5 (~39 min) |
| Fun (ennui) | +0,45/min | ~3 h 42 | balade → **−2/min** | sortir se balader |
| Affection | +100 en **24 h temps réel** (pas minutes actives) | 24 h | caresse → reset + ennui −10 | cliquer le pet |

## 3. Besoins — ajustements par stade (À VALIDER ensemble)

Idée : un multiplicateur par stade et par besoin. Proposition de départ :

| Stade | Faim | Fatigue | Ennui | Comportement |
| --- | --- | --- | --- | --- |
| Bébé | ×1,5 (~3 h 20) | **×2** (sieste ~toutes les 2 h 40) | ×0,5 (pas de balade de toute façon) | dort tout le temps, mange souvent |
| Enfant | ×1 | ×1 | **×1,5** (~2 h 30) | déborde d'énergie, veut sortir |
| Ado | **×2** (~2 h 30) | ×0,8 | **×0,5** (~7 h 20) | dévore le frigo, casanier |
| Adulte | ×1 | ×1 | ×1 | référence |

- **Ado + panel** : quand l'ado est dans son panel (pas en balade), il sort un
  petit laptop (sprite simplifié, 2 frames) au lieu de l'idle classique.
- Question ouverte : l'ennui de l'ado devrait-il monter *plus vite* s'il ne
  touche pas à son laptop ? (gag possible, à voir)

## 4. Nouvelles mécaniques décidées

- **Sonné après une grande chute** : si la hauteur de chute dépasse un seuil
  (proposition : > 40 % de la hauteur d'écran), état `stunned` pendant
  ~3 s à l'atterrissage (sprite étoiles), insensible aux clics pendant ce temps.
- **Effets sonores (optionnels)** : petit set 8-bit (éclosion, évolution,
  miam, splash du bain, bâillement/dodo, cui-cui de caresse, « boing » de
  chute sonnée). Réglage on/off dans le panel, format WAV court dans
  `sounds/` (comme le tomato-timer). Je peux générer des bleeps chiptune
  de placeholder par script en attendant de meilleurs sons.
- **Moteur d'animations avec fallback** (côté code, prérequis à tout le
  reste) : chaque état/action tente `<form>_<anim>_*.png` et retombe sur
  l'idle de la forme si le fichier n'existe pas → les sprites peuvent être
  livrés au fil de l'eau sans jamais rien casser.
- **Bulles d'émotion partagées** (raccourci malin) : 6 petites bulles
  au-dessus de la tête (`emote_hungry`, `emote_sleepy`, `emote_dirty`,
  `emote_bored`, `emote_sad`, `emote_stun`), communes à TOUTES les formes.
  Elles rendent chaque état lisible immédiatement, même avant que les
  sprites d'état dédiés existent. À dessiner une seule fois.

---

## 5. Sprites — la liste de courses

Format : 16×16, blanc sur transparent (PNG32), nommage
`<form>_<anim>_<frame>.png`, frames `a`/`b`. Grilles texte dans
`tools/sprites/*.txt` + `tools/gen-sprites.sh`, ou export direct PNG depuis
Pixelorama — les deux marchent.

Formes : `egg`, `baby`, `child`, `teen_neat`, `teen_scruffy`, `adult_ace`,
`adult_ok`, `adult_gremlin`.

### P1 — la base redessinée (remplace mes drafts)

| Anim | Formes concernées | Frames | Total |
| --- | --- | --- | --- |
| `idle` | toutes (8) | a, b | 16 |
| `walk` | toutes sauf egg, baby (6) | a, b | 12 |
| `sleep` | toutes sauf egg (7) | a, b | 14 |

### P1,5 — les bulles partagées (gros gain, petit effort)

| Sprite | Note |
| --- | --- |
| `emote_hungry`, `emote_sleepy`, `emote_dirty`, `emote_bored`, `emote_sad`, `emote_stun` | 6 sprites uniques, taille libre (8×8 ou 16×16), affichés au-dessus de la tête |

### P2 — les animations dédiées (par ordre d'apparition à l'écran)

Priorité aux formes qu'on voit longtemps : `child`, les 2 `teen_*`, puis les
3 adultes. (Bébé passe vite, œuf n'a besoin de rien.)

| Anim | Usage | Frames |
| --- | --- | --- |
| `climb` | remplace la rotation −90° actuelle | a, b |
| `eat` | pendant le Feed | a, b |
| `wash` | pendant le Clean | a, b |
| `hungry` / `dirty` / `bored` / `sad` / `sleepy` | idle d'état (si tu veux plus que la bulle) | a, b chacun |
| `stunned` | après une grande chute | a, b |
| `laptop` | **teens uniquement**, idle dans le panel | a, b |

### P3 — plus tard

- Formes supplémentaires pour l'arbre Gen1 complet + le « special ».
- Frames de chute dédiées, animation d'éclosion, contour sombre 1 px
  (lisibilité sur fonds clairs).

---

## 6. Ordre de bataille (d'ici lundi 9h)

| # | Quoi | Qui |
| --- | --- | --- |
| 1 | Moteur d'anims avec fallback + bulles d'émotion | Claude |
| 2 | Multiplicateurs de besoins par stade (tableau §3 à valider avant) | Claude |
| 3 | État sonné après grande chute | Claude |
| 4 | Sons optionnels (setting + placeholders générés) | Claude |
| 5 | Sprites P1 (idle/walk/sleep des 8 formes) | **Stella** |
| 6 | Bulles P1,5 | **Stella** |
| 7 | Laptop de l'ado dans le panel | Claude (dès sprites teen) |
| 8 | Sprites P2 au fil de l'eau | **Stella** |
| 9 | GIF de démo (escalade + grab) + preview.png + README final | ensemble |
| 10 | Repo GitHub public, `omarchy plugin validate`, scan sécurité, soumission | ensemble |

Règle de survie : à partir de samedi, on gèle les mécaniques et on ne fait
plus que sprites + démo + soumission.

## 7. Post-concours (backlog)

- Arbre d'évolution Gen1 complet (+ special caché)
- Multi-écran (le pet suit l'écran focus ? un pet par écran ?)
- Support scale ≠ 1 (coords Hyprland vs surface)
- Se cacher quand une fenêtre passe fullscreen
- Mini-jeu de discipline ? (le chart Gen1 a une jauge discipline)
