# Tournée Calendriers

App firefighters use to mark the houses visited during the yearly calendar round, shared live
across a team. Flutter + Riverpod, Android first. The UI is in French.

- Product and architecture: [`docs/PLAN.md`](docs/PLAN.md)
- Commands and conventions: [`CLAUDE.md`](CLAUDE.md)

## Features

Onboarding:

- « Bienvenue » on a phone that holds nothing yet: the first name, then « Rejoindre une
  tournée » (and « Créer une tournée » for an admin), disabled until a name is typed;
  « Identifiant de l'appareil » with a copy button at the bottom. A phone with streets of
  its own opens on « Mes rues » as before.
- « Nouvelle tournée »: the centre de secours picked from the known ones as you type (or
  added), its communes (one or more, searched on geo.api.gouv.fr), the number checked as
  you type (« … existe déjà » with « Rejoindre avec un code »), the year; then the code (with a copy button), its QR code and « Partager ».
  Admins only. Needs the network.
- « Rejoindre une tournée »: scan the QR code or type the code in two boxes, check the
  tournée shown, « Demander à rejoindre »; « Demande envoyée » waits, offline too, and opens
  the tournée once a member accepts (« Demande refusée » otherwise, « Annuler la demande »).

Temporary M1 start screen (until the map arrives in M3):

- « Mes rues »: the streets of the open tournée, shared live with the team (Firestore), or
  the streets on the phone while no tournée is open; their progress, a filter that ignores
  accents and case; works offline.
- With a tournée open, a card offers the streets kept on the phone: « Les ajouter à la
  tournée » moves them with their marks (once per tournée; a street the tournée already has
  is skipped), « Plus tard » hides the card until the next launch.
- « Importer des rues » (no tournée open): find a commune by name (geo.api.gouv.fr), tick
  some of its streets (national address base, BAN) and import them with their house numbers
  onto the phone. Needs the network once; streets already imported keep their marks.
- « Ajouter des rues » (a tournée open): tabs « Carte | Liste ». « Liste » ticks the streets
  of the tournée's communes (a chip per commune) and adds them to the tournée; « Carte »
  shows the tournée's map, opened on its communes, offline too.
- Top bar: the open tournée (« Tournée 49 · 2026 » over its centre de secours), or the
  app's name when none is open, opens « Mes tournées », to switch tournée (the app reopens
  the last one at launch, offline too) or create or join one, with a dot on another
  tournée where a join request waits; 👥 opens Équipe (a dot while a join request waits); ⚙ opens Paramètres: first name (the team sees the new one), « Mes tournées », theme (Système,
  Clair, Sombre), confidentialité, version (opens « Nouveautés », what each version brings), licences, data credits.
- Équipe (👥): the join code (copy button: « Code copié ») and its QR code, « Partager »,
  « Nouveau code » (admins), the requests to join with « Accepter » / « Refuser » (any
  member or admin), the members (« · admin ») with « Retirer » (admins), the Corbeille,
  the tournée's communes (« + Ajouter une commune », ✕ but on the last one),
  « Quitter la tournée » (every member) and « Supprimer la tournée » (admins).
  Answering, removing and leaving work offline; a new code and deleting need the network.
  A member removed, or whose tournée was deleted, sees it leave « Mes tournées » with a
  message (« Vous avez été retiré de la tournée 49. »); offline, nothing is forgotten.
- Administrators (an `admins/{uid}` document added by hand in the Firebase console): they
  create tournées, manage every one, and see them all in « Toutes les tournées » (from
  « Mes tournées », needs the network). A tournée an admin opens without being in it shows
  « Administrateur · pas membre » with « Rejoindre » (a member at once); « Retirer de Mes
  tournées » forgets it. Paramètres shows « Identifiant de l'appareil » (« · administrateur »).
- Corbeille (from Équipe): the deleted streets and numbers, who deleted them and when, and
  « Restaurer », which brings them back with their marks. What stayed there more than 30 days
  is deleted for good by the first member's app that starts (no server).
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
  « Ne plus la faire », shown to a member who covers the street, takes them off it (the
  street stays for the others); « Supprimer la rue » sends the street to the Corbeille.
- « Modifier les portes » (« Gérer l'immeuble » under the grid): floor by floor, « + » adds a
  door, ✕ removes one (with « Annuler »; asks first when it has a mark), a tap renames it
  (« Gauche », « Droite » on every floor). The other doors keep their marks.
- Works offline, cold start included: marks are kept on the phone (Firestore's cache for a
  tournée) and sent to the team when the network is back.
- Not yet: the map, « Mes rues » as the streets one covers, and « Ajouter des rues » (M3;
  the street-picking use cases are there, no screen uses them yet).
