# Screen mockups

Source of the visual mockups for `docs/PLAN.md` §5, one `.dc.html` file per screen
(`Main.dc.html` is the Street screen). `Start.dc.html` (« Mes rues ») and `Import.dc.html`
(« Importer des rues ») are **temporary M1 screens** (PLAN §5.0), replaced by Accueil in M3.
`Doors.dc.html` is « Ajuster les portes » (PLAN §5.7), opened from « Gérer l'immeuble » under a
building's grid (`Building.dc.html`). All copy is French, as in the app. Live canvas: https://claude.ai/artifact/7ym7Qvi5Xpp8VwEDnyn5dL

Status: **awaiting approval**. Once approved, these are the visual reference for the `ui/` code:
the colours, type, spacing and status treatments below are the design tokens.

| Token | Value | Use |
|---|---|---|
| Ground | `#F3F1EC` | screen background |
| Surface | `#FFFFFF` | cards, sheets, to-do tiles |
| Ink | `#1B1F24` | text |
| Muted | `#4A5058` | secondary text |
| Line | `#CFC9BD` / `#E2DED5` | borders / dividers |
| Accent | `#B3261E` | primary buttons |
| Done | `#1E6B47` bg, white text, `✓` | |
| Nobody home | `#F2B33D` bg, ink text, `✗` | |
| Come back | `#D6E6F5` bg, `#1D4E7A` text, `↻` | |
| Building partial | `#EFE9DD` bg, dashed border, `◐ n/m` | |
| Map: street faite | `#1E6B47` line | |
| Map: street en partie | `#E0A21B` line | |
| Map: street à faire | `#2F5DA8` line | |
| Map: street libre | `#6B7078` dashed line | |
| Map: selected road | `#1B1F24` casing, white core | |
| Fonts | Atkinson Hyperlegible (text), Barlow Condensed (numbers, titles) | |
