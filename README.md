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
- A tap cycles a house ○ → ✓ → ✗ → ↻ → ○ (à faire, fait, personne, repasser) with a light vibration and a screen-reader announcement;
  « Annuler » for 4 s undoes the last tap. A note shows as a small dot on the tile.
- « Masquer faits » hides the done houses, remembered per street on the phone.
- Hold a house for its sheet (« Fiche maison »): status « À faire | Fait | Personne | Repasser »,
  « Quand repasser ? » (greyed unless « Repasser »), a note (200 characters at most, with the privacy hint),
  and when it was last changed. Each control is stored at once; the tile follows.
- « Transformer en immeuble… » in the sheet describes a building (« Décrire l'immeuble »):
  staircases, floors (RdC–5e, or « Inconnus »), doors per floor, door labels « 51, 52… |
  5A, 5B… | Libres », with a live preview.
- Tap a building for its grid (« Immeuble »): floors from the top down, four doors a row,
  a staircase control when there are several, « ◐ done/total » for the whole building. A tap
  cycles a door (vibration, announcement, « Annuler » for 4 s); a hold opens the door's
  sheet. « Modifier les étages » lays it out again, keeping the marks of the doors that stay
  (and asks before losing marked ones); « Note · Repasser » sets the building's own.
- Edit mode (✏, « Modifier la rue »): rename the street, ✕ removes a number at once with
  « Annuler » (asks first when it has marks; it goes to the Corbeille with them), « + numéros »
  adds a number, a list or a range (`12bis, 21-25`) with a live preview, each on its side
  (numbers in the Corbeille come back with their marks). Tap a number to change it
  (`3` → `3bis`), make it a building, lay a building out again or turn it back into a house.
  « Supprimer la rue » sends the street to the Corbeille.
- « Ajuster les portes » (a building's number in edit mode): floor by floor, « + » adds a
  door, ✕ removes one (with « Annuler »; asks first when it has a mark), a tap renames it
  (« Gauche », « Droite » on every floor). The other doors keep their marks.
- Works offline, cold start included: marks are stored on the phone.
- Not yet: the Corbeille screen (M2), « Ne plus la faire » (M3).
