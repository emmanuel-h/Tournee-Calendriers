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

The street screen itself comes next (it opens as an empty screen with the street's name).
