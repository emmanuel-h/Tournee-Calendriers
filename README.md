# Tournée Calendriers

App firefighters use to mark the houses visited during the yearly calendar round, shared live
across a team. Flutter + Riverpod, Android first. The UI is in French.

- Product and architecture: [`docs/PLAN.md`](docs/PLAN.md)
- Commands and conventions: [`CLAUDE.md`](CLAUDE.md)

## Features

Temporary M1 start screen (until the map arrives in M3):

- « Mes rues »: the streets of the open tournée, shared live with the team (Firestore), or
  the streets on the phone while no tournée is open; their progress, a filter that ignores
  accents and case; works offline.
- With a tournée open, a card offers the streets kept on the phone: « Les ajouter à la
  tournée » moves them with their marks (once per tournée; a street the tournée already has
  is skipped), « Plus tard » hides the card until the next launch.
- « Importer des rues »: find a commune by name (geo.api.gouv.fr), tick some of its streets
  (national address base, BAN) and import them with their house numbers, into the open
  tournée (or the phone). Needs the network once; streets already imported keep their marks.
- Top bar: the open tournée (« Tournée 49 · 2026 » over its centre de secours) opens « Mes
  tournées », to switch tournée (the app reopens the last one at launch, offline too); 👥
  opens Équipe (a dot while a join request waits); ⚙ opens Paramètres: first name, « Mes tournées », theme (Système, Clair, Sombre),
  confidentialité, version and licences, data credits. Creating or joining a tournée comes
  with the onboarding screens.
- Équipe (👥): the join code and its QR code, « Partager », « Nouveau code » (creator), the
  requests to join with « Accepter » / « Refuser » (any member), the members with « Retirer »
  (creator), the Corbeille, « Quitter la tournée » / « Supprimer la tournée » (creator).
  Answering, removing and leaving work offline; a new code and deleting need the network.
- Corbeille (from Équipe): the deleted streets and numbers, who deleted them and when, and
  « Restaurer », which brings them back with their marks.
- « ☁ Modifications de 3 rues en attente d'envoi » above « Importer des rues » while marks
  made offline in the open tournée have not reached the server yet.

Street screen (« Rue »):

- Odd numbers on the left, even on the right, scrolling together (one column when the street
  has one side only); counts « done/total · ✗ · ↻ » and a progress bar.
- A tap cycles a house ○ → ✓ → ✗ → ↻ → ○ (à faire, fait, personne, repasser) with a light vibration and a screen-reader announcement;
  « Annuler » for 4 s undoes the last tap.
- « Masquer faits » hides the done houses, remembered per street on the phone.
- Hold a house for its sheet (« Fiche maison »): status « À faire | Fait | Personne | Repasser »,
  « Quand repasser ? » (greyed unless « Repasser », 20 characters at most) and when it was
  last changed. No free note: too likely to hold personal data, so the app keeps none (notes
  stored by an earlier version are erased). Each control is stored at once; the tile follows.
- « Transformer en immeuble… » in the sheet describes a building (« Décrire l'immeuble »):
  staircases, floors (RdC–5e, or « Inconnus »), doors per floor — the same for every staircase,
  or each its own (« Même chose pour chaque escalier » unticked) —, door labels « 51, 52… |
  5A, 5B… | Libres », with a live preview.
- Tap a building for its grid (« Immeuble »): floors from the top down, four doors a row,
  a staircase control when there are several, « ◐ done/total » for the whole building. A tap
  cycles a door (vibration, announcement, « Annuler » for 4 s); a hold opens the door's
  sheet. « Gérer l'immeuble » holds every change to the building: « Modifier les étages » lays
  it out again, keeping the marks of the doors that stay (and asks before losing marked ones),
  « Modifier les portes », and « Changer en maison » (asks first when doors have marks;
  « Annuler » brings them back). « Repasser » sets the building's own.
- Edit mode (✏, « Modifier la rue »): rename the street, ✕ removes a number at once with
  « Annuler » (asks first when it has marks; it goes to the Corbeille with them), « + numéros »
  adds a number, a list or a range (`12bis, 21-25`) with a live preview, each on its side
  (numbers in the Corbeille come back with their marks). Tap a number to change it
  (`3` → `3bis`), make it a building, or open a building's grid (« Ouvrir l'immeuble »).
  « Supprimer la rue » sends the street to the Corbeille.
- « Modifier les portes » (« Gérer l'immeuble » under the grid): floor by floor, « + » adds a
  door, ✕ removes one (with « Annuler »; asks first when it has a mark), a tap renames it
  (« Gauche », « Droite » on every floor). The other doors keep their marks.
- Works offline, cold start included: marks are kept on the phone (Firestore's cache for a
  tournée) and sent to the team when the network is back.
- Not yet: « Ne plus la faire » (M3).
