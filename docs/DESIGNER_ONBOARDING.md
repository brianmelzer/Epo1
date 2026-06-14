# FERVEUR — Web Designer Onboarding & Direction Brief

*L'acier de tous les jours.*

Welcome to the Maison. This document is your single starting point: what the
site is today, the design language already in place, where we want to take the
look, and — importantly — **where we want AI agents doing real work in the
build and the ongoing operation of the site.**

Read this top to bottom once. Then keep Sections 4 (Look Upgrade) and 5
(Agentic AI) open as your working backlog.

---

## 1. The Project at a Glance

**FERVEUR** is a (fictional, for now) French maison of Paris-designed,
hand-forged carbon steel cookware. The site is a luxury brand storefront — the
job is to make a $115–$295 pan feel like an heirloom, not a SKU.

| | |
|---|---|
| **Type** | Marketing/brand site with a demo storefront (no real checkout yet) |
| **Stack** | Hand-authored static HTML + one CSS file + one vanilla JS file. **No build step, no framework, no dependencies.** |
| **Hosting** | GitHub Pages, auto-deployed from `main` via `.github/workflows/pages.yml` |
| **Repo** | `brianmelzer/Epo1` |
| **Pages** | `index.html` (home), `collection.html` (range + pricing), `about.html` (story/atelier/timeline/care) |
| **Fonts** | Cormorant Garamond (serif display) + Jost (sans), via Google Fonts; degrades gracefully offline |

### File map
```
index.html          ~281 lines  — hero, brand intro, "why steel", featured grid, craft, newsletter
collection.html     ~227 lines  — full 8-piece range, two sections (skillets / specialists)
about.html          ~240 lines  — maison story, atelier, history timeline, care ritual
assets/
  css/style.css     ~363 lines  — the entire design system (tokens + components)
  js/main.js        ~83 lines   — sticky nav, scroll-reveal, mobile menu, demo cart, newsletter
  img/              — brand photography (PNG/JPEG, currently 2–3 MB each — see §4.6)
.github/workflows/pages.yml      — Pages deploy
README.md           — quick orientation + the product table
docs/DESIGNER_ONBOARDING.md      — this file
```

### The product range (source of truth for pricing/copy)
| Piece | Spec | Price |
|---|---|---|
| The 8″ Skillet | Poêle · 20 cm | $115 |
| The 10″ Skillet | Poêle · 25 cm | $145 |
| The 12.5″ Skillet | Poêle · 31.75 cm | $185 |
| The 14″ Skillet | Poêle · 35 cm | $215 |
| The Crêpière | 28 cm | $135 |
| The French Wok | Wok à bord évasé | $245 |
| The Roasting Pan | Rectangulaire · 35 cm | $265 |
| The Griddle Set | Plancha · 6 pièces | $295 |

---

## 2. Working Conventions (read before you touch anything)

- **No build step is a feature, not a limitation.** It keeps the site instantly
  editable and deployable. Don't introduce npm/webpack/React without a
  conversation — the bar to add a toolchain is "the design genuinely can't be
  done otherwise."
- **One stylesheet, token-driven.** All color/spacing/type decisions live as CSS
  custom properties in `:root` at the top of `style.css`. Change the system
  there, not inline. (Inline `style=""` exists in a few spots for one-off
  spacing — minimize new ones.)
- **Branch + PR workflow.** Develop on the designated feature branch, push, open
  a PR, merge to `main` to deploy. Don't push directly to `main`.
- **Accessibility and performance are part of "luxury."** A slow, inaccessible
  site is not high-end. Treat Lighthouse/contrast/keyboard-nav as non-negotiable
  quality gates, not nice-to-haves.
- **Graceful degradation.** The site must still read correctly with no JS and no
  webfonts. Keep enhancements layered on top.

---

## 3. The Current Design Language (what's already decided)

You're inheriting a coherent system. Respect it before you reinvent it.

**Palette** (`:root` tokens):
- `--ink` `#1b2540` deep French navy · `--ink-deep` `#131b30` near-black navy · `--ink-soft` `#2b3756`
- `--paper` `#f5efe2` warm cream · `--paper-2` `#ece3d1` · `--paper-3` `#e3d8c2`
- `--gold` `#b08d57` brushed brass · `--gold-soft` `#c8a978`
- French tricolor accents: `--fr-blue` `#2b3a78`, `--fr-red` `#c0322c`

**Type:** Cormorant Garamond for headings (500–600 weight, tight line-height,
italic for the *script* flourishes like *L'acier de tous les jours*). Jost for
body and UI, light (300) body weight, wide letter-spacing on eyebrows/nav
(`.eyebrow` is uppercase, `.42em` tracking, brass color).

**Motion:** a single shared easing curve `--ease: cubic-bezier(.22,.61,.36,1)`.
Scroll-reveal via `IntersectionObserver` (`.reveal` → `.in`), staggered with
`.d1` delay classes. Nav shrinks + swaps theme on scroll. A marquee strip and a
scroll hint add quiet movement.

**Voice:** French-inflected, restrained, heritage-forward. "Est. 1926." "The
Tuesday omelet. The Sunday roast." Sentences are short and warm. Never salesy.

> **Design principle to hold onto:** restraint. The luxury here comes from
> space, typography, material photography, and small considered motion — not
> from effects. When in doubt, remove.

---

## 4. Where We Upgrade the Look

This is the priority backlog for elevating the visual quality. Roughly ordered
by impact-to-effort. Each item notes the *why* so you can make judgment calls.

### 4.1 Product photography is the #1 lever  ⭐ highest impact
The cards currently reuse a handful of shared brand photos across multiple
products (we just reverted a set of flat SVG placeholders because they read
cheap next to real photography). **Each of the 8 products needs its own
consistent, on-white-or-on-stone hero shot**, plus 2–3 lifestyle/detail angles
for future product detail pages.
- Define a single shooting/treatment spec: angle, crop ratio, background,
  patina level, lighting direction — so all 8 feel like one family.
- This is the most credible path to "looks expensive." See §5.2 for how AI image
  tools can prototype the art direction *before* a real shoot.

### 4.2 Build real Product Detail Pages (PDPs)
Right now products are cards with an "Add to Cart" demo button — there's no
per-product page. A luxury brand needs PDPs: large imagery, the story of the
piece, specs, seasoning/care, "pairs with," and a considered buy module. This is
the biggest structural gap.

### 4.3 Typographic refinement
- Introduce a fluid type scale (`clamp()`) site-wide so headlines breathe on
  large screens and stay controlled on mobile. The hero already uses `clamp` —
  extend the discipline to all headings.
- Audit measure (line length) on long-form copy in `about.html` — cap at
  ~62–68ch for readability.
- Consider a true display weight / optical-size treatment for the largest
  headlines.

### 4.4 Motion & interaction polish
- Add tasteful image parallax / reveal-on-scroll for the split sections and PDP
  galleries (respecting `prefers-reduced-motion` — currently not honored, **fix
  this**).
- Hover states on cards: a slow scale + brass underline reveal rather than a
  hard state.
- Page transitions: even a subtle fade between pages would lift perceived
  quality (can be done without a framework).

### 4.5 The storefront experience
- A real slide-in cart drawer (the current cart is a counter in the nav).
- Quantity, line items, subtotal, "continue shopping." Still front-end/demo
  until commerce is wired, but it should *feel* real.
- A size/comparison helper for the skillet range (8″→14″) — a signature
  interactive moment.

### 4.6 Performance hygiene  ⚠️ do this early
- The current images are **2–3 MB PNGs**. That's a luxury-killing load time.
  Convert to responsive `srcset` + AVIF/WebP, lazy-load below the fold, and add
  width/height to prevent layout shift. Target: largest contentful paint under
  2s on a mid-tier phone.
- Self-host the two webfonts (or `font-display: swap` + preload) to kill the
  flash and the third-party dependency.

### 4.7 Identity polish
- The brand monogram is an inline SVG ("FC" lockup). Refine it into a proper
  mark + wordmark with clear-space rules and a favicon/touch-icon set
  (currently missing).
- Define a small but real brand guidelines page (internal) so the system stays
  consistent as it grows.

### 4.8 Accessibility pass
- Color-contrast audit (brass-on-cream is borderline — verify AA).
- Focus-visible styles, skip-link, ARIA on the mobile menu/cart, keyboard path
  through the whole purchase flow.
- Honor `prefers-reduced-motion` across all the scroll/marquee animation.

---

## 5. Where Agentic AI Agents Fit the Build

This is a first-class part of how we want to work, not an afterthought. Two
distinct tracks: **(A) agents that help us build & operate the site**, and
**(B) agentic features inside the product the visitor experiences.** Be
deliberate about which is which.

### 5.A — Agents in the build & operations workflow

You are already working in an environment (Claude Code) where an AI agent can
read the repo, make changes, open PRs, and respond to CI/review events. Lean
into it:

1. **Component & page scaffolding.** Describe a PDP or a cart drawer in plain
   language; have the agent generate the HTML/CSS/JS consistent with the
   existing token system, then you art-direct and refine. Fastest path from
   wireframe to working markup.
2. **Design-system enforcement (linting agent).** An agent reviewing each PR for
   drift: hard-coded hex values that should be tokens, new inline styles,
   missing alt text, contrast regressions, images over a size budget, missing
   `width/height`. This keeps quality from eroding as velocity rises.
3. **Content & copy generation in-voice.** Product descriptions, care
   instructions, journal/editorial entries — generated against a locked brand
   voice guide (§3), then human-edited. Especially useful for the bilingual
   French/English flourishes.
4. **Asset pipeline automation.** An agent (or a CI step it maintains) that
   ingests a raw photo and emits the full responsive set: cropped ratios, AVIF/
   WebP/fallback, `srcset` markup, compressed to budget. Turns §4.6 from a chore
   into a drop-a-file workflow.
5. **Accessibility & performance auditor.** Scheduled agent runs Lighthouse/axe,
   files issues (or opens fix PRs) for regressions. Treat it as a tireless QA
   teammate.
6. **PR babysitting / autofix.** Agents can watch a PR, react to CI failures and
   review comments, and push fixes — closing the loop between "designed" and
   "shipped green."
7. **SEO & metadata agent.** Generates/validates per-page titles, descriptions,
   Open Graph/Twitter cards, JSON-LD `Product` structured data (price,
   availability) — important for a commerce site and easy to forget by hand.
8. **Visual regression agent.** Screenshots key pages across breakpoints on each
   PR and flags unintended visual diffs.

> **Guardrail for build agents:** agents draft, humans direct. Every
> agent-generated change goes through a PR and a designer's eye. Lock the brand
> voice, the token system, and the performance budget as the rules agents must
> obey — those constraints are what make autonomous output safe.

### 5.B — Agentic features in the product itself

Where AI could become part of the FERVEUR *experience* (validate against brand
restraint — only ship what feels like a concierge, never a gimmick):

1. **"La Concierge" — a cookware advisor.** A conversational agent that helps a
   visitor choose the right pan ("I cook for two, mostly eggs and weeknight
   sears") → recommends the 10″ skillet with reasoning, links the PDP. This is
   the strongest candidate: high-value, on-brand as personal service.
2. **Care & seasoning assistant.** Post-purchase agent answering "how do I
   re-season after rust?" with steps drawn from the care ritual content —
   reduces support load, deepens the ownership relationship.
3. **Recipe / pairing companion.** Given a pan the visitor owns, suggest dishes
   and techniques that show it off. Editorial, brand-building, sticky.
4. **Gift & registry helper.** Agentic flow that assembles a gift set within a
   budget and writes the note. Natural fit for a heirloom brand.
5. **Personalized journal.** Agent curates which story/editorial entries to
   surface based on what the visitor has browsed.

**Sequencing recommendation:** start with **5.A** (build/ops agents) — it
compounds your output immediately and is low-risk. Pilot exactly one **5.B**
feature (La Concierge) behind a clear, optional entry point once PDPs exist.
Don't bolt a chatbot onto a brand site that doesn't yet have product pages worth
recommending.

---

## 6. Suggested First 2 Weeks

1. **Get oriented:** run the site locally (just open `index.html`), read all
   three pages and `style.css` top-to-bottom. Note every token.
2. **Quick wins that raise the floor:** image optimization (§4.6), favicon/icon
   set (§4.7), `prefers-reduced-motion` + focus styles (§4.8). These are
   high-credibility, low-risk, and a perfect first PR.
3. **Define the photography spec** (§4.1) and prototype art direction with AI
   image tools (§5.A.4 / image generation) so we can align before any real
   shoot.
4. **Design one PDP** (§4.2) as the template — this unlocks the storefront and
   the first agentic feature.
5. **Stand up the design-system linting agent** (§5.A.2) so everything after you
   stays consistent.

---

## 7. How to Run & Ship

- **Run locally:** open `index.html` in a browser. No server required (use a
  static server like `python3 -m http.server` if you want clean paths).
- **Edit:** change tokens/components in `assets/css/style.css`; behavior in
  `assets/js/main.js`; structure in the three HTML files.
- **Ship:** branch → commit → push → PR → merge to `main`. GitHub Pages deploys
  automatically (~1 min) via `.github/workflows/pages.yml`.
- **Don't** push directly to `main`, and don't add a build toolchain without
  agreeing on it first.

---

*Questions, or want any section expanded into its own working doc (photography
spec, PDP template, agent guardrails)? Flag it and we'll deepen it.*
