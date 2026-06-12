# FERVEUR — Carbon Steel Cookware

*L'acier de tous les jours.*

A high-end luxury brand website for **Ferveur**, a (fictional) maison of
Paris-designed, hand-forged carbon steel cookware. Built as a static site —
no build step, no dependencies. Open `index.html` in a browser.

## Pages
- `index.html` — Home: hero, brand intro, features, featured collection, craft story, newsletter
- `collection.html` — Full product range with pricing ($115–$295)
- `about.html` — Brand story, atelier, history timeline & care ritual

## Structure
```
index.html
collection.html
about.html
assets/
  css/style.css   — design system (navy + cream + brass, French tricolor accents)
  js/main.js      — sticky nav, scroll reveal, mobile menu, demo cart + newsletter
  img/            — brand photography
```

## The Collection
| Piece | Size | Price |
|---|---|---|
| The 8″ Skillet | Poêle · 20 cm | $115 |
| The 10″ Skillet | Poêle · 25 cm | $145 |
| The 12.5″ Skillet | Poêle · 31.75 cm | $185 |
| The 14″ Skillet | Poêle · 35 cm | $215 |
| The Crêpière | 28 cm | $135 |
| The French Wok | Wok à bord évasé | $245 |
| The Roasting Pan | Rectangulaire · 35 cm | $265 |
| The Griddle Set | Plancha · 6 pièces | $295 |

Fonts (Cormorant Garamond + Jost) load from Google Fonts, so a network
connection gives the intended typography; the site degrades gracefully without it.
