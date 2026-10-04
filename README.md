# Tournée Calendriers

App firefighters use to mark the houses visited during the yearly calendar round, shared live
across a team. Flutter + Riverpod, Android first. The UI is in French.

- Product and architecture: [`docs/PLAN.md`](docs/PLAN.md)
- Commands and conventions: [`CLAUDE.md`](CLAUDE.md)

## Features

Temporary M1 start screen (until the map arrives in M3):

- « Mes rues »: the streets on the phone with their progress, a filter that ignores accents
  and case; works offline.
- « Importer des rues »: find a commune by name (geo.api.gouv.fr), tick some of its streets
  (national address base, BAN) and import them with their house numbers. Needs the network
  once; streets already imported keep their marks.

Street screen (« Rue »):

- Odd numbers on the left, even on the right, scrolling together (one column when the street
  has one side only); counts « done/total · ✗ · ↻ » and a progress bar.
- A tap cycles a house ○ → ✓ → ✗ → ○ with a light vibration and a screen-reader announcement;
  « Annuler » for 4 s undoes the last tap. A note shows as a small dot on the tile.
- « Masquer faits » hides the done houses, remembered per street on the phone.
- Works offline, cold start included: marks are stored on the phone.
- Not yet: hold a house for its details, open a building's grid, edit mode (✏ opens an empty
  screen).
