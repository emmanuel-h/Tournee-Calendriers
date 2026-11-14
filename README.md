# Tournée Calendriers

App firefighters use to mark the houses visited during the yearly calendar round, shared live
across a team. Flutter + Riverpod, Android first. The UI is in French.

- Product and architecture: [`docs/PLAN.md`](docs/PLAN.md)
- Commands and conventions: [`CLAUDE.md`](CLAUDE.md)

## Features

Onboarding:

- « Bienvenue » on a phone that holds nothing yet: the first name, then « Rejoindre un
  secteur » (and « Créer un secteur » for an admin), disabled until a name is typed;
  « Identifiant de l'appareil » with a copy button at the bottom.
- « Nouveau secteur »: the centre de secours picked from the known ones as you type (or
  added), its communes (one or more, searched on geo.api.gouv.fr), the number checked as
  you type (« … existe déjà » with « Rejoindre avec un code »), the year; then the code (with a copy button), its QR code and « Partager ».
  Admins only. Needs the network.
- « Rejoindre un secteur »: scan the QR code or type the code in two boxes, check the
  secteur shown, « Demander à rejoindre »; « Demande envoyée » waits, offline too, and opens
  the secteur once a member accepts (« Demande refusée » otherwise, « Annuler la demande »).
  Names are unique within a secteur, case and accents ignored, checked by the server: a name
  taken there asks for another one for that secteur only (« Vos autres secteurs gardent … »).

Start screen:

- Accueil (a secteur open): the secteur's map, its streets coloured by progress (« faite »,
  « en partie », « à faire ») and, from street zoom, a dot per house; a legend chip that
  folds away and explains the dots once zoomed in. Below, the « Rues » panel (drag it up for
  the whole list, down for the totals): « Rues · 31/50 » over every street of the secteur,
  then every street in one list (each member covers the whole secteur); a row opens the
  street. A street tapped on the map shows its card: progress and « Ouvrir ». Works offline.
- « ↻ À repasser (5) » on Accueil (« Prochain : aujourd'hui vers 19 h ») while the secteur
  has houses to come back to: the list by day (« Aujourd'hui », « Demain », … « À tout
  moment » for no day or a day gone), who set each, a 🔔 on those that ring this phone; a
  row opens the street at the house, ringed for a moment (a door opens its building's grid
  at that door). Reminders: a local notification 15 min before the hour of each ↻ the
  member set, or one at 9 h for those of the day without an hour; a tap opens the house (or
  the list). Inexact, offline, kept after a restart of the phone; « Rappels » in Paramètres
  switches them off, and says when Android blocks them (« Réglages »).
- No secteur open: the map alone and « Aucun secteur ouvert », with « Rejoindre un
  secteur » (and « Créer un secteur » for an admin). Streets only live in a secteur.
- « Ajouter des rues » (from Secteur; ✕ goes back there): tabs « Carte | Liste ». « Liste » ticks the streets
  of the secteur's communes (a chip per commune; a commune searched by name for a secteur
  without any) with their house numbers from the national address base (BAN), and adds
  them to the secteur, a street from the Corbeille coming back with its marks; « Carte »
  (first) shows the secteur's map, opened on its communes: a tap on a road ticks it (a ✓ on
  its road; a second tap unticks it; a street of the secteur shows its card instead, with
  « Modifier la rue » and « Supprimer la rue »), the
  search box finds a street of the communes by name and ticks it, « Zone » draws a
  rectangle with a finger and lists its streets (those to add ticked, those of the secteur
  and roads without address greyed; at any zoom, 50 streets at most; two fingers move the
  map), and the sheet at the bottom lists the streets ticked and adds them all at once
  (« Ajouter 3 rues »), staying open to add more. The street under a tap, the streets of
  a zone and every street's line come from IGN BD TOPO by the street's BAN id (the side of
  the road under the finger when it carries a street on each side), OpenStreetMap by name
  only where IGN has nothing. Under each street ticked (sheet, zone,
  « Liste »), « Toute la rue › » opens « Partie de la rue » to keep only some of its numbers
  (« Pairs 2–8 › », « 4 numéros sur 8 »): only those are added. A street another secteur
  holds in part says so under its row (« Secteur 12 : impairs 19–41 »), and « Partie de la
  rue » hatches that secteur's stretch and warns of the numbers both hold, never blocking;
  « Rue
  absente de la carte ? Saisir à la main » adds a street the map lacks, offline
  (« Connexion nécessaire pour ajouter une rue. » otherwise).
- Top bar: the open secteur (« Secteur 49 · 2026 » over its centre de secours) opens
  Secteur, with a dot while a join request waits; the app's name, when none is open, opens
  « Mes secteurs » (also « Changer de secteur » in Secteur), to switch secteur (the app
  reopens the last one at launch, offline too) or create or join one, with a dot on another
  secteur where a join request waits; ⚙ opens Paramètres: first name (the team sees the new one where it is free; « Vos noms par secteur » and a name of its own for a secteur where it is taken), « Mes secteurs », theme (Système,
  Clair, Sombre), confidentialité, version (opens « Nouveautés », what each version brings), licences, data credits.
- Secteur (Accueil's title, once called Équipe): « Changer de secteur », the join code (copy button: « Code copié ») and its QR code, « Partager »,
  « Nouveau code » (admins), the requests to join with « Accepter » / « Refuser » (any
  member or admin), the members (« · admin ») and « Retirer » (admins; « Changer aussi le code » ticked), « RUES (n) » with
  « + Ajouter des rues » and the Corbeille (not for a pending member), the secteur's
  communes (« + Ajouter une commune », ✕ but on the last one), and pinned at the bottom
  « Quitter le secteur » (every member) and « Supprimer le secteur » (admins).
  Answering, removing and leaving work offline; a new code and deleting need the network.
  A member removed, or whose secteur was deleted, sees it leave « Mes secteurs » with a
  message (« Vous avez été retiré du secteur 49. »); offline, nothing is forgotten.
- Administrators (an `admins/{uid}` document added by hand in the Firebase console): they
  create secteurs, manage every one, and see them all in « Tous les secteurs » (from
  « Mes secteurs », needs the network). A secteur an admin opens without being in it shows
  « Administrateur · pas membre » with « Rejoindre » (a member at once); « Retirer de Mes
  secteurs » forgets it. Paramètres shows « Identifiant de l'appareil » (« · administrateur »).
- Corbeille (from Secteur): the deleted streets and numbers, who deleted them and when, and
  « Restaurer », which brings them back with their marks. What stayed there more than 30 days
  is deleted for good by the first member's app that starts (no server).
- « ☁ Modifications de 3 rues en attente d'envoi » at the bottom of Accueil's panel while marks
  made offline in the open secteur have not reached the server yet.

Street screen (« Rue »):

- Odd numbers on the left, even on the right, scrolling together (one column when the street
  has one side only); counts « visited/total · ⊘ · ✗ · ↻ » and a progress bar.
- During a tournée, a tap on a house (light vibration, the tile outlined) opens its status
  picker: « N° 7 »,
  its status in grey, « ✓ Fait », « ⊘ Refusé », « ✗ Personne », « ↻ Repasser » two by two
  and « ○ À faire » across,
  then the tries and who changed it last. One tap stores a status and closes, with « N° 7 :
  personne » and « Annuler » for 4 s and a screen-reader announcement; the status it already
  has stores nothing. No hold any more.
- Houses are marked only during a tournée: with none on, the street and its buildings show
  every status, but a tap says « Commencez une tournée pour marquer les maisons. » with
  « Commencer », which starts one there (offline too); a visiting admin is told « Seuls les
  membres en tournée marquent les maisons. ». « Modifier la rue » needs no tournée.
- « ⊘ Refusé » (no calendar wanted): a dark grey tile and a ⊘ dot on the map, counted as
  visited with the done houses (a street can be « faite » with refusals), no tries, no
  come-back.
- « Masquer faits » hides the done and refused houses, remembered per street on the phone.
- Tournées (one outing, offline too): « Commencer une tournée » on Accueil for a member of the
  team; while it runs, the « En tournée · 1 h 20 » band with « 19 dons · 280 € › » and
  « ■ Terminer » takes the place of Accueil's top bar (no secteur switch, Secteur or ⚙ until it
  ends) and sits above the street screen and the building grid. « ✓ Fait » then asks
  « Montant du don » (Espèces | Chèque | Carte, 5 / 10 / 20 €, « Autre montant », « Calendrier
  offert »; ✕ puts the house back), and a house done offers « + Ajouter un don »; « Annuler »
  in the snackbar takes the don back too. « Dons de la tournée » lists them newest first, to
  change, remove or add one; « Bilan de la tournée » shows the houses visited, the dons and the
  money per method, then « Valider la tournée » (asked first; only the totals are kept, never a
  don per house), or « Abandonner la tournée » for one started by mistake (asked first; its
  dons are forgotten, nothing reaches « Collecte », the houses stay marked). A validated
  tournée stays on the phone until the server has it: « Collecte » lists it under « PAS ENCORE
  ENVOYÉES » (« ⏳ En attente d'envoi », or « ⚠ Refusée par le serveur » with « Réessayer » and
  « Effacer »), out of the totals.
- Calendars per house: a house or door done shows « 1 calendrier » / « 2 calendriers » in its
  picker with « − » (disabled at one); « + Ajouter un don » adds one, and its
  « Annuler » takes the don and the calendar back; from two, the tile and the door carry a
  round badge with the number. Only the count is kept, no amount.
- « ↻ Repasser » then asks « N° 5 · quand repasser ? »: a day among the next week's chips, an
  hour 8 h–21 h or « Pas d'heure », « Le samedi 24 oct. vers 18 h », each stored at once, and
  « Valider ». No free note: too likely to hold personal data, so the app keeps none (notes
  stored by an earlier version are erased).
- Tries with nobody home: the picker counts them (« 2 passages sans personne ») and, on a house
  « Personne » or « Repasser » already tried, « ✗ Personne » reads « De nouveau personne » and
  adds one (« N° 7 : personne (3e passage) »); tiles and doors show « ×3 » from two tries,
  kept once done; back to « À faire » starts again at 0.
- « Transformer en immeuble… » in edit mode (✏, tap a number) describes a building (« Décrire l'immeuble »):
  staircases, floors (RdC–5e, or « Inconnus »), doors per floor — the same for every staircase,
  or each its own (« Même chose pour chaque escalier » unticked) —, door labels « 51, 52… |
  5A, 5B… | Libres », with a live preview.
- Tap a building for its grid (« Immeuble »): floors from the top down, four doors a row,
  a staircase control when there are several, « ◐ done/total » for the whole building. A tap
  on a door opens the same status picker (« Porte 51 · Fait »), with its snackbar « Porte 51 :
  fait » and « Annuler ». « Gérer l'immeuble » holds every change to the building: « Modifier les étages » lays
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
  secteur) and sent to the team when the network is back.
- The open secteur downloads itself for offline use, unseen, whenever the app is online: every
  street and the map of its area (+ 300 m, zooms 12–17), again when a street reaches beyond
  it; the maps are refreshed silently (the map's tiles change every week), a failure is tried
  again 2 minutes later, and a secteur the phone forgets loses its download. Nothing on
  screen says so, except one line in Paramètres; offline, « Mes secteurs » greys a secteur
  not downloaded on this phone (« Disponible avec réseau ») and does not open it.

## Licence

MIT — see [LICENSE](LICENSE). The bundled fonts (Atkinson Hyperlegible, Barlow Condensed) keep
their own SIL Open Font License, next to them in `assets/fonts/`. The privacy policy is
[PRIVACY.md](PRIVACY.md).
