# Contour — Design System Reference (DESIGN_REFERENCE.md)

- This file is the complete design-system reference. [DESIGN.md](../../DESIGN.md) is the short core; it uses the same section numbers, so "DESIGN 2.5" is section 2.5 here.
- Screens are in [docs/screens/SCREENS.md](../screens/SCREENS.md).

**Version 2.1 "Obsidian" — 15 October 2026.** Companion to SPEC.md (section 7).

- This file says **how** to build the interface. SPEC.md says **what** each screen contains. Screens: [docs/screens/SCREENS.md](../screens/SCREENS.md). Visual reference: the Obsidian figures in contour-design.html.
- The look is **Obsidian** (DESIGN-SYNC-001) with METAL-RIM-001, CARD-TITLE-OUT, POLISH-001, MOTION-002, WIDGETS-001...004, HOME-QUICKLOOK and the REVIEW-004 fixes. Superseded looks: docs/DECISIONS.md.
- NUM-001...003, UI-001 and DESIGN-HTML-002...010 still apply where they define numbers, words and states.

---

## 0. The laws

1. **One place.** Colours, type, sizes, spacing, radii, shadows, icons and motion live only in `lib/design/`. No other file creates them.
2. **Reuse before you build.** Use a component. Else compose components. Else add a **variant**. A new component in `lib/design/components/` is the last option.
3. **Meaning, not values.** Code asks for a role (`tokens.color.text.secondary`, `tokens.space.m`, `AppText.numberHero`), never a value (`Color(0xFF5D626B)`, `16`, `TextStyle(fontSize: 15)`).
4. **Section from the route.** A screen takes its section from its route (`Section.spending`). Components read it from the theme. Never pass a section colour by hand.
5. **Not in the gallery = does not exist.** Every component and variant is in the gallery (debug builds) with goldens in Obsidian dark and Light, at text scale 1.0 and 2.0, and in the hidden-amount state where it shows money.
6. **Obsidian: light comes from data, not decoration** (14.1). Metal cards on a near-black page; one hero number per screen; section colour only on chrome (2.3); data colours only from 2.4; glow only on end-point marks (GLOW-001); solid fills that end at the true value; gradients only under the bounded rule (14.1).

Precedence: this file wins over a screen design. SPEC.md wins on content; this file wins on style.

---

## 1. Where things live

```
lib/design/
  tokens/
    tokens.json          single source of truth (W3C design tokens format)
    tokens.g.dart        generated from tokens.json — never edit by hand
  theme/
    app_theme.dart       builds ThemeData + ContourTokens (ThemeExtension) for light and dark
    section.dart         Section enum and SectionScope (inherited section colour)
  typography/
    app_text.dart        the only text styles (AppText.*)
  icons/
    app_icons.dart       the only icon set (AppIcons.*), one stroke style
  components/            every reusable widget (section 6)
  charts/                every chart painter (section 7)
  layout/                screen templates (section 5)
  format/                MoneyText, ChangeText, DateText, PercentText (section 8)
  gallery/               component gallery (debug only)
test/golden/design/      golden tests for every component and chart
```

- Feature code (`lib/features/**`) imports only `package:contour/design/design.dart`.
- Feature code builds screens from **layout templates** and **components**. It never uses `Container`, `DecoratedBox`, `BoxDecoration`, `TextStyle`, `EdgeInsets` with numbers, `BorderRadius`, `BoxShadow` or `Color`.

---

## 2. Tokens

- `tokens.json` is the only source. `dart run tool/gen_tokens.dart` generates `tokens.g.dart`. Both themes come from the same file. Values are logical pixels.
- Every colour token has a dark and a designed Light value (section 12). Where a figure differs from this section, this section wins.

### 2.1 Colour — base palette (do not use directly in features)

| TOKEN | OBSIDIAN DARK | OBSIDIAN LIGHT | USE |
|---|---|---|---|
| `palette.page` | #040405 | #ECEBE7 | page |
| `palette.sheet` | #16171B | #FFFFFF | sheets, menus |
| `palette.ink` | #F4F4F6 | #16171B | primary text, neutral fills |
| `palette.inkDeep` | #0B0C10 | — | dark ink on bright section fills (dark only) |
| `palette.grey.control` | #C9CBD3 | #3C3F48 | unselected control text, neutral pills |
| `palette.grey.secondary` | #A3A6AF | #5A5D67 | secondary text |
| `palette.grey.icon` | #8E9099 | #5A5D67 | chevrons and secondary icons only, never text |
| `palette.white` / `palette.black` | #FFFFFF / #000000 | same | overlays at a stated opacity only |

- Text uses `text.primary` or `text.secondary` only. No tertiary text grey exists. Removed tokens: see DECISIONS.md (DESIGN-SYNC-001).
- `tool/check_contrast.dart` checks every pair in 2.2–2.4 in both themes, composited over the page (section 9). Text needs 4.5:1. Essential non-text marks need 3:1.

### 2.2 Colour — semantic roles (use these)

| ROLE TOKEN | OBSIDIAN DARK | OBSIDIAN LIGHT | USE |
|---|---|---|---|
| `color.surface.page` | #040405 + neutral spotlight (white 6% radial at the top) | #ECEBE7 + white radial at the top | screen background |
| `color.surface.glass` | metal: #18191D → #0C0D0F → #0A0A0C at 160°, no blur | white metal: #FFFFFF → #F4F4F2 → #EFEFEC at 160° | GlassCard, stages |
| `color.surface.rim` | 1 pt at 135°: white 38% (top-left) → 7% → 3% → 20% (bottom-right) | polished silver 1.25 pt: #FFFFFF → #D6D7DC → #C4C6CC → #9EA1A9 | edge of every GlassCard; never on tiles, rows or controls |
| `color.surface.glassEdge` | white 12%, 1 px | ink 8% | toast and undo bar edge only |
| `color.surface.tile` | white 3.5% + inset top 1 pt white 6% | ink 3.5%, no edge | tiles and groups inside a card |
| `color.surface.sheet` | #16171B | #FFFFFF | AppSheet, FilterSheet, menus, toast |
| `color.surface.track` | white 6% | ink #16171B 6% | meter, capsule and segment tracks |
| `color.surface.inverse` | #F4F4F6 | #16171B | neutral selected state: view icons, sheet chips |
| `color.text.onInverse` | #0B0C10 | #FFFFFF | text and icons on `surface.inverse` |
| `color.action.primary.fill` | solid section `gradientStart` (2.3) | same, Light values | primary button, Done, count badge, switch on, checkbox |
| `color.action.selected.fill` | section `gradientStart` → `gradientEnd` | same, Light values | selected chip, segment tab, own/owe tab |
| `color.action.neutral.fill` | #F4F4F6 | #16171B | neutral primary: sheet "Done", tab bar Add |
| `color.action.destructive.fill` | #3A3C44, text #F4F4F6 | #E4E5EA, text #16171B | AppButton destructive, widget Hide (DESTRUCTIVE-ROLE) |
| `color.data.neutral.fill` | #F4F4F6 | #16171B | neutral marks: "today" tick, ring ticks, end of a term bar |
| `color.text.primary` | #F4F4F6 | #16171B | main text, numbers (18.2:1 / 16.1:1 on the page) |
| `color.text.secondary` | #A3A6AF | #5A5D67 | context lines, captions, axis text. Dark: 8.4:1 page, 7.2:1 metal card, 6.6:1 tile. Light: 5.3:1 or more on page, card, tile (measured 15 Oct 2026) |
| `color.text.control` | #C9CBD3 | #3C3F48 | unselected chip and segment text, neutral fact pills |
| `color.text.onSection` | #0B0C10 | #FFFFFF | text on `action.primary.fill` |
| `color.text.link` | section.text | section.text | text links |
| `color.icon.secondary` | #8E9099 | #5A5D67 | chevrons, menu arrows; dark 5.0:1 or more on page, card, tile |
| `color.border.divider` | white 7% | ink 8% | row and section dividers |
| `color.border.chip` | white 12% | ink 10% | unselected chips, ghost buttons |
| `color.focus.ring` | #FFFFFF, 2 px | #16171B, 2 px | keyboard focus on every control |
| `color.state.gain` / `color.state.loss` | 2.4 `data.signed` | 2.4 `data.signed` | signed change text and marks only |
| `color.state.neutral` | text.secondary | text.secondary | zero change |
| `color.state.estPill` | white 8% fill, text.control text | ink 6% fill, text.control text | "Est." and fact pills; never an alarm colour |
| `color.state.disabled` | white 30% | ink 30% | disabled controls, with a text label |
| `color.overlay.scrim` | black 55% | black 35% | behind sheets and dialogs |

- Ink has three roles: `surface.inverse`, `action.neutral.fill`, `data.neutral.fill`. Keep them separate; they differ on a light page.
- Blur is allowed only on the tab bar, the compact title, sheets and menus.
- "Earlier" states (past days, paid items) use a style (`text.secondary` number, no fill), not opacity.

### 2.3 Colour — section roles (chrome only)

Section colour marks only: the selected period chip, the selected segment tab, the primary button, the count badge, the active tab bar item, kickers and links. **Never data or a signed change.**

| SECTION | ROLE | OBSIDIAN DARK | OBSIDIAN LIGHT |
|---|---|---|---|
| Home (also Inbox, Settings) | `gradientStart` → `gradientEnd` | #6F8BFF → #B268FF | #4A55CC → #7A35C4 |
| | `section.text` | #6F8BFF | #4A55CC |
| Spending | `gradientStart` → `gradientEnd` | #FF7A59 → #FF3D8B | #B63D1C → #B81E5C |
| | `section.text` | #FF7A59 | #B63D1C |
| Income (money in) | `gradientStart` → `gradientEnd` | #5CD3FF → #4F8BFF | #0A6BA2 → #2F58D8 |
| | `section.text` | #5CD3FF | #0A6BA2 |
| Wealth (also Investments, What you owe) | `gradientStart` → `gradientEnd` | #EBD08A → #D9A441 | #7F5C0E → #7A5312 |
| | `section.text` | #EBD08A | #7F5C0E |
| Plan (Calendar, Goals, Protect, Tax) | `gradientStart` → `gradientEnd` | #F5C46A → #FF8A4C | #9A5309 → #B4441A |
| | `section.text` | #F5C46A | #9A5309 |
| All sections | `text.onSection` | #0B0C10 | #FFFFFF |

- No `section.glow` (METAL-RIM-001). The page has one neutral spotlight.
- **Measured contrast (WCAG 2.x, 15 Oct 2026):**
  - `text.onSection` on both stops: dark 5.8:1 or more (lowest: Spending end #FF3D8B); Light 5.0:1 or more (lowest: Spending start #B63D1C).
  - `section.text` on page, metal card and tile: dark 5.22:1 or more; Light 4.61:1 or more.
  - Measure on `surface.page` with the spotlight and on both stops of `surface.glass`.
- Kickers use solid `section.text`, never gradient text.
- What you owe and neutral screens use the Wealth and Home roles. A separate "owe" role is open (OB-UX-09).
- `SectionScope` sets the section for a subtree. Components read `context.section`.

### 2.4 Colour — data palettes (charts, category marks and signed change only)

- Data colours are for marks (fills, lines, dots, swatches). Text in a data colour uses the Light text tint in Obsidian Light.
- Essential marks need 3:1 on their background. Labels on a fill need 4.5:1 on that fill.

**Signed change (reserved pair).** No other role uses these hues.

| TOKEN | OBSIDIAN DARK | OBSIDIAN LIGHT | GLYPH |
|---|---|---|---|
| `data.signed.gain` | #3DF2B0 (13.9:1 on page) | #076B49 (5.9:1) | ▲ `glyph.gain` |
| `data.signed.loss` | #FF7A8A (8.0:1) | #C8324B (4.7:1) | ▼ `glyph.loss` |

- Gain and loss always carry a sign (+/−) and, in charts and pills, the glyph. Colour is never the only signal.
- Open: some figures use #C2263A for Light loss text. The token is #C8324B. Unify the figures at regeneration.

**Flow groups (calendar, timelines, cash flow).** Shape first, colour second.

| TOKEN | GLYPH | OBSIDIAN DARK | OBSIDIAN LIGHT | INCLUDES |
|---|---|---|---|---|
| `data.flow.spending` | `glyph.spending` ● dot | #FF7A8A | #B0164F | bills, card bills, loans, card charges |
| `data.flow.investing` | `glyph.investing` ◆ diamond | #C77DFF | #7424C0 | regular investments, vests |
| `data.flow.moneyIn` | `glyph.moneyIn` ★ star | #3DF2B0 | #076B49 | salary, maturing deposits, other income |

- Spending and money in use the loss and gain hues on purpose (CAL-TYPES). The glyph shape separates them from a gain or loss mark.
- Spoken labels keep the full type ("card charge, not from Checking").

**Categorical (`data.category`)** — spending categories, needs/wants, flow of money in. `DataColors.next` cycles the list; colours may repeat. Name and position identify a category, not colour. Never invent a colour.

| KEY | OBSIDIAN DARK | LIGHT TEXT TINT | LIGHT MARK |
|---|---|---|---|
| Rent | #D9B38C | #8D5B28 | #B47534 |
| Groceries | #FFB347 | #B4400C | #B35F00 |
| Dining | #FF5E8A | #B0164F | #DA2A60 |
| Shopping | #9B8CFF | #5540D8 | #7A66F0 |
| Transport | #7AA2FF | #3550C8 | #3D6BE0 |
| Utilities | #5CE1E6 | #0B6A82 | #0B7F86 |
| Subscriptions | #F5D76E | #8A5A00 | #9A7206 |
| Fun | #F28FD0 | #A8136F | #D63C9C |
| Other | #B8C0CC | #4B5260 | — |
| Needs | #FFB347 | #B4400C | #B35F00 |
| Wants | #F28FD0 | #A8136F | #D63C9C |
| Invested | #C77DFF (= `data.flow.investing`) | #7424C0 | #A055E8 |
| In cash | #5CE1E6 (cash colour) | #0B6A82 | #0B7F86 |

- Dark values: 6.8:1 or more on the page. Light text tints: 5.1:1 or more on the page; 4.5:1 or more on page, white-metal card and tile. Light marks: 3:1 or more on all three (DATA-LIGHT, closed 15 Oct 2026).
- **Light mark map (DATA-LIGHT), all other data hues:** #3DF2B0 / #2EE6A6 → #0E8F62; #F5D76E / #F5C46A → #9A7206; #FFD08A → #9A6A10; #7AA2FF → #3D6BE0; #7A90FF → #4A55CC; #5CE1E6 → #0B7F86; #FFB347 / #FFB067 → #B35F00; #FF7A59 → #C8401F; #C9A8FF / #B58CFF → #7A4FD6; #FF6FA8 → #C1336F; #FF8FA3 → #C1334F; #E8A07A → #A8552B.
- Bubbles, vials and pills keep light fills so dark text stays readable.
- **Open:** a colour-vision-deficiency check of the palette.

**Debt (`data.debt`)** — copper #E8A07A (Light text tint #9A4B1E, mark #A8552B) for owe bars, loan lines and icons. The loss hue stays reserved.

**Asset classes (`data.assetClass`)** — Equity ETFs #2EE6A6, Stocks #7AA2FF, Bonds #C77DFF, Mutual funds #FFB347, Cash #B8C0CC, Gold #F5D76E. Holding badges use the class colour (monogram, no remote logo).

- Open (OB-UX-03, partly): Equity ETFs is close to the gain hue; Bonds shares the investing colour; Mutual funds shares Groceries. Class colour shows only on badges and allocation marks, never next to a signed value without its sign.

**Series (`data.series`)** — Net worth #3DF2B0, Investments #7AA2FF, Cash #F5D76E (Wealth line chart); goals: House #2EE6A6, Emergency #7AA2FF, Japan #FF5E8A, Car loan #C77DFF.

- Open: the net worth line uses the gain hue, and Cash is #5CE1E6 on Home but #F5D76E on Wealth. One neutral net worth colour and one cash colour need a token decision.

**Heat scale (`data.heat`, holdings bubbles and treemap only)** — the signed hue mixed into #24262D:

- gain #14B47E, loss #E0485C; strength k = 22% + 38% × min(1, |change| ÷ largest |change| in view), so k is 22%–60%;
- no change or no return (cash): #4A4D57;
- the 60% cap keeps white labels at 4.5:1 or more (5.2:1 at the strongest gain fill);
- the key states both ends (for example "−1.1% ... +1.1%") with ▲ / ▼.

**Track tint:** a track behind a coloured bar is `surface.track`, not a tint of the bar colour.

### 2.5 Type

**Family (OB-FONT, POLISH-001):** Inter Display for `numberHero.light`; Inter (v4) for all other styles. SIL OFL 1.1, bundled in `lib/design/fonts/` (weights 200, 400, 500, 600). Tabular figures (`tnum`) on every number. No other family. The figures use SF Pro as a stand-in; sizes and weights are the same.

| STYLE TOKEN | SIZE | WEIGHT | LETTER SPACING | LINE HEIGHT | USE |
|---|---|---|---|---|---|
| `AppText.numberHero.light` | 64 (fits down to 40) | 200 | −0.035 em | 1.0 | the one hero number (0bHero); currency mark 0.45 em, weight 300, raised; cents 0.5 em in `text.secondary` |
| `AppText.numberXL` | 40 | 500 | −0.02 em | 1.05 | a second large number in a sheet; never a second hero |
| `AppText.numberL` | 30 | 400 | −0.03 em | 1.05 | net worth on a tile, card totals |
| `AppText.numberM` | 24 | 400 | −0.03 em | 1.1 | This month figures, values in rings |
| `AppText.numberS` | 18 | 500 | −0.01 em | 1.2 | IconTileGrid values, fact values, card summary values |
| `AppText.numberXS` | 15 | 500 | 0 | 1.3 | amounts in rows and tables |
| `AppText.dateDay` | 22 | 400 | −0.02 em | 1.0 | day number in date rows |
| `AppText.titleScreen` | 24 | 400 | −0.02 em | 1.12 | header title where it shows |
| `AppText.titleBar` | 17 | 400 | 0 | 1.25 | centred title in a TopBar |
| `AppText.titleCompact` | 15 | 600 | 0 | 1.2 | compact title |
| `AppText.titleGroup` | 20 | 600 | −0.015 em | 1.2 | card titles, above the card (CARD-TITLE-OUT) |
| `AppText.titleSection` | 17 | 500 | −0.01 em | 1.3 | titles inside a sheet or tile group |
| `AppText.titleDialog` | 20 | 600 | 0 | 1.3 | sheet and dialog titles |
| `AppText.body` | 15 | 400 | 0 | 1.45 | default text, row names |
| `AppText.bodyStrong` | 15 | 500 | 0 | 1.45 | strong row names |
| `AppText.line` | 15 | 400 | 0 | 1.55 | context line under a hero (`text.secondary`) |
| `AppText.bodyS` | 14 | 400 | 0 | 1.4 | secondary buttons, toast |
| `AppText.caption` | 13 | 400 | 0 | 1.4 | context lines, notes, legends, tile facts (minimum size) |
| `AppText.captionStrong` | 13 | 600 | 0 | 1.4 | tile names, field labels |
| `AppText.label.caps` | 13 | 600 | 0.06 em or less, uppercase | 1.2 | kickers, card meta, sheet group labels, "Show as table" |
| `AppText.button` | 17 | 600 | 0 | 1.0 | primary buttons |
| `AppText.buttonS` | 13 | 500 | 0 | 1.0 | chips, segment tabs, menus |
| `AppText.tabLabel` | 12 | 500 / 600 selected | 0.04 em | 1.0 | tab bar and own/owe tab labels only |
| `AppText.weekday` | 12 | 500 | 0.04 em | 1.0 | calendar weekday headers, date-row month labels only |
| `AppText.chartLabel` | 12 | 600 | 0.04 em | 1.0 | direct labels in charts |
| `AppText.chartAxis` | 11 | 400 | 0.02 em | 1.0 | chart axes; month mark and "+N" in a calendar cell |
| `AppText.key` | 26 | 400 | 0 | 1.0 | keypad digits |

- **Sizes:** minimum 13. Exceptions: 12 (tab labels, weekday headers, chart labels) and 11 (chart axes). No other sizes.
- **Weights:** 200–300 only at 40 pt or more. Numbers 18–39 pt use 400 or more. Amounts below 18 pt use 500 (OB-UX-10).
- **One hero size.** Every tab root and detail screen uses `numberHero.light` for its hero (HERO-ONE).
- **No gradient text** except the hero number fill (14.1 rule c).
- Colour is not part of a style. Components apply the role colour.
- `copyWith(fontSize: ...)` is forbidden outside `lib/design/`. If a screen description or figure gives another size for the same style, this table wins.
- **Text scale:** all styles follow the system scale up to 2.0, chart text included. `numberHero.light` shrinks through `FitNumber`, never below 40.

### 2.6 Space

| TOKEN | VALUE | USE |
|---|---|---|
| `space.xxs` | 2 | icon to text in pills |
| `space.xs` | 4 | number to sub-line |
| `space.s` | 8 | gaps in rows, chips, tiles |
| `space.m` | 12 | gaps in cards, row icon to text |
| `space.card` | 14 | gap between cards |
| `space.l` | 16 | gaps between groups in a card |
| `space.page` | 20 | screen side padding on every screen (POLISH-001); only a hero chart goes edge to edge |
| `space.cardPad` | 18 | card padding (top and sides) |
| `space.xl` | 20 | sheet side padding |
| `space.xxl` | 24 | dialog padding |
| `space.xxxl` | 32 | empty-state spacing |
| `space.tabClearance` | 120 | bottom padding on screens with the tab bar |

- Templates apply the gaps between blocks. Features add no gaps.

### 2.7 Size

| TOKEN | VALUE | USE |
|---|---|---|
| `size.touchMin` | 44 | minimum touch target; the visual pill can be smaller |
| `size.button` | 52 | primary, neutral and ghost buttons (figures 52–54) |
| `size.buttonCompact` | 44 | chips, segment tabs, view, filter and sort icons |
| `size.field` | 52 | text and select fields |
| `size.rowS` | 54 | rows in a card |
| `size.rowM` | 62 | date rows |
| `size.rowHolding` | 65 | two-line holdings rows |
| `size.tileQuick` | 87 high, 125 wide minimum | IconTileGrid tile on Home |
| `size.key` | 60 | keypad keys: no fill, no edge at rest; press fill only |
| `size.iconS` | 16 | chevrons, inline icons |
| `size.iconM` | 20 | icon buttons, tile icons |
| `size.iconL` | 22 | tab bar, source icons |
| `size.badgeS` | 36 | holding and list badges |
| `size.badgeM` | 40 | performance badges, inbox count |
| `size.badgeL` | 46 | type icons in tile grids |
| `size.tabBar` | 64 | tab bar; floats 14 pt above the bottom and 16 pt from the sides; hides with the keyboard |
| `size.capsule` | 14 | CapsuleMeter track (12 in category rows) |
| `size.meterS` | 6 | thin bars in rows |
| `size.meterM` | 10 | hero meter bar |
| `size.ringStroke` | 7 | small rings (16 for premium and net-worth rings) |
| `size.vial` | 62 × 190 | GoalVial; equal for every goal, never scaled by target |
| `size.calendarCell` | 48 high minimum | SymbolCalendar cell (60 with two glyph rows) |
| `size.glyph` | 7 (dot), 6 (diamond), 9 (star) | flow glyphs |

### 2.8 Radius

| TOKEN | VALUE | USE |
|---|---|---|
| `radius.xs` | 3 | bars in rows, small marks |
| `radius.s` | 8 | focus outlines, small pills |
| `radius.m` | 12 | badges, calendar cells, icon buttons |
| `radius.tile` | 18 | tiles, inner groups, segmented groups, treemap frame |
| `radius.card` | 26 | GlassCard and stages |
| `radius.sheet` | 28 | top corners of sheets |
| `radius.pill` | 999 | buttons, chips, segment tabs, capsules |

- Surfaces use only `radius.s`, `m`, `tile`, `card`, `sheet` and `pill` (POLISH-001). A nested shape uses the outer radius minus the padding (minimum `radius.s`).
- **No card in a card.** A tile or group in a GlassCard has `surface.tile` and no edge. Only a top-level card has `surface.rim`.

### 2.9 Elevation and glow

| TOKEN | OBSIDIAN DARK | OBSIDIAN LIGHT | USE |
|---|---|---|---|
| `elevation.glass` | `surface.rim` + 0 24 50 −30 black 90% | `surface.rim` + 0 18 40 −28 rgba(20,22,40,.35) | GlassCard, stages |
| `elevation.sheet` | 0 −20 50 −10 black 80% + inset 0 1 0 white 8% | 0 −20 50 −10 black 25% | sheets |
| `elevation.nav` | #16171B 86%, blur 20, inset 0 1 0 white 8%, 0 12 30 −12 black 80% | white 88%, blur 20, inset 1 px ink 6%, 0 12 30 −14 rgba(20,22,40,.3) | tab bar, compact title |
| `glow.mark` | one static halo: radius ≤ dot radius + 6 pt, mark colour, opacity ≤ 0.4 | same, Light mark value | end-point marks only. End dot 4.5 pt with a 2 pt ring in the page colour |
| `elevation.none` | — | — | rows, items in cards |

**Rule GLOW-001 (glow only on end-point marks).**

- Only on a chart end-point mark (last dot of a line, lowest point of a balance line, "today" dot on a value line): one static halo behind the dot, radius ≤ dot + 6 pt, opacity ≤ 0.4, never animated (example: dot 5, halo 11, opacity 0.3).
- No glow (blur filter, drop-shadow filter, coloured outer shadow) on lines, arcs, areas, bars, capsules, rings, vials, tracks, icons, pills, badges, chips, selected states or buttons. No halo or text shadow on the hero.
- Allowed: the black elevation shadows; an inset 1 px edge (no blur) in a data or section colour on tiles and selected tabs.
- Lint `no_glow_except_endpoint`.

### 2.10 Motion (MOTION-002)

Motion explains a change, plays once and never delays a number. It never loops, never counts up, never celebrates, and treats gain and loss the same (SPEC 2).

**Screen order.** Input works from 0 ms. The screen is complete by 700 ms.

| STEP | START | WHAT MOVES |
|---|---|---|
| Page | 0 ms | `motion.page` (tab change: fade 220 ms), or `motion.shared` when a card opened the page |
| Hero | 60 ms | `motion.hero`: fade up 6 pt, scale .985 → 1, 320 ms. Never counts |
| Main chart | 140 ms | `motion.draw` |
| Cards | 200 ms | 8 pt rise + fade, 300 ms, 40 ms stagger, first 5 cards only |

| TOKEN | VALUE | USE |
|---|---|---|
| `motion.fast` | 120 ms, standard | press states, colour changes, hide amounts (digits fade to "$……") |
| `motion.select` | 300 ms, critically damped (stiffness 380, damping 39; web `cubic-bezier(.25,1,.5,1)`) | one pill indicator behind chips, two-part tabs and section tabs; retargets from its current place and speed (taps never queue); text stays still, its colour fades 120 ms |
| `motion.hero` | 320 ms, `cubic-bezier(.2,.8,.2,1)` | hero reveal; on change, old number out 120 ms, then new in 220 ms, never overlapping; direction follows time, never gain or loss |
| `motion.page` | 340 ms, standard | page push 20 pt slide + fade; Back from the left |
| `motion.shared` | 450 ms, critically damped (stiffness 300, damping 35) | container transform: card rect and `radius.card` (26) become the page rect (radius 0); content cross-fades at 40–60% of travel; no page slide at the same time; glyphs never scale |
| `motion.draw` | once per chart per session, when 15% is in view and scrolling stopped; 900 ms cap | lines and arcs draw along the path (520 ms); area fill in the same pass, clipped to the line; bars grow from zero, also negative bars (400 ms, 12 ms stagger, 160 ms cap); dots scale in after the line (300 ms, no overshoot); dashed reference lines and labels fade in last; end-dot halo lights once (dark .3, Light .2) |
| `motion.revisit` | 160 ms fade | a chart drawn earlier this session; the Home line draws once a day |
| `motion.settle` | 420 ms, critically damped (FLIP) | holdings bubbles and tree tiles move and resize; new ones grow from .6, no overshoot |
| `motion.sheet` | 420 ms, damping ratio .85 (web `cubic-bezier(.2,.9,.25,1.04)`) | sheets rise; stops at 50% and full; follows the finger; closes on a flick above 900 pt/s or a drag past 40%; 0.55 rubber band above the top stop; page behind scales to .965 — dark dims to 80%, Light adds ink scrim rgba(20,22,40,.18) (no filter) |
| `motion.press` | 60 ms delay, 120 ms to scale .98; release spring (stiffness 500, damping 30) | cards and rows; dark fill 4% → 7% white; Light shadow 0 10 28 → 0 4 12; no glow |
| `motion.toggle` | thumb spring (stiffness 500, damping 28); track colour 160 ms | switches |
| `motion.dismiss` | 420 ms, 45 ms stagger | confirmed Inbox rows slide out, gap closes, count goes down per row; Undo for 5 s (no countdown motion); then static "Inbox is clear · N confirmed" |
| `motion.scrub` | hold 180 ms; cursor in 120 ms, out 160 ms | hold a chart: 1 pt cursor; hero shows value and date under the finger at once (no tween); haptic ticks at month ends and today; on release the hero returns with `motion.hero` |
| `motion.pull` | rubber band .5; threshold 64 pt, one tick | pull down at top: recalculate on this phone, show "Updated on this phone · hh:mm"; on Investments also fetch prices for enabled symbols with "Prices n of m". A button does the same |

**Rules**

- **Overshoot:** only sheets and toggle thumbs. Data marks never pass their true value.
- **Haptics** (`selectionClick` only): chip and tab selection, switches, keypad keys, Confirm, pull threshold, scrub detents. Never on sheet open, a due item or a loss.
- **Loading:** no spinner, no shimmer. Progress is text ("6 of 9 prices"). Old prices show their date.
- **Trust:** "Saved" shows on the changed row for 2 s. "Since last open" shows counts and times only ("3 imported · prices 09:10 · 2 to check"), never money changes.
- **Not used:** streaks, badges, confetti, reward bursts, count-up numbers, red flash or shake on a loss, pulse on due items, Live Activities for prices or net worth, parallax on numbers, looping glows.
- **Accessibility:** `MotionScope` reads `MediaQuery.disableAnimationsOf` (iOS Reduce Motion, Android "Remove animations") and sets every token to 0; haptics stay. Screen readers get the final value at once (outgoing child excluded). After a push, focus goes to the top-line label. After Confirm, only the count is announced. At 200% text, shared transform and FLIP use the final layout, no large travel.
- **Performance:** per chart one `AnimationController` and one `CustomPainter(repaint:)`, marks from `Intervals`; cached `PathMetrics` with `extractPath`; area sweep with `clipRect`, not `saveLayer`; halo by colour alpha, not `Opacity`; `RepaintBoundary` around each chart and the hero; `TickerMode` off on hidden tabs; a scrim layer behind sheets, not a colour filter; no backdrop blur over scrolling content on low-tier devices. Budget: p90 build + raster 16 ms at 60 Hz, 8 ms at 120 Hz.
- **Tests:** goldens at the final state, animations off (light, dark, 1.0, 2.0); no ticker after draw-in; semantics after a period change (new label, no old label); a fake haptics interface counts calls per event.

### 2.11 Icons

- One set: **Lucide** (ISC licence), stroke icons, bundled in `lib/design/icons/`. Stroke 1.75 (2.2 for the tab bar Add), round caps and joins.
- Access only through `AppIcons.*`: add, mic, scanQr, receipt, file, chevronRight, info, hide, show, inbox, settings (sliders glyph), tools (calculator glyph), search, filter, import, lock, shield, trash, edit, more, close, back, viewBubbles, viewList, viewTree, and type icons bank, chart, card, repeat, house, car, safe. Settings and Tools use different glyphs.
- Size only from `size.icon*`. Colour from the component.
- `AppIcons.add` **only on the tab bar Add button and, on screens without the tab bar, one header button.** Lint `no_add_icon`.
- **Glyphs** (`AppGlyphs.*`): spending ●, investing ◆, moneyIn ★, gain ▲, loss ▼. Drawn shapes in `lib/design/`, sized by `size.glyph`, coloured by 2.4.

---

## 3. Theme and sections

- Obsidian dark is the default; Obsidian Light is the other theme (section 12). SPEC.md owns the theme switch.
- `AppTheme.dark()` / `AppTheme.light()` build ThemeData and register ContourTokens (`context.tokens`).
- Override non-matching Material defaults (ripple, text theme, buttons) once in AppTheme, never per widget.
- The router sets `SectionScope(scope: ...)` per route (AppRoutes declares each route's section). Components read `context.section`. Sheets and dialogs inherit the opener's section.
- The page is `surface.page` in every section.
- The section sets only chrome: `action.primary.fill`, `action.selected.fill`, `section.text`, `text.onSection`, the active tab bar item. Data components never read the section colour.

---

## 4. Number and text formatting

All amounts, percentages, changes and dates go through `lib/design/format/`. Never format a number in a feature.

| WIDGET | SHOWS | RULES |
|---|---|---|
| `MoneyText(amount, style: NumberStyle.hero)` | "$187,900" | locale separators, currency symbol, cents only with `showCents` or when the value has cents; hidden as "$······" (currency mark stays) in text and accessible name |
| `ChangeText(amount or percent, period: ...)` | "+$5,490 this month", "−0.4% today" | always a sign; colour from `state.gain` / `loss` / `neutral`; period words from SPEC Appendix B |
| `PercentText(value)` | "37%" | splits come from `Percent.split(...)` (largest remainder) |
| `DateText(date, format: DateStyle.short)` | "22 Oct", "Tuesday, 13 October", "in 9 days" | no relative word without a date for payments |
| `EstLabel()` | "Est. pill" | only through `ValueState.estimated` |
| `SourceLabel(source)` | "Imported", "Captured", "Manual", or a date | from the value's source |
| `StateValue(value)` | real value, "None recorded", "Missing since [date]", "Expected" | every value on screen passes through it; unknown never shows as zero |
| `FitNumber(child)` | shrinks a number to fit | minimum sizes from 2.5 |

---

## 5. Layout templates (every screen uses one)

| TEMPLATE | USE | FIXED PARTS |
|---|---|---|
| `TabRootScreen` | Home, Spending, Wealth, Plan (Inbox is a DetailScreen with the tab bar) | `surface.page`; ScreenHeader (date line, optional SegmentTabs, up to 3 icon buttons), one 0bHero; optional one ControlRow (PeriodChips in the hero); scrolling GlassCards with `space.card` gaps; ends with WidgetEditBar; tab bar; bottom padding `space.tabClearance` |
| `DetailScreen` | every screen opened from another | `surface.page`; DetailHeader; one 0bHero; optional one ControlRow; scrolling GlassCards; tab bar if the parent had it |
| `FormScreen` | add and edit forms | TopBar with Close and an optional "Save" text action; form blocks; bottom primary button |
| `CaptureScreen` | camera, QR, voice | full-height area; one primary and one secondary button |
| `AppSheet` | sheets | scrim, grabber, titleDialog, content, buttons; height fits content up to 90%; rises as one piece; no line under the title at rest, a 1 pt divider only after content scrolls |
| `AppDialog` | confirmations | scrim, title, body, primary (or destructive) and ghost buttons stacked |
| `AppToast` | undo and confirmations | see 6.6 |

- **Compact title (tab root and detail):** when the hero scrolls away, the kicker in sentence case (13/500 `text.secondary`) and the hero value (15/600) show at the top with blur. A 28 pt `surface.page` fade sits above the tab bar.
- **One ControlRow per screen** (PeriodChips, SegmentedControl or ChipRow). The template accepts only one. Forms are excluded. SegmentTabs in the header is navigation, not a control row.
- **DECISION-PENDING: CONTROL-ROW-SCOPE.** Card-level controls exist on X40 (You own / You owe tabs), X43 (group menu, view icons, filter, gain period) and X60 (source chips). Until decided, a card-level control changes only its own card, names its state in the card and never changes the hero. REVIEW-004 OB-UX-13 prefers one "Display options" sheet per card.
- **One add control per screen.** TabRootScreen and a DetailScreen with the tab bar refuse a header add button (debug assert).
- Block order follows SPEC.md 4.6 (needs action, available money, this month, overall position, progress) where the content exists.

---

## 6. Component catalogue

- Every component reads tokens and the section from the theme. Variants are enums. Do not wrap a component to change its look; add a variant here.
- New screens use the Obsidian components (6.7). Components in 6.1–6.6 take Obsidian tokens.
- **Hidden amounts.** Every money component has a hidden state: text and accessible names show "$······"; dates, counts and percentages stay; charts keep their shape and hide their text (section 7); area charts of amounts change to a list.
- **Goldens:** Obsidian dark and Light, 100% and 200% text, hidden state where money shows.

### 6.1 Surfaces

| COMPONENT | VARIANTS | NOTES |
|---|---|---|
| `Slab` | section (default), neutral, butter, plain | every variant draws as 0bHero (kicker, number, line) + GlassCard(stage) for its chart and stat boxes. No colour block. At most one chart; an inner ControlRow counts as the screen's control row |
| `AppCard` | normal, outlined (decisions), sunken | draws as GlassCard: `surface.glass`, `radius.card`, `space.cardPad`, `elevation.glass`. `outlined` adds a 1 px `border.chip` edge; `sunken` uses `surface.tile`, `elevation.none` |
| `StatBox` | onCard, onStage | label (`label.caps`), value (`numberS`/`numberM`, weight ≥ 400), optional sub-line, `surface.tile`. Same as one FactRow fact |
| `StatusBanner` | info, estimate | `surface.tile` with 1 px `border.chip`, icon, one or two sentences in `text.primary`. Dark: estimate icon and title #F5D76E. Never an alarm colour |

### 6.2 Text blocks

| COMPONENT | NOTES |
|---|---|
| `ScreenTitle` | `titleScreen`, optional caption, section dot (14 × 14, `radius.xs`), up to 3 IconButtons |
| `TopBar` | back or close, centred `titleBar` and caption, right actions (icon buttons or one text action) |
| `SectionTitle` | `titleSection` left, optional total (`numberXS`) or TextLink right. Only in a sheet or tile group; a card title is the GlassCard header |
| `Sentence` | summary line in a card (`AppText.line` / `bodyS`) with inline MoneyText |
| `Note` | caption in `text.secondary` under blocks |
| `TextLink` | `buttonS` in the section colour, 44 px target |

### 6.3 Buttons and controls

| COMPONENT | VARIANTS | NOTES |
|---|---|---|
| `AppButton` | primary (solid `action.primary.fill`, `text.onSection`), neutral (`action.neutral.fill`, `text.onInverse`), ghost (transparent, `border.chip`), soft (`surface.track`), destructive | height `size.button`, `radius.pill`, `button` text, optional leading icon (never `AppIcons.add`), full width by default. No gradient, no glow. **DESTRUCTIVE-ROLE:** destructive = `action.destructive.fill` (filled neutral grey), trash icon, explicit verb ("Delete payment"). Never the loss hue or a section colour |
| `IconButton` | onPage (white 6% / ink 5%, no edge), onCard (`surface.tile`), plain | 44 × 44 circle, `radius.pill`, icon `size.iconM` in `text.primary`, required semantic label, `focus.ring`. Every Back and Close is IconButton.onPage |
| `AddButton` | — | only in AppTabBar: icon-only pill 56 × 44, `surface.inverse`, `AppIcons.add`; label "Add"; long-press = voice |
| `SegmentedControl` | — | `surface.track` background; selected `action.selected.fill` + `text.onSection`; 44 px items; `buttonS` |
| `ChipRow` / `Chip` | filter (count), choice (colour dot), dashed ("All categories") | 44 px, `radius.pill`, horizontal scroll |
| `PeriodControl` | — | period chips inside a slab (counts as the control row) |
| `ToggleRow` | — | name (body 500), description (caption), switch (on = `action.primary.fill`; state also by position) |
| `SelectRow` | with or without leading badge | name, value (`text.secondary`), chevron, min `size.rowS` |
| `Checkbox` | — | 30 × 30 visible in a 44 × 44 target, radius 10; ticked: `surface.inverse` with `text.onInverse` tick; unticked: 1.5 px `border.chip` |
| `InfoButton` | — | (i) icon; opens GlossarySheet or AboutNumberSheet |
| `SortButton` | — | ghost chip with chevron; opens a sort sheet |

### 6.4 Forms

| COMPONENT | NOTES |
|---|---|
| `AppField` | label above (`captionStrong`, `text.secondary`); 52 px field (`surface.tile`, 1 px `border.chip`, `radius.m`); helper caption; optional trailing icon |
| `AmountInput` | large `numberHero` amount with grey cents; used with Keypad |
| `Keypad` | 3 × 4 grid of `size.key` keys, no fill, no edge; press fill white 8% / ink 6%, `radius.tile`; digits `AppText.key`; Delete in `text.secondary` |
| `PillPicker` | small pill (currency, date, account) that opens a sheet |
| `SplitEditor` | category and amount rows, "Add a part", left to split |
| `FormGrid` | 2-column field grid, `space.s` gaps |

### 6.5 Rows and lists

| COMPONENT | NOTES |
|---|---|
| `PaymentRow` | DateBlock (`dateDay` + month caption), name (`bodyStrong`), type dot + type + detail (caption), amount (`numberXS`, gain colour for money in), optional "after" balance |
| `BalanceRow` | colour mark (3 pt, `radius.xs`, data key), name, one fact, optional SourceLabel, optional Sparkline, value (`numberXS`) via StateValue, share or change, chevron. Variants faded ("None recorded"), indented ("Of which") |
| `HoldingRow` | badge (class colour, ticker initials), name, "Gain +$…", sparkline, value, change today |
| `TransactionRow` | category badge, name, detail, amount |
| `ReadyRow` (Inbox) | checkbox, name, source icon and text, amount, category chip ("?" when unsure) |
| `FactCard` | 6 px colour bar on top, when, name, fact; horizontal via FactCardRow |
| `ProgressRow` | name, %, detail, thin meter |
| `KeyValueList` | label–value pairs in a card |
| `AppTable` | header in `captionStrong` `text.secondary`; rows with dividers; numbers right-aligned (`numberXS` or body); horizontal scroll when wider than the card; minimum width 330 |
| `ListGroup` | card: rows in one card; plain: page surface, divider before each section, no nested card or shadow. The component owns all dividers. With icons, the divider starts under the text (icon width + `space.m`) |
| `EmptyState` | icon in a neutral badge (white 6% / ink 5%, icon `text.secondary`); no section colour, no reward mark; title (`titleDialog`), one sentence, next step in words |

### 6.6 Feedback

| COMPONENT | NOTES |
|---|---|
| `AppToast` | `surface.sheet` pill (`radius.pill`) with `surface.glassEdge`, blur allowed, `bodyS` text, one "Undo" in `action.neutral.fill`, 5 s, above the tab bar |
| `UndoBar` | inline bar after a list action: 52 pt pill, `surface.glassEdge` edge, 15 pt message, underlined "Undo" text; button 44 pt; no spinner |
| `AppDialog` | see section 5 |
| `ConfirmBar` | primary button with count and total ("Confirm 8 ticked, $412.36"). Sits after the list, in the scroll flow. Never floats over rows or decision buttons |
| `LoadingValue` | cached value with a small updating mark; no spinner over content |

### 6.7 Obsidian components

Each has a semantic label, l10n strings, a gallery entry, goldens (dark and Light, 100% and 200%) and a hidden-amount golden where it shows money. Widget catalogue: [docs/spec/SPEC_WIDGETS.md](../spec/spec-widgets.md) (W11, W12). "Hidden" = what the hidden-amount state shows.

| COMPONENT | VARIANTS | ANATOMY AND RULES | HIDDEN |
|---|---|---|---|
| `0bHero` | number (default), period (with PeriodChips and a background chart), detail (two side figures) | Kicker: `label.caps`, solid `section.text`, metric and period only (never the tab name). One `numberHero.light` number with the 14.1 (c) fill. Optional side figures (signed change in `data.signed`, small `label.caps` period under each), context line (`AppText.line`), InfoButton in the kicker row. `period`: the period's line sits behind the number, masked to 45% at its left end. No halo, no text shadow. At 200%, side figures move under the number | number "$······"; side amounts masked, % stay; chart keeps shape, axis text hidden |
| `GlassCard` | normal, stage (holds a chart), wide | `surface.glass`, `elevation.glass`, `radius.card`, padding 18 top and sides, 10 bottom. **CARD-TITLE-OUT:** title and meta sit above the card, 4 pt in from its edge, 10 pt above it: title `titleGroup` `text.primary` left, meta `label.caps` `text.secondary` right (wraps under the title). A title that opens a screen has a small chevron. Card and title are one focus and reader group. Exception: a header with controls for the card (Holdings) stays inside. A whole-card link has a chevron and one accessible name | amounts masked |
| `WidgetSlot` | normal, editing | WIDGETS-001: wraps each tab-screen card with its title. editing: 1 pt dashed outline (white 22% / ink 25%) 6 pt outside; tool row on the title line: Hide (`action.destructive.fill`, minus glyph), title, Move up, Move down (44 pt each), drag handle; content inert at 72% opacity. Drag lift: scale 1.02 + `elevation.sheet` (none with reduce motion). At a section boundary Move up / Move down move the widget into the previous / next section (SPEC W5); the spoken label is "Move to [section name]" or, with no title, "Move to section [n]"; no extra control | as the card |
| `WidgetSection` | titled, untitled, editing, readOnly | WIDGETS-007: a titled group of widgets from the default layout file (SPEC W13). Title in the "More" divider style: `label.caps`, `text.secondary`, hairline to the right; untitled (also a retained section that the file removed) = no header at rest. Lays out placements by size, inside the section, on the visible order: a half placement shares a row (12 pt gap) with the next visible placement if that one is also half; otherwise it takes the row alone. Compact width: all placements full width above text scale 1.3 (DECISION-PENDING: WIDGET-HALF-REFLOW); medium and expanded classes (13.1) keep pairs. Width changes never change a widget's content or state. editing: every section shows an edit header with Move section up / Move section down (44 pt): titled sections on the title line; untitled and retained sections a `label.caps` header "Section [n]" (spoken "Section [n], no title"). Empty sections show in edit mode only, as a 64 pt dashed drop area with the caption "No widgets". readOnly: a layout saved by a newer app version; edit tools are disabled, the note "Saved by a newer version of the app. Default is available." shows above the first section, and Default stays enabled. No styling per section. | as the host |
| `WidgetEditBar` | — | End of a tab screen. At rest: quiet pill "Edit widgets" (grid glyph, 15 pt, white 6% / ink 5%). Edit mode: sticky bar 6 pt above the tab bar, **one row** (WIDGETS-004), all 48 pt: Cancel (icon X; back to the state at edit start), Undo (icon; one step; disabled with no change), "Default" (text pill, 14 pt; disabled at default; restores this screen's widgets and order, Home also its tiles), "Add widget" (text pill, never the add icon), Done (filled circle `action.primary.fill`, ✓; the only filled control). Spoken "Cancel", "Undo", "Done". Wraps at 200% (WIDGETS-003) | — |
| `AddWidgetSheet` | — | AppSheet "Add widget": a note; `label.caps` groups "New in this version" (only on a customised screen, first; SPEC W13, DECISION-PENDING: LAYOUT-UPGRADE), "Hidden on [screen]", "From [screen]"; each row: a live preview of the widget (inert, same numbers, hidden amounts masked; full-width widgets at 62 %, half-width widgets at their real size; a tap or Enter shows it full width, again shows it small), then name, source screen (caption) and an "Add" pill (44 pt; WIDGETS-006b). A value that is not loaded shows "Not loaded yet" (`text.secondary`, no number, no chart). Semantics: the preview is one image-like group; inner semantics are excluded; spoken label "Preview of [name]: [main visible values]. Show full size." with amounts masked when hidden. Text in a 62 % preview can be below 13 pt; the `min_text_size` lint exempts only AddWidgetPreview and requires its "Show full size" control, which draws the widget at 100 %. Above the WIDGET-HALF-REFLOW text scale, previews draw at 100 % width. Goldens: dark, Light, 100 %, 200 % and hidden amounts (X12). Widgets with own controls stay on their screen | preview amounts "$······" % and counts stay; spoken label masked |
| `TileListSheet` | — | HOME-QUICKLOOK: AppSheet "Quick look tiles", opened by a "Tiles" pill in the Quick look edit row. Per tile: name, "Shown"/"Hidden", Move up / Move down (shown tiles only), native switch 51 × 31 (on = `action.primary.fill`) | — |
| `ScreenHeader` | title, tabs, label | TOPLINE-001: one top line. Left: Back or Close (if any), then the kicker label (`label.caps`, `section.text`, wraps only between " · " parts); or SegmentTabs (Plan), no label. Title and date line are reader headings only. Up to 3 IconButtons right (Search, Inbox with count badge, Settings or Tools), same positions on every tab root of a section | — |
| `DetailHeader` | back, plain (Inbox) | 48 pt row: 44 pt IconButton.onPage Back, page label (`label.caps`, `section.text`) left, one 44 pt action right; title is a reader heading | — |
| `SegmentTabs` | — | Sibling navigation (Plan: Calendar · Goals · Protect · Tax). Track `surface.track` + 1 px `border.chip`, visible height 32; selected pill 26 high, `action.selected.fill`, `text.onSection`; unselected `text.control`; `buttonS`; 44 pt targets. Narrow width or 200%: horizontal scroll, tabs do not shrink. Spending has no SegmentTabs (SPEND-TABS) | — |
| `PeriodChips` | — | Hero control row: chips 44 high, min 56 wide, `radius.pill`, 1 px `border.chip`, white 4% / ink 4%, `buttonS` `text.control`. Selected: `action.selected.fill`, `text.onSection`. One radio group named "Period". Periods from SPEC (e.g. 1D · 1M · 1Y · All) | — |
| `IconTileGrid` | quickLook (Home, sideways), types (Wealth, 3 columns), monochrome | Tile: type icon 18–20 pt; name `captionStrong` in the tile colour (Light: mixed 70% to black); value `numberS`; one fact caption `text.secondary`, one line. quickLook: tiles ≥ 125 wide, about 2.5 visible, snap per tile; a tile shows only when its kind is recorded; no tiles = no card. types: a recorded type opens its page; an empty type shows "None recorded", dashed edge, opens Add for that type. 200%: one column. monochrome (X10, X12; METAL-RIM-001): neutral icon tiles (`text.control` icon, white 6%), neutral capsule fills (#E4E5EA / #2A2C33), grey net-worth target bar, tile values `numberM` (24/400), This month figures `numberL` (30/400), silver hero line (#D8D9DE 2.25 pt, area white 6%, white end dot, halo .18). Colour stays on split bars, flow glyphs, gain and loss, kicker, Inbox count | values and amount facts masked |
| `CapsuleMeter` | variable ("today" tick), fixed (striped), fixed bills), hero (10 high) | Track `size.capsule`, `radius.pill`, `surface.track`, 1 px inner edge. Solid fill in the data colour to value ÷ limit (capped; exact amount and true % in text). "Today" tick `data.neutral.fill`, 1.5–2 px, 4 px over the track each side. No glow, no gradient. Text: "$620 of $1,200 · 52%" and the amount left | fill stays; amounts masked |
| `GoalVial` | — | Equal `size.vial` for all goals. Solid liquid in the goal colour to the exact share (capped; true % in text). % on top in `numberS` (500); name, "$39,440 of $60,000", date below. No wave, loop, glare or glow. States per 7.3 goal progress. 200%: one column | level and % stay; amounts masked |
| `SymbolCalendar` | — | Month grid, Monday first, weekday headers. Cell ≥ 48 high (target ≥ 44 × 44), `radius.m`, white 3.5% (6% when it opens the Day sheet). Day number 13/400; under it one flow glyph per event, max 3, then "+N" (`chartAxis`). Today: 1 px `text.primary` outline. Past: `text.secondary` number, no opacity. First day of a month shows the month mark. Amounts only in the spoken label, the list and the Day sheet. Legend in words. Days with payments are buttons | glyphs stay; spoken amounts masked |
| `GlyphTimeline` | — | Next 30 days, one date scale, sideways scroll (104 high, 34 pt a day). Flow glyphs; spending dot area follows the amount. Dashed line after the next income. Name and amount label per mark, never overlapping (7.1). Scroll region with focus ring and accessible name | amount labels hidden |
| `HoldingsCard` | bubbles (default, the person's choice), list, tree | Header: group menu as title (Holdings · Sectors · Markets); three view icons 44 × 44 (selected `surface.inverse` + `text.onInverse`, spoken names); filter icon 44 × 44 with a dot when on. Total line: value the filters keep (`numberS`), "share of $129,800 · N holdings" when filtered, period gain $ and % with a menu ("today ⌄" / "since bought"). Bubbles and tree: area = value now, fill `data.heat`, white labels only where they fit, key with both ends. List: two lines (`size.rowHolding`): class-colour monogram badge, symbol, value; name, gain "$ · %" with ▲ / ▼. Cash: "no return". Sold: realised gain, forces the list. Rows open the holding | list only; amounts masked; % stay |
| `FilterSheet` | — | AppSheet "Filters and sort": `label.caps` groups of 44 pt choice chips (selected `surface.inverse` / `text.onInverse`), sticky "Done" in `action.neutral.fill`. Holdings groups: Account, Asset type, Status, List: sort by, List: order, List: count. The card names every non-default choice | — |
| `DateRow` | due, lot | `dateDay` (22/400) with month in weekday style, flow glyph or colour dot, name and context line, signed amount | amounts masked |
| `FactRow` | — | Up to 3 facts: `label.caps` name, value `numberS` (≥ 400), one caption line; each can be a 44 pt link | values masked |
| `NeutralPill` | — | "was $15.49", "Due 22 Oct", "Est.": `state.estPill`, caption, `radius.pill`. Never a section or alarm colour | amounts masked |
| `BrandMark` | — | One luminous contour line #9BAFFF → #C9B6FF with a white end dot and two faint lower lines on a #0B0C0E squircle. Sources `docs/brand/app-icon.svg`, `docs/brand/launch-screen.svg` (launch: page colour and mark only). Welcome 64 pt, Lock 76 pt | — |
| `LockScreen` | — | Fixed blurred Home silhouette (no data) behind the brand mark, "Locked", one line, Unlock with Face ID, Use passcode. Face ID starts on open | no amounts |

- **No floating button over a list.** A primary action that confirms a list sits after it, in the scroll flow (ConfirmBar). A floating button only on a screen without a list; the template reserves its height at the bottom.
- **Badges:** the Inbox count badge uses `action.primary.fill` with `text.onSection`, 12 pt / 700, 20 high.
- **Focus:** every control shows `focus.ring` (2 px, offset 2).

---

## 7. Chart library (`lib/design/charts/`)

All charts are CustomPainters in a `ChartFrame`. **Charts never take raw colours, fonts or sizes.** They take a `ChartTone` (onStage, onCard, heroBackground) and data with group keys, and get colours from 2.4 through the keys. A chart never reads the section colour, except the neutral chrome (axis, grid) of `heroBackground`.

### 7.1 ChartFrame rules (every chart)

A chart without these parts does not build (lint `chart_requires_table`).

- **Label.** One accessible name: what, period, exact values in reading order. A dynamic chart keeps exact figures in a named group.
- **"Show as table".** A ChartTable with the exact values and the same rows, under a `label.caps` disclosure, in the scroll flow, with a scroll cue when wide. Exception (PREVIEW-CHART): a preview chart on a card that opens the full chart (Home net worth line, Home Next 30 days) has no table; its label keeps the exact values.
- **Scalable text.** `chartLabel` (12) and `chartAxis` (11), up to 2.0. If text does not fit, remove axis ticks between the ends, then direct labels on small marks. Axis ends and the end-point label stay. Removed labels stay in the table and label. **Open (CHART-SCALE):** the figures do not scale chart text at 200%; the build follows this rule.
- **Collision.** Labels never overlap each other or a mark. Priority: end point, largest value, others. A colliding label moves to the other side of its mark, else it is removed (kept in table and label). Overlays never resize a segment, bar or bubble.
- **Hidden state.** Shape stays on a hidden scale. Amount text hidden; dates, counts, % stay; no blank zones; label masks "$······". Area and bubble charts of amounts are not shown where a list exists (HoldingsCard).
- **Heat key.** Both ends in words and numbers ("−1.1% ... +1.1%") with ▲ / ▼.
- **Scale stated.** Every bar has a labelled axis, a labelled limit or a stated common maximum. Bars of one chart share one scale unless each states its own limit.
- **Glow.** GLOW-001 only; never on lines, areas, arcs, bars or legend marks.
- **Axis grammar (POLISH-001).** Value labels right, 40 pt gutter, short form ("$150K"), `chartAxis`. 3–5 grid lines, 1 pt, white 7% / ink 8%; base line 16% / 20%. Dates "Oct"; the year only on the first label and at a year change.
- **Line grammar.** Main series 2.25 pt; second series 1.5 pt at 70%; reference lines (average, limit, cost basis, last period) 1 pt, dash 3 3. One end dot per series.
- **Areas.** Flat fill in the line colour at 12%. No area with two or more lines; a dashed reference line counts as a line.
- **Future days.** A dotted base line, never a $0 bar.
- **Light marks.** In Obsidian Light every mark uses its Light value (2.4), 3:1 or more on page and card.
- **Motion.** One `motion.draw` per chart per session (≤ 900 ms incl. delays; Home line once a day); revisit with `motion.revisit`. No overshoot, no loop. Reduce motion: final state at once.
- **Missing data.** "Missing" or "None recorded" in words. Never a zero line for unknown data (SPEC 4.3). No interpolation across missing points.

### 7.2 Obsidian chart variants

| CHART | CLASS | DATA IN | RULES |
|---|---|---|---|
| Area line with end dot | `AreaLineChart` | one series, optional dashed reference (cost basis, money put in, last period) | Line 2.25 pt, solid, data colour. Flat area at 12%. End dot 4.5–5 pt in `data.neutral.fill` or the series colour, with `glow.mark`. Start and end labels. `heroBackground`: behind 0bHero.period, masked to 45% at the left, axis text.secondary. multi: up to 3 series on one zero-based scale (Wealth: net worth, investments, cash), legend in words |
| Period bars with average | `PeriodBarChart` | values per day or month, optional average and limit | Neutral bars: past white 24% (Light: ink equivalent); current day or month `data.neutral.fill`; mid grey when no current period; `radius.xs` top corners. Dashed average line in `text.control` with label ("AVG $303"). Optional limit line. An incomplete period is hatched and named in the label |
| Ring meter | `RingMeter` | value, limit, optional fixed flag, icon | Track `surface.track`, arc in data colour, `size.ringStroke`. Fixed bills: dashed arc. Value and "left" under the ring. Spending category grid, net worth target, Protect premiums |
| Capsule meter | `CapsuleMeter` (6.7) | value, limit, optional today share | see 6.7 |
| Glyph timeline | `GlyphTimeline` (6.7) | dated events with flow group and amount | see 6.7 |
| Symbol calendar | `SymbolCalendar` (6.7) | events per day with flow group | see 6.7 |
| Lane comparison | `LaneChart` | portfolio and an index for the period | One lane per series on one labelled % scale (e.g. 0–40%). Portfolio lane wider. Exact values beside each lane; index label under its lane. Missing periods: no lanes, "Missing" |
| Treemap | `Treemap` | items with value and signed change | Squarified, area = value now, fill `data.heat`. White labels only where they fit; small tiles named only in the label. Key with both ends. **Open (TREE-TARGETS):** tiles under 44 pt are not targets; the list view is the accessible path |
| Bubble pack | `BubblePack` | same as treemap | Only in HoldingsCard (the person's default view there). Area = value now; flat `data.heat` fill with a 1 pt inner edge, no shine; labels only where they fit; minimum diameter 50 pt; largest near the centre. Never the only view |
| Split bar | `SplitBar` | parts with group keys | Solid segments, 3 px gaps, `radius.pill` ends. Labels outside (or inside a large segment) with name, amount and share from `Percent.split`. No glow |
| Gain bars | `GainBars` | signed values from zero | Positive right in `data.signed.gain`, negative left in `data.signed.loss`, visible zero line, one unit per pixel for both signs, sign and glyph on each value |
| Goal vial | `GoalVial` (6.7) | assigned amount, target | see 6.7 |

- Every chart has goldens in dark and Light, at 1.0 and 2.0, with an empty data set, and in the hidden state.
- Add a chart type only when none of these can show the data. It follows 7.1.

### 7.3 Earlier chart classes

`LineChart`, `StepChart`, `GaugeChart`, `RibbonBar`, `CentreBars`, `LabelledDonut`, `ColumnChart`, `MonthGrid.dividends`, `MonthGrid.calendar`, `DotGrid`, `Sparkline`, `ContributionChart` and `Meter` stay until their screens are rebuilt (OB-UX-09). They take Obsidian tokens and the 7.1 rules.

- `LineChart` draws as `AreaLineChart`. `StepChart` steps on event days only (Cash flow); the lowest point is the end-point mark. `MonthGrid.calendar` → `SymbolCalendar`. `Meter.waterBowl` → `GoalVial`.
- End points, "today" ticks and colours use `data.neutral.fill` and the 2.4 palettes.
- `SplitBar` labelled geometry (DESIGN-HTML-005): 132 px height; 164 px for the primary Spending variant; 116 px for Allocation. A label overlay adds no padding, border or minimum width to a weighted segment. Check the segment-width ratio (without the fixed gap) at both text scales.
- Return comparison bars use a common labelled % scale for the period. The empty area is not a target track.
- Goal progress (DESIGN-HTML-003, applies to `GoalVial`): known zero = empty, 0%; missing amount or missing or nonpositive target = neutral unavailable, no invented 0%; above target = full, true %; negative assigned amount = signed amount with an unavailable visual. Each vial has one accessible description: goal, amount, target, percentage.

---

## 8. Content rules for components

- Copy follows SPEC.md Appendix B. No hard-coded strings; every string comes from `context.l10n`.
- Money components require a `ValueState` (real, estimated, expected, noneRecorded, missing). A bare zero for unknown data is impossible.
- Every tappable component requires a semantic label.
- Gains and losses show a sign through `ChangeText`. Colour is never the only signal.

---

## 9. Enforcement (CI fails if any rule breaks)

Custom lint rules (`custom_lint`, in `tool/lints/`) apply outside `lib/design/` unless stated:

| RULE | FORBIDS |
|---|---|
| `no_color_literals` | `Color(…)`, `Colors.*`, hex strings |
| `no_text_style` | `TextStyle(…)`, `.copyWith(fontSize/fontWeight/…)`, `GoogleFonts.*` |
| `no_raw_spacing` | `EdgeInsets` / `SizedBox` / `Padding` with number literals (use `Space.*` widgets or tokens) |
| `no_raw_decoration` | `BoxDecoration`, `BoxShadow`, `BorderRadius`, `Border`, `ShapeDecoration` |
| `no_raw_containers` | `Container`, `DecoratedBox`, `Material` with styling arguments |
| `no_material_buttons` | `ElevatedButton`, `TextButton`, `OutlinedButton`, `IconButton` (Material), `Chip` (Material) |
| `no_raw_icons` | `Icon(Icons.*)`, any icon not from AppIcons |
| `no_add_icon` | `AppIcons.add` outside AppTabBar and TopBar.addAction |
| `no_number_format` | `NumberFormat`, `toStringAsFixed`, string interpolation of money values |
| `one_control_row` | more than one `SegmentedControl` / `ChipRow` / `PeriodControl` in a screen widget (forms excluded) |
| `no_custom_paint` | `CustomPaint` / `CustomPainter` outside `lib/design/charts/` |
| `min_text_size` | a style below 13 pt, except `tabLabel`, `weekday`, `chartLabel` (12) and `chartAxis` (11). Also runs on `lib/design/`. The only scaled exemption is AddWidgetPreview, and only with its "Show full size" control (6.7) |
| `no_gradient_on_data` | a `Gradient` or `ShaderMask` on a data mark, body text or a kicker. Allowed only for the page spotlight, metal card and rim, scroll-edge fades, selected fill and hero number fill (14.1). Also runs on `lib/design/charts/` |
| `no_infinite_animation` | `repeat()`, a looping `AnimationController` or implicit animation, a chart draw-in above 900 ms total, an overshooting curve on a data mark, a `Duration(` literal outside `lib/design/motion/`. Every animation reads "reduce motion" |
| `chart_requires_table` | a chart without `ChartFrame`, a semantic label and a ChartTable; `ChartFrame(preview: true)` needs only the label with the main values and a link to the full chart and table (PREVIEW-CHART) |
| `no_glow_except_endpoint` | `ImageFilter.blur`, `MaskFilter.blur`, a non-black `BoxShadow`, or a shadow on a chart path, bar, arc, icon, pill, badge, chip, selected state or button. Allowed: `glow.mark` on an end-point mark (radius ≤ dot + 6 pt, opacity ≤ 0.4), the black `elevation.*` shadows, blur only in `elevation.nav` and `elevation.sheet` (sheets, menus, toast). Also runs on `lib/design/` |
| `hidden_mode_semantics` | a money widget without a hidden state, or a semantic label with an amount while amounts are hidden. Hidden names mask amounts as "$······" (currency mark kept); dates, counts, % stay |

Other checks:

- `tool/check_contrast.dart`: every text/background pair in both themes, every section: text 4.5:1, essential non-text marks 3:1 (chart marks, icons, focus ring, control edges). It composites `surface.page` + spotlight, then each stop of `surface.glass`, then `surface.tile`, then the text or mark. Text on `action.primary.fill` is checked on both stops. White labels on `data.heat` are checked at k = 60%.
- `tool/check_tokens.dart`: `tokens.g.dart` matches `tokens.json`; no unused tokens; every token has dark and Light values.
- Goldens for every component, chart and final screen (SPEC.md 16.2).
- SPEC.md 16.3 interface checks run on all screen goldens.

---

## 10. How to style something new

Stop at the first step that works.

1. **Find it** in the gallery and section 6.
2. **Compose it** (for example AppCard + SectionTitle + ListGroup of SelectRows).
3. **Add a variant** in `lib/design/components/`, tokens only, with gallery entry and goldens.
4. **Add a token** (rare): semantic, dark and Light values, in `tokens.json`; regenerate; use only in `lib/design/`; document in section 2.
5. **Add a component** (last): tokens and components only, enum variants, semantic label, l10n, gallery, goldens; document in section 6.
6. **Never** style inside a feature.

**PR checklist (every UI PR):** use the AGENTS.md 8 checklist, and add:

- [ ] Section set by the route; no colours passed by hand.
- [ ] New or changed components in the gallery with goldens (dark and Light, 1.0 and 2.0, hidden state).
- [ ] Screen matches its Obsidian figure and its `docs/screens/SCREENS.md` entry: dark at 1.0, then Light and 2.0.
- [ ] No glow except end-point marks; no gradient on data; no looping motion.

---

## 11. Mapping from figures to components

| IN A FIGURE | BUILD WITH |
|---|---|
| Kicker, thin large number, side figures | `0bHero` (with chips and a faint line: `0bHero(period)` + `PeriodChips` + `AreaLineChart(heroBackground)`) |
| Metal panel, title above / with a chart | `GlassCard` / `GlassCard(stage)` + a section 7 chart |
| Header pill row (Calendar · Goals · Protect · Tax) | `SegmentTabs` |
| Sideways tiles (Quick look) / type tiles with "None recorded" | `IconTileGrid(quickLook)` / `IconTileGrid(types)` |
| Capsule with "today" tick / tall vials / ● ◆ ★ month grid / 30-day strip | `CapsuleMeter` / `GoalVial` / `SymbolCalendar` / `GlyphTimeline` |
| Holdings as bubbles, list or treemap; chip-group sheet | `HoldingsCard`; `FilterSheet` |
| Large day number row / label–value facts / grey pill | `DateRow` / `FactRow` / `NeutralPill`, `EstLabel` |
| Name, grey line, value, chevron / grey "None recorded" row | `SelectRow` / `BalanceRow(faded)` + `StateValue.noneRecorded` |
| Bottom sheet / centre pop-up / pill with Undo | `AppSheet` / `AppDialog` / `AppToast` |

---

## 12. Obsidian dark and Obsidian Light

- Obsidian Light uses the same role tokens (2.2–2.4) with designed values, not a computed map. Section 2 is the source. Designed differences:
  - Page #ECEBE7; white-metal cards with a polished silver rim (`surface.glass`, `surface.rim`, `elevation.glass`).
  - Deeper section fills (2.3), so white `text.onSection` reaches 4.5:1 or more.
  - The ink role is split (2.2).
  - Data text uses Light text tints; marks use Light mark values (2.4, DATA-LIGHT).
  - Hero number fill: dark #FFFFFF → #9C9EA8, Light #16171B → #4B4E57 (both stops 7:1 or more on the page).
- Both themes are checked in the gallery and goldens. If a screen fails in one theme, fix **tokens**, never a screen.

---

## 13. Wide screens (tablets, Mac, Windows — v2, prepared in v1)

Templates handle width. Features never check the platform or the width.

### 13.1 Window size classes

| CLASS | WIDTH | NAVIGATION | CONTENT |
|---|---|---|---|
| compact | under 600 | floating tab bar (phones) | one column |
| medium | 600–1023 | side rail with the 4 sections and Add | one column, max width 640, centred |
| expanded | 1024 and over | sidebar with sections, sub-sections, Inbox, Settings | list and detail side by side (list 360–420, detail flexible), max content width 1200 |

- Tokens do not change between classes; only templates change the arrangement.
- On expanded, TabRootScreen is the list pane and DetailScreen opens in the detail pane.
- On medium and expanded, sheets become centred dialogs (max width 520).
- 0bHero and GlassCard keep their style; charts get more width, same rules.

### 13.2 Pointer and keyboard

- Every tappable component has a hover state (token surface tint) and `focus.ring` (2 px, offset 2).
- Tab order follows visual order. Escape closes sheets and dialogs. Enter confirms the primary button.
- Shortcuts (registered by templates): N new expense, ⌘/Ctrl+K search, ⌘/Ctrl+I Inbox, ⌘/Ctrl+1–4 sections, ⌘/Ctrl+Z undo.
- Minimum window: 800 × 600 on Mac and Windows.
- Dropping a statement on any window opens the import flow.

---

## 14. Visual guide

Agents have no design tool. They build from the Obsidian figures in contour-design.html (dark and Light, 375–390 pt wide), this section and `docs/screens/SCREENS.md`. Where a figure and section 2 disagree (for example a 1.2 s capsule grow, a fade on the glass, Light loss text #C2263A), section 2 wins.

### 14.1 The look in words

- **Light from data.** Near-black page (#040405; Light #ECEBE7) with a neutral spotlight at the top. Content on metal GlassCards (Light: white metal, silver rim). No backdrop blur on scrolling content.
- **One luminous hero.** One 0bHero per screen: small kicker in `section.text`, one thin number with a white-to-silver fill, at most two side figures. Everything below is smaller.
- **Section colour on chrome only.** Home blue-violet, Spending coral-magenta, Income sky-blue, Wealth gold, Plan amber-orange (2.3). Never on data or a signed change.
- **Data colour from 2.4 only.** Gain/loss with sign and ▲ / ▼. Flow groups by shape (● ◆ ★). One key has one colour in a chart and its rows.
- **Labels, not explanations.** Keep metric, currency, date or period and value state beside the number. A FactRow can replace a sentence. Do not repeat a value in hero, sentence and legend. Formulas, sources and notes sit behind named disclosures ("Show as table", (i)).
- **Quiet lists.** Rows: icon or colour mark, name, one grey line, value. At large text, labels wrap and amounts move under them. Tables keep full amounts in a scroll region with a scroll cue.
- **One tab bar.** Floating bar (`elevation.nav`, blur allowed), four sections and one Add in `action.neutral.fill`. At large text it reflows and keeps one Add.
- **No decoration.** No images or illustrations. The only patterns are data marks.
- **Bounded gradient rule.** Gradients only for: (a) the page spotlight, metal card and rim, scroll-edge fades, all static; (b) `action.selected.fill`, with `text.onSection` at 4.5:1 or more on both stops; (c) the hero number fill, only if both stops reach 7:1 on the page (dark #FFFFFF → #9C9EA8; Light #16171B → #4B4E57). Lint `no_gradient_on_data`.
- **Calm motion and glow.** No loop, pulse, wave, shimmer or spinner (2.10). Glow only on end points (GLOW-001).

### 14.2 Anatomy of the templates

Section 5 lists the fixed parts. Visual order:

- **TabRootScreen:** spotlight page → ScreenHeader (headings for screen readers; up to three 44 pt buttons right: Hide amounts, Inbox, Settings; or Search, Tools) → 0bHero with optional PeriodChips and background AreaLineChart → GlassCards, 14 pt gaps, titles above (CARD-TITLE-OUT) → WidgetEditBar → 120 pt bottom space.
- **DetailScreen:** DetailHeader → 0bHero(detail) (two stacked side figures) → GlassCards. Keeps the parent's tab bar.
- **FormScreen:** Close (X) and optional "Save" → fields with labels above → one full-width 52 pt primary button at the bottom.
- **Sheet:** scrim → `surface.sheet`, `radius.sheet` (28) top → grabber, titleDialog, `label.caps` group legends, sticky "Done" in `action.neutral.fill`.
- **AppDialog:** centred `surface.sheet` card, 28 pt from the sides: title, `text.secondary` body, primary button, ghost button.
- **AppToast:** `surface.sheet` pill above the tab bar, one "Undo" in `action.neutral.fill`.

### 14.3 Figure and screenshot files

- The Obsidian figures in contour-design.html are the reference for every screen in `docs/screens/SCREENS.md`.
- No PNG screen files are kept. Use the prototype (All screens or Grid) in dark and Light, with sheets and dialogs open.
- Reference-only screens (X10a, X10b, X10c, TypeA–TypeG) are not built.

### 14.4 Screen by screen

Every screen (90 ids in 75 screen groups, Start to Settings) is described in [docs/screens/SCREENS.md](../screens/SCREENS.md): template, section, blocks in order, labels and sample values. Its top part lists the rules shared by all screens. This file owns components; SPEC.md owns behaviour.
