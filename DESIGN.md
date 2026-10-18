# Contour — Design Language for Implementation (DESIGN.md)

**Version 2.2 "Obsidian" core — 15 October 2026.** Companion to SPEC.md (section 7).

- This file is the **short core**: the rules a builder must know first.
- Full detail (every token value, component spec, chart rule and lint rule): `docs/design/DESIGN_REFERENCE.md`. It uses the same section numbers. A citation "DESIGN 2.5" is in section 2.5 of both files.
- Screens: `docs/screens/SCREENS.md`. Visual reference: the Obsidian figures in `contour-design.html`.
- The look is **Obsidian** (DESIGN-SYNC-001) with METAL-RIM-001, CARD-TITLE-OUT, POLISH-001, MOTION-002, WIDGETS-001…004, HOME-QUICKLOOK and the REVIEW-004 z fixes. NUM-001…003, UI-001 and DESIGN-HTML-002…010 still apply where they define numbers, words and states.

## 0. The laws

1. **One place.** Colours, type, sizes, spacing, radii, shadows, icons and motion live only in `lib/design/`.
2. **Reuse before you build.** Use a component, else compose, else add a variant. A new component is the last option.
3. **Meaning, not values.** Ask for a role (`tokens.color.text.secondary`, `tokens.space.m`, `AppText.numberHero`), never a value.
4. **Section from the route.** Components read the section from the theme. Never pass a section colour by hand.
5. **Not in the gallery = does not exist.** Every component and variant has gallery entry and goldens: dark and Light, text scale 1.0 and 2.0, hidden-amount state where it shows money.
6. **Light comes from data, not decoration.** Metal cards on a near-black page; one hero number per screen; section colour on chrome only; data colours only from 2.4; glow only on end-point marks (GLOW-001); solid fills end at the true value; gradients only under the bounded rule (14.1).

- Precedence: this file wins over a screen design. SPEC.md wins on content; this file wins on style.
- Full detail: docs/design/DESIGN_REFERENCE.md §0.

## 1. Where things live

| FOLDER IN LIB/DESIGN/ | CONTENTS |
|---|---|
| tokens/ | tokens.json (single source); tokens.g.dart (generated, never edit) |
| theme/ | app_theme.dart, section.dart (Section, SectionScope) |
| typography/, icons/ | AppText.*, AppIcons.* (the only styles and icons) |
| components/, charts/, layout/, format/ | widgets (6), chart painters (7), templates (5), formatters (4) |
| gallery/ | component gallery (debug only) |

- Goldens: test/golden/design/.
- Feature code imports only package:contour/design/design.dart.
- Feature code never uses Container, DecoratedBox, BoxDecoration, TextStyle, EdgeInsets with numbers, BorderRadius, BoxShadow or Color.
- Full detail: docs/design/DESIGN_REFERENCE.md §1.

## 2. Tokens

- tokens.json is the only source. dart run tool/gen_tokens.dart generates tokens.g.dart. Values are logical pixels.
- Every colour token has a dark and a designed Light value. Where a figure differs from section 2, section 2 wins.
- Text uses text.primary or text.secondary only (no tertiary grey). Text needs 4.5:1; essential non-text marks need 3:1.

### Key tokens

| TOKEN | OBSIDIAN DARK | OBSIDIAN LIGHT |
|---|---|---|
| color.surface.page | #040405 + neutral spotlight at the top | #ECEBE7 + white radial at the top |
| color.surface.glass (metal card) | #18191D → #0C0D0F → #0A0A0C at 160°, no blur | white metal #FFFFFF → #F4F4F2 → #EFEFEC |
| color.surface.rim | 1 pt, white 38% → 7% → 3% → 20% | polished silver 1.25 pt |
| color.surface.tile | white 3.5% + inset top 1 pt white 6% | ink 3.5%, no edge |
| color.text.primary | #F4F4F6 | #16171B |
| color.text.secondary | #A3A6AF | #5A5D67 |
| color.text.control | #C9CBD3 | #3C3F48 |
| data.signed.gain ▲ | #3DF2B0 | #076B49 |
| data.signed.loss ▼ | #FF7A8A | #C8324B |

- The rim is only on a top-level GlassCard. Never on tiles, rows or controls. No card in a card.

### Section colours (chrome only), gradientStart → gradientEnd

| SECTION | OBSIDIAN DARK | OBSIDIAN LIGHT |
|---|---|---|
| Home (also Inbox, Settings) | #6F8BFF → #B26BFF | #4A55CC → #7A35C4 |
| Spending | #FF7A59 → #FF3D8B | #B63D1C → #B81E5C |
| Income | #5CD3FF → #4F8BFF | #0A6BA2 → #2F5BD8 |
| Wealth (also Investments, What you owe) | #EBD08A → #D9A441 | #7F5C0E → #7A5312 |
| Plan (Calendar, Goals, Protect, Tax) | #F5C46A → #FF8A4C | #9A5309 → #B4441A |

- section.text = the start colour. text.onSection = #0B0C10 dark, #FFFFFF Light.

### Type (Inter; Inter Display for the hero; tabular figures on every number)

| STYLE | SIZE / WEIGHT | USE |
|---|---|---|
| numberHero.light | 64 / 200 (fits down to 40) | the one hero number |
| titleGroup | 20 / 600 | card titles, above the card |
| body | 15 / 400 | default text, row names |
| caption | 13 / 400 | minimum size |
| button | 17 / 600 | primary buttons |

- Minimum size 13. Exceptions only: 12 (tabLabel, weekday, chartLabel) and 11 (chartAxis).
- Weights 200–300 only at 40 pt or more. Amounts below 18 pt use 500.
- No copyWith(fontSize: …) outside lib/design/. All styles follow the system text scale up to 2.0, chart text included.

### Space, radius, size, motion

- space.page = 20 on every screen. Templates apply the gaps between blocks; features add no gaps.
- Radius: s 8, m 12, tile 18, card 26, sheet 28, pill 999.
- size.touchMin = 44.
- Motion (MOTION-002): plays once, explains a change, never loops, never counts up, never celebrates, same for gain and loss; screen complete by 700 ms; reduce motion sets all motion to 0.
- Icons: Lucide through AppIcons.* only. AppIcons.add only on the tab bar Add (and one header button on screens without the tab bar).

Full detail (all palettes, data colours, every type style, space, size, elevation, motion, icons): docs/design/DESIGN_REFERENCE.md §2.

## 3. Theme and sections

- Obsidian dark is the default. Obsidian Light is the other theme. SPEC.md owns the theme switch.
- AppTheme.dark() / AppTheme.light() build ThemeData and ContourTokens (context.tokens). Override Material defaults once in AppTheme.
- The router sets SectionScope per route. Components read context.section. Sheets and dialogs inherit the opener's section.
- The section sets only chrome. Data components never read the section colour.
- Full detail: docs/design/DESIGN_REFERENCE.md §3.

## 4. Number and text formatting

- All amounts, percentages, changes and dates go through `lib/design/format/` (MoneyText, ChangeText, PercentText, DateText, EstLabel, SourceLabel, StateValue, FitNumber). Never format a number in a feature.
- Every value passes through StateValue. Unknown never shows as zero ("None recorded", "Missing since [date]", "Expected").
- A change always has a sign (+/−); charts and pills also show ▲ / ▼. Splits use Percent.split(...).
- Hidden amounts show "$•••••" (currency mark stays) in text and accessible names. Dates, counts and percentages stay.
- Full detail: docs/design/DESIGN_REFERENCE.md §4.

## 5. Layout templates (every screen uses one)

- TabRootScreen — tab roots (Home, Spending, Wealth, Plan); Inbox is a DetailScreen with the tab bar: header, one ObHero, cards, WidgetEditBar, tab bar.
- DetailScreen — every screen opened from another: DetailHeader, one ObHero, cards.
- FormScreen — add and edit forms: Close, optional "Save", fields, bottom primary button.
- CaptureScreen — camera, QR, voice.
- AppSheet — sheets, fit content up to 90%.
- AppDialog — confirmations.
- AppToast — undo and confirmations.
- Compact title with blur when the hero scrolls away; a 28 pt page fade above the tab bar; WidgetEditBar at the end of every tab screen.
- **One ControlRow per screen** (forms excluded). SegmentTabs in the header is navigation, not a control row. DECISION-PENDING: CONTROL-ROW-SCOPE (card-level controls change only their own card).
- **One add control per screen.** Screens with the tab bar refuse a header add button.
- Block order follows SPEC.md 4.6.
- Full detail: docs/design/DESIGN_REFERENCE.md §5.

## 6. Components

- Variants are enums. Do not wrap a component to change its look; add a variant. New screens use the Obsidian components.
- Every money component has a hidden state. Every component has a semantic label and focus.ring.
- No floating button over a list: ConfirmBar sits after the list, in the scroll flow.

| AREA | COMPONENTS |
|---|---|
| Surfaces | Slab, AppCard, StatBox, StatusBanner |
| Text | ScreenTitle, TopBar, SectionTitle, Sentence, Note, TextLink |
| Buttons and controls | AppButton (primary, neutral, ghost, soft, destructive), IconButton, AddButton, SegmentedControl, ChipRow / Chip, PeriodControl, ToggleRow, SelectRow, Checkbox, InfoButton, SortButton |
| Forms | AppField, AmountInput, Keypad, PillPicker, SplitEditor, FormGrid |
| Rows and lists | PaymentRow, BalanceRow, HoldingRow, TransactionRow, ReadyRow, FactCard, ProgressRow, KeyValueList, AppTable, ListGroup, EmptyState |
| Feedback | AppToast, UndoBar, AppDialog, ConfirmBar, LoadingValue |
| Obsidian | ObHero, GlassCard, ScreenHeader, DetailHeader, SegmentTabs, PeriodChips, IconTileGrid, CapsuleMeter, GoalVial, SymbolCalendar, GlyphTimeline, HoldingsCard, FilterSheet, DateRow, FactRow, NeutralPill, BrandMark, LockScreen |
| Widgets | WidgetSlot, WidgetEditBar, AddWidgetSheet, TileListSheet |

- AppButton destructive is filled neutral grey, never the loss hue or a section colour (DESTRUCTIVE-ROLE).
- Full detail (variants, anatomy, hidden state): docs/design/DESIGN_REFERENCE.md §6.

## 7. Charts (`lib/design/charts/`)

- All charts are CustomPainters in a ChartFrame. They take a ChartTone and data with group keys; never raw colours, fonts or sizes. A chart never reads the section colour.
- **Label and table.** One accessible name with exact values, and "Show as table" (ChartTable). Exception PREVIEW-CHART: a preview chart that opens the full chart has the label only.
- **Scalable text.** chartLabel 12 and chartAxis 11, up to 2.0. Remove middle ticks before end labels. Labels never overlap.
- **Axis grammar.** Value labels right, 40 pt gutter, short form ("$150K"), 3–5 grid lines.
- **Line grammar.** Main series 2.25 pt; second series 1.5 pt at 70%; reference lines 1 pt, dash 3 3; one end dot per series.
- **Areas.** Flat fill at 12%. No area with two or more lines (a dashed reference line counts).
- **End dot and glow.** GLOW-001: one static halo on end-point marks only. Never on lines, areas, arcs, bars or legend marks.
- **Period bars are neutral.** Past bars white 24%; current bar data.neutral.fill.
- **Light marks.** In Obsidian Light every mark uses its Light value (3:1 or more).
- **Draw-in motion.** One draw per chart per session, ≤ 900 ms, no overshoot, no loop; reduce motion shows the final state.
- **Missing data** in words. Never a zero line for unknown data. No interpolation.

Chart classes: AreaLineChart, PeriodBarChart, RingMeter, CapsuleMeter, GlyphTimeline, SymbolCalendar, LaneChart, Treemap, BubblePack, SplitBar, GainBars, GoalVial. Earlier classes stay until their screens are rebuilt (7.3).

Full detail: docs/design/DESIGN_REFERENCE.md §7.

## 8. Content rules

- **Data only.** No advice, warnings or judgements. Copy follows SPEC.md Appendix B; every string comes from `context.l10n`.
- Money components require a ValueState. A bare zero for unknown data is impossible.
- Every tappable component has a semantic label. Gains and losses show a sign through ChangeText; colour is never the only signal.
- Full detail: docs/design/DESIGN_REFERENCE.md §8.

## 9. Enforcement (CI fails if any rule breaks)

Custom lint rules (`tool/lints/`):

- `no_color_literals` — no colour literals.
- `no_text_style` — no TextStyle or font copyWith.
- `no_raw_spacing` — no number literals in spacing.
- `no_raw_decoration` — no raw decoration, shadow, radius or border.
- `no_raw_containers` — no styled Container, DecoratedBox, Material.
- `no_material_buttons` — no Material buttons or chips.
- `no_raw_icons` — icons only from AppIcons.
- `no_add_icon` — AppIcons.add only in AppTabBar and TopBar.addAction.
- `no_number_format` — no number formatting outside `lib/design/format/`.
- `one_control_row` — one control row per screen.
- `no_custom_paint` — painters only in `lib/design/charts/`.
- `min_text_size` — no style below 13 pt, except 12 and 11 as in 2.5.
- `no_gradient_on_data` — gradients only under the bounded rule (14.1).
- `no_infinite_animation` — no loop, no draw-in above 900 ms, no overshoot on data, no Duration( literal outside `lib/design/motion/`.
- `chart_requires_table` — ChartFrame, label and ChartTable (PREVIEW-CHART: label only).
- `no_glow_except_endpoint` — glow only on end-point marks.
- `hidden_mode_semantics` — every money widget has a hidden state.

- Other checks: tool/check_contrast.dart, tool/check_tokens.dart, goldens (SPEC.md 16.2), SPEC.md 16.3 interface checks.
- Full detail (scope and exact forbidden code): docs/design/DESIGN_REFERENCE.md §9.

## 10. How to style something new

Stop at the first step that works.

1. **Find it** in the gallery and section 6.
2. **Compose it** from components.
3. **Add a variant** in `lib/design/components/`, with gallery entry and goldens.
4. **Add a token** (rare): semantic, dark and Light values, in tokens.json; regenerate.
5. **Add a component** (last): tokens only, enum variants, semantic label, l10n, gallery, goldens.

- **Never** style inside a feature.
- Full detail and the UI PR checklist: docs/design/DESIGN_REFERENCE.md §10.

## 11. Mapping from figures to components

- Use the table in the reference to find the component for each element of a figure (for example kicker and large number = ObHero; metal panel = GlassCard).
- Full detail: docs/design/DESIGN_REFERENCE.md §11.

## 12. Obsidian dark and Obsidian Light

- Light uses the same role tokens with designed values, not a computed map. If a screen fails in one theme, fix **tokens**, never a screen.
- Full detail: docs/design/DESIGN_REFERENCE.md §12.

## 13. Wide screens (v2, prepared in v1)

- Templates handle width. Features never check the platform or the width. Every tappable component has a hover state and focus.ring.
- Full detail (size classes, keyboard shortcuts): docs/design/DESIGN_REFERENCE.md §13.

## 14. Visual guide

- **Obsidian.** Near-black page (Light #ECEBE7). Content on metal GlassCards. No images or illustrations.
- **Metal rim.** Each top-level card has a thin rim (Light: polished silver). No rim on tiles, rows or controls.
- **Neutral spotlight.** One neutral spotlight at the top of the page. No section glow.
- **Titles above cards.** Card title and meta sit above the card (CARD-TITLE-OUT).
- **Monochrome Home.** Home tiles, capsules and hero line are neutral; colour stays on split bars, flow glyphs, gain and loss, the kicker and the Inbox count.
- **Calm motion.** No loop, pulse, wave, shimmer or spinner. Glow only on end points.
- **Bounded gradients.** Only the page spotlight, metal card and rim, scroll-edge fades, action.selected.fill and the hero number fill.
- Every screen is in `docs/screens/SCREENS.md`. Where a figure and section 2 disagree, section 2 wins.
- Full detail (template anatomy, figure files): docs/design/DESIGN_REFERENCE.md §14.
