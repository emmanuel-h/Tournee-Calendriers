# Tournée Calendriers — App plan

Status: **screens chosen, mockups in review** · 2026-10-04 · mockups: `docs/mockups/`
Tasks: GitHub issues, mapped in `docs/TASKS.md`.

The app UI is **entirely in French**. This document is in English; every screen sketch shows
the real French copy.

---

## 1. Goal

Each year, firefighters sell calendars door to door. Each firefighter covers a set of
streets, and a team (one *tournée*) shares the whole sector. The app lets each person:

- pick the streets they cover **by tapping them on a map**, and add missing streets or numbers by hand,
- mark every house as **done / to do / nobody home**, quickly, with one hand, in the street,
- add details to a house: apartments handled one by one, "come back later", a free note,
- see on a map what is done, partly done and still to do, live, across the whole team.

Once a tournée has been downloaded, the app works **fully offline** (map included) and syncs
with the server whenever the network is available.

### In scope for v1

- Name + team code (or QR) onboarding, create / join a tournée
- Map of the tournée: streets coloured by progress, houses as coloured dots when zoomed in
- Street selection on the map (tap a road), backed by the national address base (BAN)
- Manual entry of missing streets and numbers
- House status, come-back flag, note, apartment units
- Live team sync, full offline mode after download
- French only, light + dark

### Out of scope for v1 (possible later)

- Donations, amounts, residents' answers: never recorded
- English or other languages
- Starting next year's campaign from this year's (v1.1). **The v1 data model is built for it** (§6): a tournée holds
  one campaign per year, so nothing needs migrating when the button ships
- Route planning / navigation, statistics beyond progress, exports, web dashboard

---

## 2. Vocabulary

Code uses English names, the UI uses French.

| UI (FR) | Code | Meaning |
|---|---|---|
| Tournée | `Tournee` | A team's round, identified by its **number + centre de secours + code**. Lives across years |
| Centre de secours (CS) | `RescueCentre` | The fire station the tournée belongs to, e.g. CS Villefranche |
| Campagne | `Campaign` | One year of a tournée (2026, 2027…). Statuses belong to a campaign; streets and notes carry over |
| Membre | `Member` | A firefighter who joined the tournée |
| Rue | `Street` | A street in a commune, with its house numbers and its shape on the map |
| Numéro / maison | `House` | One address on a street (`12`, `12bis`), with its position when known |
| Logement | `Dwelling` | One unit inside a building (`Apt 3`, `B2`) |
| Statut | `VisitStatus` | `TO_DO` (à faire), `DONE` (fait), `NOBODY_HOME` (personne) |
| Repasser | `comeBack` | The resident asked to come back later, with an optional hint ("après 19h") |
| Mes rues | assignees | Streets the current member has taken |
| Libre | — | A street in the tournée that nobody has taken |

---

## 3. Decisions taken

| Topic | Decision |
|---|---|
| Platform | **Flutter** (Dart): Android first; iOS kept open (same code, built in the cloud once an Apple developer account exists — no Mac needed) |
| Architecture | **Strict DDD, hexagonal**: domain (entities, value objects, aggregates) → application (use cases + ports) → adapters (Firestore, HTTP, map, UI). Riverpod for state and dependency injection |
| Language | **French only.** Strings in `res/values/strings.xml`; no other locale |
| Map | **MapLibre** (`maplibre_gl`, official Flutter plugin, offline regions on Android and iOS) with **OpenFreeMap** vector tiles (OpenStreetMap data, free, no key) |
| Street picking | Tap a road → reverse geocoding (IGN Géoplateforme) gives the BAN street → BAN gives its numbers with positions → Overpass (OSM) gives its shape, stored once |
| Manual edits | Missing streets and numbers can always be added by hand, offline too |
| Sharing | Live sync through **Firebase Firestore**; its offline cache *is* the local store (no Room) |
| Offline | Explicit "download the tournée" step: all street documents into an unlimited Firestore cache + map tiles of the tournée area into a MapLibre offline region |
| Identity | Firebase **anonymous auth** + display name + 6-character join code or QR |
| Tournée identity | Number + centre de secours + code. Number + CS is unique across the app; the code is the secret used to join |
| Years | A tournée has one campaign per year. A new campaign copies streets, numbers, buildings and notes; statuses and *repasser* start at ○ (v1.1) |
| Apartments | Optional unit list per house; building status derived from units |
| Comments in code | Explain the *why* and non-obvious Dart/Flutter concepts; never restate the code |
| Tests | TDD, fast Dart tests in the dev loop; 100 % coverage gate on domain + application + presentation; no mutation-testing gate (no reliable Dart tool) |

---

## 4. User flows

```
first launch
   │
   ▼
 Bienvenue ── name ──┬── Créer une tournée ──▶ QR + code ──┐
                     └── Rejoindre (QR or code) ───────────┤
                                                           ▼
                                           Download for offline (banner until done)
                                                           ▼
                               Accueil = map of the tournée + "Mes rues" panel
              ┌──────────────────┬──────────────┼──────────────────┬─────────────┐
              ▼                  ▼              ▼                  ▼             ▼
        Rue (2 sides)     Ajouter des rues   Rue à la main     Équipe        Paramètres
              │           (map mode: tap a    (missing street)
              ▼            road → street card)
   Fiche maison / Immeuble
```

Next launches open the last tournée directly, on the map.

Before the round (once):

1. Join the tournée with the QR code at the station.
2. Banner "Télécharger pour le hors-ligne" → one tap → streets + map tiles saved (Wi-Fi advised).
3. "Ajouter des rues" → tap each of my roads on the map → "Ajouter et me l'attribuer".
4. A cul-de-sac missing from the map → "Rue absente ? Saisir à la main".

In the street (often offline):

1. Open the app → the map shows my streets coloured; the panel lists them.
2. Tap *Rue des Lilas* → Street screen: odd side on the left, even side on the right.
3. Each door: **tap the tile** → ✓ fait. Again → ✗ personne. Again → ○ à faire. Undo snackbar.
4. Building at n°8: tap → unit grid → tap each unit the same way.
5. "Repassez ce soir" → **hold** the tile → sheet → *Repasser* + "après 19h".
6. Back in range: queued changes sync; the team map updates.

---

## 5. Screens

Agreed in the terminal on 2026-10-04 (ASCII variants), confirmed with visual mockups in
`docs/mockups/`. Phone portrait. Tap targets ≥ 48 dp; street tiles ≥ 56 dp high. Status is never
shown by colour alone: every status has a glyph too.

Glyphs: `○` à faire · `✓` fait · `✗` personne · `↻` repasser · `◐ 7/12` immeuble en partie.

**One gesture everywhere:** tap cycles `○ → ✓ → ✗ → ○`; hold opens the details. Same rule for
house tiles and apartment tiles. A building tile opens its unit grid on tap.

### 5.1 Bienvenue (first launch only)

```
┌──────────────────────────────┐
│   Tournée des calendriers    │
│                              │
│   Votre prénom [ Manu      ] │
│                              │
│   [   Créer une tournée    ] │
│   [   Rejoindre une tournée] │
└──────────────────────────────┘
```

Both buttons stay disabled until the name is filled in.

### 5.2 Créer / Rejoindre

```
  Créer                               Rejoindre
┌──────────────────────────────┐    ┌──────────────────────────────┐
│ ← Nouvelle tournée           │    │ ← Rejoindre une tournée      │
│ Centre de secours            │    │ [   📷 Scanner le QR code   ] │
│ [ CS Villefranche       ▾ ]  │    │      ou saisir le code       │
│ N° de tournée   [ 49       ] │    │ [ K7P ] - [ 2QX ]            │
│ Année           [ 2026     ] │    │ ┌──────────────────────────┐ │
│ [          Créer         ]   │    │ │ Tournée 49               │ │
│ ──────────────────────────── │    │ │ CS Villefranche · 6 memb.│ │
│ Tournée 49 · CS Villefranche │    │ │ Campagne 2026            │ │
│        ▄▄▄▄ ▄ ▄▄▄▄           │    │ └──────────────────────────┘ │
│   Code K7P-2QX   [Partager]  │    │ [        Rejoindre       ]   │
└──────────────────────────────┘    └──────────────────────────────┘

  Créer — the pair already exists
┌──────────────────────────────┐
│ Centre de secours            │
│ [ CS Villefranche       ▾ ]  │
│ N° de tournée   [ 49       ] │
│ ⚠ La tournée 49 du CS        │
│   Villefranche existe déjà.  │
│   Demandez le code ou le QR  │
│   code à son créateur.       │
│ [ Rejoindre avec un code ]   │
└──────────────────────────────┘
```

- **A tournée is identified by its number, its centre de secours and its code.** Number + CS is
  unique across the app: creation checks it as you type and refuses a duplicate. The code is the
  secret that lets you in; number and CS alone never do.
- **Centre de secours:** a list of the CS already known to the app, filtered as you type, with
  *Ajouter « … »* at the bottom for a new one. Picking from the list avoids "CS Villefranche" and
  "CIS Villefranche-sur-Saône" becoming two stations. Comparison ignores case, accents and the
  CS / CIS / "centre de secours" prefix.
- **Année:** the campaign's year, pre-filled with the current year and editable (calendars sold
  in late 2026 may be called 2027).
- **Code:** 6 random characters from an alphabet without look-alikes
  (`ABCDEFGHJKMNPQRSTUVWXYZ23456789`, no 0/O, 1/I/L): 31⁶ ≈ 887 million combinations, shown as
  `K7P-2QX`, generated with a secure random source. Typing is case-insensitive, ignores the dash
  and refuses characters outside the alphabet.
- **Rejoindre:** QR code (normal way) or the code alone; the app then shows *Tournée 49 · CS
  Villefranche · Campagne 2026* to confirm before joining. **Joining sends a request**: the
  newcomer waits on the screen below until an accepted member lets them in (§8). Scanning uses
  `mobile_scanner` (Android and iOS); the camera permission is asked only when *Scanner* is
  tapped. `qr_flutter` draws the QR.
- The creator can regenerate the code from Équipe (old code stops working; members stay).

```
  after "Rejoindre": waiting for approval
┌──────────────────────────────┐
│ Demande envoyée              │
│ Tournée 49 · CS Villefranche │
│                              │
│   ⏳                          │
│ Un membre de la tournée doit │
│ vous accepter. Demandez-le à │
│ la personne qui vous a donné │
│ le code.                     │
│                              │
│ [ Annuler la demande ]       │
└──────────────────────────────┘
```

- The screen updates by itself as soon as someone accepts (listener on the member document),
  then opens Accueil and offers the download. If refused: "Demande refusée", back to Bienvenue.
- Until accepted, the app shows this screen at every launch.
- Everywhere else the app shows **Tournée 49 · 2026** as the title and the CS as subtitle.

### 5.3 Accueil — map + "Mes rues" panel

```
┌──────────────────────────────┐
│ Tournée 49 · 2026 ▾  [👥•][⚙]│  ← title opens « Mes tournées »; dot: a join request is waiting
│ ┌──────────────────────────┐ │
│ │ ⬇ Télécharger pour le    │ │  ← banner until the tournée is downloaded
│ │   hors-ligne  [Télécharger]│
│ └──────────────────────────┘ │
│ ░░████████░░░░║░░░░░░░░░░░░  │  ← map: my streets + the team's
│ ░░░░░░░░║░░░░▒▒▒▒▒▒▒▒░░░░░░  │
│ ░░░░░░░░║░░░░░░░░░░░│░░░░░░  │
│ [fait █][en partie ▒][à faire ║][libre │]  ← legend chip, collapsible
├──────────────────────────────┤
│            ━━━               │  ← bottom panel, drag up for the full list
│ Mes rues · 43/62   Équipe 41%│
│ Rue des Lilas  ▓▓▓▓▓░ 31/42 ›│
│ Allée des Pins ░░░░░░  0/8  ›│
│ [   Ajouter des rues   ]     │
│ ☁ 3 modifications en attente │  ← only while offline writes are pending
└──────────────────────────────┘
```

- **City zoom:** each street of the tournée drawn over the map, coloured by progress:
  fait (all done), en partie, à faire, libre (in the tournée but nobody took it).
- **Street zoom (≥ 16):** one dot per house at its BAN position, coloured and glyphed by status
  (`●` fait, `✗` personne, `↻` repasser, `○` à faire). Houses entered by hand have no position
  and appear only in the lists.
- Tapping one of the tournée's streets on the map opens its street card (see 5.4) with *Ouvrir*.
- The panel's rows open the Street screen. Dragging the panel up shows the full list; down
  leaves only the handle and the totals.
- A "locate me" button centres the map on the phone's position (location permission asked
  the first time it is tapped, never at launch).

**Mes tournées (tap the title).** The title "Tournée 49 · 2026 ▾" is a button that opens a
bottom sheet:

```
┌──────────────────────────────┐
│ (map, dimmed)                │
├──────────────────────────────┤
│ Mes tournées                 │
│ ● Tournée 49 · 2026        ✓ │  ← current
│   CS Villefranche · 41 %     │
│ ○ Tournée 12 · 2026      •   │  ← dot: a join request waits there
│   CS Gleizé · 8 %            │
│ ◌ Tournée 7 · 2026           │
│   CS Anse · demande en attente│ ← my own request, not accepted yet
│ ──────────────────────────── │
│ [ + Créer une tournée ]      │
│ [   Rejoindre une tournée ]  │
└──────────────────────────────┘
```

- Tapping another tournée switches at once: map, panel and listeners follow it; the app reopens
  on it next time. A tournée that has never been downloaded on this phone shows the download
  banner; offline, only tournées already downloaded can be opened (the others are greyed with
  "Pas téléchargée").
- *Créer* and *Rejoindre* open 5.2; the current tournée stays untouched until the new one is
  ready (or accepted).
- Paramètres → *Mes tournées* opens the same sheet.

### 5.4 Ajouter des rues — map mode

```
┌──────────────────────────────┐
│ ✕  Ajouter des rues          │
│ [🔍 Rechercher une rue     ] │
│ [✎ Saisir une rue à la main] │  ← always visible, works offline
│ ░░░░░░║░░░░░░░░░░░░░░░░░░░░  │
│ ░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░  │ ← tapped road, highlighted
│ ░░░░░░║░░░░👆░░░░░░░░░░░░░░  │
│ ░░░░░░║░░░░░░░░░░░░░░░░░░░░  │
├──────────────────────────────┤
│ Rue Pierre Morin             │  ← street card (bottom sheet)
│ Villefranche-sur-Saône       │
│ 19 numéros · pas encore dans │
│ la tournée                   │
│ [ Ajouter et me l'attribuer ]│
│ [ Ajouter sans m'attribuer  ]│
│ Rue absente ? Saisir à la main│
└──────────────────────────────┘
```

The street card adapts to the street's state:

| State | Card content | Actions |
|---|---|---|
| Not in the tournée | name, commune, number count | *Ajouter et me l'attribuer* · *Ajouter sans m'attribuer* |
| In the tournée, libre | progress | *Me l'attribuer* · *Ouvrir* |
| Mine (maybe shared) | progress, other members | *Ouvrir* · *Ne plus la faire* |
| Someone else's | progress, who covers it | *La faire aussi* · *Ouvrir* |

- Tapping a road calls the reverse geocoder at that point (type `street`) to get the BAN street;
  then BAN gives the numbers and their positions, and Overpass gives the road's shape. All three
  are needed only once per street, when it is added: **this screen needs the network**.
  Offline, the map still shows and existing streets can still be taken, but adding says
  "Connexion nécessaire pour ajouter une rue" and offers manual entry.
- The search box finds a street by name (BAN search, limited to the tournée's communes) and
  centres the map on it.
- A road with no BAN match (private road, new estate): the card says so and offers manual entry.

### 5.5 Keeping streets true to reality: manual street, edit mode

Three entry points, all of which work offline:

| To… | From |
|---|---|
| Add a street missing from the map | *Ajouter des rues* → **Saisir une rue à la main** (always visible under the search box), or the link on a street card |
| Add, remove or rename numbers; rename the street; make a number a building | Street screen → **✏** in the top bar → edit mode |
| Stop covering / delete the street | Edit mode → buttons at the bottom |

```
  manual street                        street in edit mode (✏)
┌──────────────────────────────┐    ┌──────────────────────────────┐
│ ← Rue à la main              │    │ ✕ Modifier la rue      [OK]  │
│ Nom    [ Chemin des Vignes ] │    │ Nom [ Rue des Lilas       ]  │
│ Commune [ Villefranche-s… ▾] │    │   côté impair │  côté pair   │
│ Du [ 1 ]  au [ 57 ]          │    ├──────────────┼───────────────┤
│ ( Les deux | Impairs | Pairs)│    │ [ 1      ✕]  │ [ 2      ✕]   │
│ En plus [ 12bis, 14ter    ]  │    │ [ 3      ✕]  │ [ 4      ✕]   │
│ Aperçu : 1, 2, 3 … 57 (59 n°)│    │ [ 3bis   ✕]  │ [ 6      ✕]   │
│ Fonctionne sans réseau.      │    │ [ 5      ✕]  │ [ 8 🏢   ✕]   │
│ [      Ajouter la rue     ]  │    │ [ + numéros ] │ [ + numéros ] │
└──────────────────────────────┘    ├──────────────┴───────────────┤
                                    │ [Ne plus la faire][Supprimer]│
                                    └──────────────────────────────┘
```

Edit mode:

- **✕** removes a number (undo snackbar; a number that already has a status asks for
  confirmation first).
- **+ numéros** opens the *Ajouter des numéros* sheet: one number, a list or a range
  (`12bis, 21-25`), with a preview. New numbers land on the right side automatically.
- **Tapping a tile** opens a small sheet: change the number (`3` → `3bis`), *Transformer en
  immeuble…* (5.7), or back to a single house.
- The name field renames the street for the whole team.
- *Ne plus la faire* removes me from its assignees; *Supprimer* deletes it for everyone
  (confirmation, any member may do it — see Q2).
- A manual street has no shape on the map; it appears in the lists, marked "saisie à la main".

### 5.6 Rue — two sides of the street (used 95 % of the time)

```
┌──────────────────────────────┐
│ ← Rue des Lilas          [✏] │  ← edit mode (5.5)
│   31/42 · ✗3 · ↻1 ☐ Masquer faits │
│   côté impair │  côté pair    │
├──────────────┼───────────────┤
│ [ 1     ○ ]  │ [ 2     ✓ ]   │
│ [ 3     ✓ ]  │ [ 4     ✓ ]   │
│ [ 3bis  ✗ ]  │ [ 6     ○ ]   │
│ [ 5     ↻ ]  │ [ 8   ◐7/12]  │
│ [ 7     ○ ]  │ [10     ○ ]   │
│ [ 9     ○ ]  │ [12     ✗ ]   │
│ [11     ○ ]  │ [14     ○ ]   │
├──────────────┴───────────────┤
│ 7 → Personne     [Annuler]   │  ← snackbar, 4 s
└──────────────────────────────┘
```

- Odd numbers on the left, even on the right, each column sorted ascending
  (`3 < 3bis < 3ter < 3quater < 3A < 4`). Both columns scroll together.
- Tile: number, status glyph, tinted background per status. A note shows as a small dot.
- **Tap** cycles `○ → ✓ → ✗ → ○` (light haptic tick); **hold** opens the Fiche maison.
- Building tile: tap opens the Immeuble grid.
- A street with numbers on one side only shows a single column.

### 5.7 Fiche maison (hold a tile) and Immeuble (by floor)

```
  single house (hold)                 building (tap)
┌──────────────────────────────┐    ┌──────────────────────────────┐
│ (street screen, dimmed)      │    │ (street screen, dimmed)      │
├──────────────────────────────┤    ├──────────────────────────────┤
│ 5 Rue des Lilas              │    │ 8 Rue des Lilas    ◐ 15/24   │
│ (○ À faire|✓ Fait|✗ Personne)│    │ (Esc. A | Esc. B)  ← if > 1  │
│ ☑ Repasser                   │    │ 5e  [51✓][52○][53✗][54✓]     │
│   [ après 19h             ]  │    │ 4e  [41✓][42✓][43✓][44○]     │
│ Note                         │    │ 3e  [31✗][32✓][33✓][34✓]     │
│ [ chien dans le jardin    ]  │    │ 2e  [21✓][22✓][23○][24✓]     │
│ [ Transformer en immeuble… ] │    │ 1er [11○][12✓][13✓][14✗]     │
│ Modifié par Léa · 14:02      │    │ RdC [01✓][02○]               │
└──────────────────────────────┘    │ Appui : ○→✓→✗→○ · long : détails│
                                    │ [Modifier les étages]        │
                                    │ ☐ Repasser · Note [digicode] │
                                    └──────────────────────────────┘
```

- **Floors from top to bottom**, the way you climb the stairs. One row per floor, its doors
  left to right. A row with more doors than fit wraps onto a second line under the same label.
- Same gesture as everywhere: tap cycles `○ → ✓ → ✗ → ○`, hold opens the door's note / repasser.
- **Several staircases:** a segmented control (Esc. A | Esc. B …) above the floors, shown only
  when the building has more than one; the header count covers the whole building.
- A building whose floors are unknown is a single row labelled "Logements".
- Building status is derived, never stored: done when all doors are done, to do when none are,
  otherwise partial (`◐ done/total`).
- Under every note field: "N'écrivez ni nom ni information personnelle" (see §8).

*Transformer en immeuble…* / *Modifier les étages* sheet:

```
┌──────────────────────────────┐
│ Immeuble · 8 Rue des Lilas   │
│ Escaliers     [ 1 ]  (−)(+)  │
│ Étages  RdC à [ 5 ]e (−)(+)  │
│ Portes par étage [ 4 ] (−)(+)│
│ Numéros ( 51, 52… | 5A, 5B… | libres )
│ Aperçu : RdC 01-04 … 5e 51-54│
│ [         Valider         ]  │
└──────────────────────────────┘
```

- Afterwards each floor can be adjusted on its own (add / remove a door, rename a door), from
  *Modifier les étages* in edit mode. "Libres" lets you type the labels (e.g. "Gauche", "Droite").
- Changing the layout keeps the statuses of doors whose label still exists.

### 5.8 Équipe (👥)

```
┌──────────────────────────────┐
│ ← Tournée 49                 │
│   CS Villefranche · 2026     │
│  ▄▄▄▄ ▄ ▄▄▄▄   Code K7P-2QX  │
│  █▄▄█ ▀ █▄▄█   [Partager]    │
│                [Nouveau code]│  ← creator only
│ EN ATTENTE (1)               │  ← only when requests exist
│ Julie · il y a 2 min         │
│ [ Accepter ]  [ Refuser ]    │  ← any accepted member
│ MEMBRES (5)                  │
│ Manu (vous) · créateur 5 rues│
│ Léa                 3 rues [⋮]│  ← creator only: retirer
│ Paul                0 rues [⋮]│
│ Corbeille · 2 éléments     › │  ← 5.11
│ CAMPAGNE 2026                │
│ [ Démarrer une nouvelle campagne ] │  ← creator only, v1.1 (5.10)
│ [  Quitter la tournée  ]     │
│ [  Supprimer la tournée ]    │  ← creator only
└──────────────────────────────┘
```

- A request shows the name the newcomer typed and how long ago it was sent. Any accepted member
  can accept or refuse, so nobody has to wait for the creator.
- *Retirer* (creator only) cuts the member's access at once; what they marked stays, stamped
  with their name. Combine with *Nouveau code* if the code has leaked.

### 5.9 Paramètres (⚙)

```
┌──────────────────────────────┐
│ ← Paramètres                 │
│ VOUS                         │
│ Prénom        Manu         › │
│ Mes tournées  49 · 2026    › │  ← same sheet as the title
│ HORS-LIGNE                   │
│ Tournée 49 · 34 Mo           │
│ ✓ Téléchargée le 02/11 08:12 │
│ Les modifications sont envoyées dès que le réseau revient. │
│ [Mettre à jour] [Supprimer]  │
│ APPLICATION                  │
│ Thème         Système      › │
│ Confidentialité            › │
│ Données © OpenStreetMap, BAN │
│ Version 1.0.0                │
└──────────────────────────────┘
```

### 5.10 Nouvelle campagne (v1.1)

```
  creator (from Équipe)               every member, after the switch
┌──────────────────────────────┐    ┌──────────────────────────────┐
│ ← Nouvelle campagne          │    │ Tournée 49 · 2027     [👥][⚙]│
│ Tournée 49 · CS Villefranche │    │ ┌──────────────────────────┐ │
│ Année  [ 2027 ]              │    │ │ La campagne 2027 a       │ │
│ ──────────────────────────── │    │ │ commencé.                │ │
│ Repris de 2026               │    │ │ [Reprendre mes rues 2026]│ │
│  ✓ 60 rues, 2 412 numéros    │    │ └──────────────────────────┘ │
│  ✓ 14 immeubles              │    │ (map, all streets à faire)   │
│  ✓ 87 notes                  │    │                              │
│ Remis à zéro                 │    │                              │
│  ○ statuts, « repasser »     │    │                              │
│  ○ qui fait quelle rue       │    │                              │
│ 2026 reste consultable.      │    │                              │
│ [  Démarrer 2027  ]          │    │                              │
└──────────────────────────────┘    └──────────────────────────────┘
```

- Copied: streets (with shapes and edits), numbers, buildings and their floors, notes on houses
  and doors. Reset: statuses, *repasser*, last-change info, assignees.
- *Reprendre mes rues 2026* re-takes in one tap the streets the member covered last year.
- The house sheet and door sheet show last year's result in small type: *En 2026 : ✗ personne*.
  It helps ("nobody home last year either, try the evening") and is read-only.
- The previous campaign stays readable from Paramètres → Tournée → *Campagne 2026*. The one
  before it is deleted when a new campaign starts (data minimisation).
- Members need the network once to receive the new campaign; the download step then runs again.

### 5.11 Corbeille

```
┌──────────────────────────────┐
│ ← Corbeille                  │
│ Gardés 30 jours, puis        │
│ supprimés définitivement.    │
│ ──────────────────────────── │
│ Rue Gambetta (22 n°)         │
│ supprimée par Paul · hier    │
│                  [Restaurer] │
│ 14ter Rue des Lilas          │
│ supprimé par Léa · 3 oct.    │
│                  [Restaurer] │
└──────────────────────────────┘
```

- Deleting a street or a number only hides it; any member can restore it for 30 days, with its
  statuses and notes intact. This is the safety net against mistakes and against a member who
  makes a mess.
- Items older than 30 days are purged by the first member's app that is online (no server
  needed), and at the latest when a new campaign starts.

---

## 6. Data model

### 6.1 Domain model (pure Dart: no Flutter, no Firebase, no MapLibre)

Strict DDD. Two aggregates match the two things people change independently; everything
inside an aggregate changes only through its root, which enforces the invariants.

| Aggregate (root) | Contains | Invariants it guards |
|---|---|---|
| `Tournee` | `Member`s, `JoinCode`, `RescueCentre`, current campaign year | one creator; members are pending or active; only active members accept others; only the creator removes members, regenerates the code, starts a campaign |
| `Street` (one per campaign) | `House` entities, each with an optional `Building` → `Staircase` → `Floor` → `Dwelling` | numbers unique in the street; a building's status is derived, never set; deleting is soft (Corbeille) |

Value objects (immutable, validated at construction, equal by value): `JoinCode` (6 chars from
the alphabet), `RescueCentreKey` (normalised name), `HouseNumber` (12 + "bis", with the
French ordering), `VisitStatus` (`toDo`, `done`, `nobodyHome`), `ComeBack` (optional hint),
`Note` (≤ 200 chars), `GeoPoint`, `StreetShape`, `Progress`, `ProgressLevel`
(`free`, `toDo`, `partial`, `done`), `CampaignYear`. Each house and dwelling also keeps its
`previousStatus` (last campaign's result, read-only).

Value-object rules fixed in T1.1 (`lib/domain/street/`):

- **`HouseNumber`**: integer part `0..99999` (the BAN uses at most five digits; 0 exists) and
  an optional suffix of ≤ 16 ASCII letters and digits starting with a letter, stored lowercase
  as the BAN writes it (`bis`, `a`). Parsing ignores case, leading zeros and spaces around and
  inside (`12 BIS` = `12bis`). The canonical label is the display form *and* the storage key:
  Latin multiplicatives lowercase and glued (`12bis`), any other suffix uppercase (`3A`).
  Order: integer part, then no suffix, then `bis ter quater quinquies sexies septies octies
  nonies decies`, then every other suffix alphabetically. Odd/even comes from the integer part.
- **`Note`** (≤ 200) and **`ComeBack`** hint (≤ 50): trimmed at both ends (inner line breaks
  kept), blank means none (`""`), length counted in Unicode code points (🚒 = 1). The security
  rules must count the same way (checked with emoji in the rules tests, T2.4).
- Invalid input returns a failure value (`Result` = `Ok` | `Err`, `lib/domain/shared/`),
  never an exception.

```dart
// Sketch of the core (final names fixed in the tasks)
final class Street {                       // aggregate root
  final StreetId id;
  final String name;
  final Commune commune;
  final BanStreetId? banId;                // null when entered by hand
  final StreetShape shape;                 // empty when entered by hand
  final Set<MemberId> assignees;
  final List<House> houses;                // always sorted by HouseNumber

  /// Every change returns the new street *and* what changed, so the Firestore adapter
  /// can write only that field (houses.12.status) instead of the whole document.
  (Street, StreetChange) markHouse(HouseNumber n, VisitStatus s, MemberId by, DateTime at);
  (Street, StreetChange) addNumbers(List<HouseNumber> numbers);
  (Street, StreetChange) removeNumber(HouseNumber n, MemberId by, DateTime at); // soft
  Progress get progress;
}

sealed class StreetChange { /* HouseMarked, NumbersAdded, NumberRemoved, … */ }
```

Domain services (pure functions, the bulk of the unit tests): house-number parsing and
ordering, odd/even split, manual range expansion (`1..57`, odd, extras, `21-25`), building
layout generation (staircases × floors × doors, `51` / `5A` styles), join-code generation and
normalisation, rescue-centre name normalisation, campaign roll-over (copy / reset rules),
**map layers as plain data** (street lines with a level, house dots with a status), tournée
bounding box for the offline download, shape simplification (Douglas–Peucker).

Repository **ports** live in the domain (`TourneeRepository`, `StreetRepository`); they take
and return aggregates and `StreetChange`s, never Firestore types.

### 6.2 Firestore layout

```
rescueCentres/{centreKey}                         ← "villefranche"; the CS picker lists these
    name: "CS Villefranche"
tourneeKeys/{centreKey}_{number}                  ← "villefranche_49": guarantees number + CS is unique
    tourneeId
joinCodes/{code}                                  ← "K7P2QX": readable only by exact code (get, not list)
    tourneeId, number, centreName, campaign      ← what the join preview shows; nothing else

tournees/{tourneeId}
    number: 49, centreKey, centreName, joinCode, createdBy, createdAt,
    currentCampaign: 2026, communes: ["69264", …]
  members/{uid}
    displayName: "Manu", status: "pending" | "active", requestedAt, acceptedBy, acceptedAt
  campaigns/{year}                                ← one per year: 2026, 2027…
      startedAt, previousYear: null | 2026
    streets/{streetId}
      name, communeName, communeCode, banId,
      shape: ["<encoded polyline>", …],           ← one per OSM way, simplified, ≈ 1 KB a street
      assignees: [uid, …],
      deletedAt, deletedBy                        ← set = in the Corbeille (5.11)
      houses: {                                   ← a map inside the street document
        "12":  { n: 12, sfx: null, lat, lon, status: "DONE", comeBack: null, note: "",
                 prev: "NOBODY_HOME", by: uid, at: timestamp, deletedAt: null },
        "8":   { n: 8, …, dwellings: { "A51": { label: "51", esc: "A", floor: 5, status, note,
                                                prev, by, at }, … } }
      }
```

Creating a tournée writes `tourneeKeys`, `joinCodes`, `tournees` and its first campaign in one
batch; the security rules refuse the batch if `tourneeKeys/{key}` already exists, which is what
makes number + CS unique even if two people create it at the same second.

A new campaign (v1.1) is a batch that copies each street of the current campaign into
`campaigns/{newYear}`, resets the fields listed in 5.10, stores the old effective status in
`prev`, then flips `currentCampaign`. Listeners follow `currentCampaign`, so every phone
switches by itself.

Why houses are a map inside the street document and not one document each:

- **Cost and speed.** The map and the home screen read one document per street of the current campaign (≈ 60), not
  one per house (≈ 2 500). That stays inside the free tier even with a large team.
- **No conflicts in practice.** Writes use field paths (`houses.12.status`), so two people
  marking different houses of the same street at the same moment never overwrite each other.
  Only the same house at the same instant is last-write-wins, and the tile then shows who won.
- **Size is safe.** A street of 300 numbers with positions and a few buildings is ≈ 80 KB;
  the document limit is 1 MB.

Progress is computed on the device from the street documents. No counters are stored, so they
can never drift.

### 6.3 Local-only state

- `shared_preferences`: display name, last tournée id, theme, "hide done" per street, offline
  download date and size per tournée.
- MapLibre offline region per tournée (tiles), behind the `OfflineMapStore` port.

---

## 7. Sync and offline behaviour

**Goal:** once "Télécharger pour le hors-ligne" has run, the app can be used for a whole day with
no network, including a cold start, and loses nothing.

| What | How it works offline |
|---|---|
| Sign-in | The anonymous Firebase session is persisted on the phone; no network needed at start-up |
| Tournée data | Firestore persistent cache with **unlimited size** (no eviction). The download step runs one read of every street of the tournée, so all of them are in the cache |
| Live updates | Snapshot listeners serve the cache at once, then the server when reachable |
| Writes | Applied locally at once, queued by Firestore, survive restarts, sent when back online |
| Map | MapLibre offline region covering the tournée's bounding box + 300 m margin, zooms 12–17 (≈ 10 MB, measured in the T0.4 spike: OpenFreeMap tiles stop at z14, fonts are most of it). Street lines and house dots are drawn from the cached street documents, not from the network |
| New streets in the tournée added by teammates | Arrive with the next sync; their map tiles are already covered if they are inside the downloaded area, otherwise the banner asks to update the download |

- The pending-writes indicator ("☁ 3 modifications en attente") comes from the snapshot
  metadata `hasPendingWrites`.
- The banner and the Paramètres section show the download state; "Mettre à jour" re-runs both
  parts (streets and tiles).
- What needs the network: creating / joining a tournée, the download itself, and **adding a
  street from the map** (reverse geocoding, BAN, Overpass). Adding a street by hand, adding
  numbers, taking streets and every status change work offline.
- Undo is a normal write that restores the previous value, not a rollback.

---

## 8. Security and privacy

### 8.1 Threat: someone guesses or obtains a code

The code space (31⁶ ≈ 887 million) protects one *given* tournée well, but not "any tournée":
with 1 000 tournées in the app, one guess in ~887 000 lands somewhere. Without rate limiting,
a script could get in somewhere within minutes. A leaked code (forwarded WhatsApp message,
photo of the QR) is even more likely. So **knowing a code must not be enough**:

| Layer | What it stops | When |
|---|---|---|
| **Approval of newcomers.** Using a code creates a *pending* member who can read or write nothing until an accepted member accepts them (5.2, 5.8) | Guessed or leaked codes give no access at all | v1 |
| **App Check (Play Integrity)** enforced on Firestore: only the genuine app from the Play Store can talk to the database | Scripts, mass guessing, data scraping | v1 (M2) |
| **Strict security rules**: schema, allowed values and lengths for every field; members may only touch the fields of their job; nobody edits `createdBy`, codes, or other members except as below | A member corrupting documents or escalating | v1 |
| **Corbeille + attribution**: deletes are soft for 30 days (5.11); every change records who and when | Mistakes, and a member who makes a mess | v1 |
| **Remove member + new code** (creator) | A bad actor already inside | v1 |
| Server-side join with rate limiting (Cloud Function, needs the Blaze plan) | Large-scale guessing even from the real app | **To decide at the M2 infrastructure checkpoint** (staying on the free Spark plan for now) |

### 8.2 Security rules (`firebase/firestore.rules`, tested in the emulator, §11)

- `tournees/{id}/**`: read and write only for members with `status == "active"`.
- `members/{uid}` create: only by that uid, only `status: "pending"`, only with the tournée's
  current join code. Update `pending → active` or delete a pending request: any active member.
  Delete an active member: the creator, or the member themself (*Quitter*).
- `joinCodes/{code}`: `get` for signed-in users, `list` denied; holds only the preview fields.
- `tourneeKeys/{key}`: `get` allowed (creation must know the pair is taken); create only if
  absent; never updated; deleted only with the tournée.
- `rescueCentres`: readable by signed-in users (station names only), create-only.
- Street and house writes: field-path updates only on `status`, `comeBack`, `note`, `by`, `at`,
  `assignees`, `deletedAt/By`, numbers and dwellings; `status` in the enum; `note` ≤ 200 chars
  and the `comeBack` hint ≤ 50 chars (code points, as the domain counts them, §6.1);
  `by` must equal the caller's uid; `at` must be the server time.
- Only the creator: delete the tournée, regenerate the code, start a campaign. Previous
  campaigns are read-only.

### 8.3 Privacy

- **Auth:** anonymous Firebase account created on first launch. The uid is the member id.
  Reinstalling the app creates a new uid, so the person rejoins with the code and is approved
  again (their old member row can be removed by the creator).
- **Data stored:** addresses and their positions (public data), visit statuses, free-text notes,
  first names of the members. No donations, no residents' names, no residents' answers. The
  note field carries a hint asking not to write personal information.
- **Location:** the phone's position is used only on screen ("locate me"), never stored or
  sent. Permission is asked when the button is first tapped.
- Firestore region: `europe-west` (EU).
- Attribution shown on the map and in Paramètres: © OpenStreetMap contributors (ODbL),
  OpenFreeMap, Base Adresse Nationale (Licence Ouverte).
- Play Store: needs a privacy policy (Firebase + network + location). Data can be deleted by
  deleting the tournée; the previous-but-one campaign is deleted at each roll-over.

---

## 9. External services (verified 2026-10-04, no key needed)

| Purpose | Endpoint | Notes |
|---|---|---|
| Map tiles + style | `https://tiles.openfreemap.org/styles/liberty` (or `positron`) | OSM vector tiles for MapLibre. Offline download through `maplibre_gl` offline regions; check OpenFreeMap's terms on bulk download in the spike task |
| Street under a tap | `https://data.geopf.fr/geocodage/reverse?lon={lon}&lat={lat}&index=address&type=street&limit=1` | Returns BAN `id` = idVoie (`69264_1460`), `name`, `citycode` |
| Street search by name | `https://data.geopf.fr/geocodage/search?q={q}&type=street&citycode={code}` | For the search box |
| Numbers of a street | `https://plateforme.adresse.data.gouv.fr/lookup/{idVoie}` | `numeros[]`: `numero`, `suffixe`, `position.coordinates` [lon, lat] |
| Shape of a street | Overpass `https://overpass-api.de/api/interpreter`, query `way(area INSEE)["highway"]["name"="…"]; out geom;` | Needs a `User-Agent`. One call per added street. Fallback when empty: no shape, house dots only |

All of them are wrapped behind domain interfaces (`AddressDirectory`, `StreetShapes`), so the rest
of the app never sees HTTP or JSON, and tests use fakes. Parsing is tested against JSON fixtures
captured from the real services.

---

## 10. Architecture and tech stack

### 10.1 Layers (strict DDD, hexagonal)

```
lib/
├── domain/          Pure Dart. Aggregates, entities, value objects, domain services,
│   ├── tournee/     repository ports. Imports nothing but dart:core / dart:math / collection.
│   ├── street/
│   └── shared/
├── application/     Use cases (one class per use case, a single `call` method), outbound
│   ├── use_cases/   ports for external services (AddressDirectory, StreetShapes,
│   └── ports/       OfflineMapStore, IdentityProvider, Clock, IdGenerator). Depends on domain only.
├── infrastructure/  Adapters implementing the ports: firestore/, geopf/ + ban/ (http),
│                    overpass/, maplibre_offline/, firebase_auth/, preferences/, mappers.
│                    The only place Firebase, http, MapLibre, shared_preferences appear.
├── presentation/    Riverpod Notifiers + immutable view states. Call use cases only.
│                    No Flutter widget, no infrastructure import.
├── ui/              Flutter widgets: screens, theme/, components/, map/ (wraps maplibre_gl).
│                    Reads view states, sends intents; no business logic.
└── bootstrap/       Composition root: Firebase + App Check init, Riverpod providers binding
                     each port to its adapter (overridden with fakes in tests). main.dart.
```

- **Dependency rule:** arrows point inward only — `ui → presentation → application → domain`,
  `infrastructure → application / domain`, `bootstrap` sees everything. `ui` may also name
  domain value types (e.g. `VisitStatus`) but never calls `application`; `presentation` may use
  Riverpod but not Flutter. Firebase / http / shared_preferences appear only in
  `infrastructure` and `bootstrap`; MapLibre only in `ui/map` and `infrastructure/maplibre_offline`. A fast architecture
  test (`test/architecture_test.dart`) reads every import in `lib/` and fails on a forbidden one.
- **Use cases** are the only entry point to behaviour: `MarkHouse`, `AddStreetFromMap`,
  `AddManualStreet`, `EditStreetNumbers`, `DescribeBuilding`, `CreateTournee`,
  `RequestToJoin`, `AcceptMember`, `DownloadTournee`, `StartCampaign`, … A use case loads the
  aggregate through its port, calls the root, saves the `StreetChange` through the port.
- **Adapters translate**: Firestore maps ⇄ aggregates, `StreetChange` → field-path updates,
  geopf / BAN / Overpass JSON → value objects. Translation code is pure functions, tested alone.
- The map is split the same way: the domain computes *what* to draw; `ui/map/` only turns that
  into MapLibre GeoJSON sources and layers, and taps into coordinates.

### 10.2 Stack

| Concern | Choice |
|---|---|
| SDK | Flutter stable + Dart 3 (versions pinned at scaffolding, M0) |
| State + DI | `flutter_riverpod` 3 (Notifier / AsyncNotifier), **no code generation**: faster builds, readable code |
| Navigation | `go_router` |
| Models | Dart 3 `final class` / `sealed class` / records; value equality hand-written in the domain (no `freezed`, no build_runner) |
| Backend | FlutterFire (official): `firebase_core`, `cloud_firestore`, `firebase_auth` (anonymous), `firebase_app_check` (Play Integrity on Android, App Attest on iOS). Spark (free) plan for now — revisit at M2 |
| Map | `maplibre_gl` (official MapLibre plugin) + OpenFreeMap tiles; offline regions |
| HTTP | `http` (geopf, BAN, Overpass), `MockClient` in tests |
| QR | `qr_flutter` (draw), `mobile_scanner` (scan; camera permission asked on tap) |
| Location | `geolocator`, only for "locate me" |
| Share | `share_plus` |
| Settings | `shared_preferences` |
| i18n | `flutter_localizations` + ARB, **French only** (`app_fr.arb`) |
| Fonts | Atkinson Hyperlegible + Barlow Condensed bundled as assets (OFL), so they work offline |
| Lint | `flutter_lints` + strict analysis options (`strict-casts`, `strict-raw-types`), architecture test |
| Android | minSdk 26; release signing from env / `key.properties`; `flutter build appbundle` |
| iOS (later) | iOS 15+; built and signed in the cloud (Codemagic or GitHub Actions macOS runner) → TestFlight. Needs the Apple developer account only, no Mac |

### 10.3 Firebase setup (manual, done once by you)

1. Create a Firebase project, Firestore in `europe-west`, enable Anonymous sign-in and App Check.
2. `dart pub global activate flutterfire_cli`, then `flutterfire configure` for Android
   (`fr.mandarine.tourneecalendriers`); iOS is added the same way later.
3. Install the Firebase CLI (`npm i -g firebase-tools`) for the emulator and rules deploys.

The generated `firebase_options.dart` and `google-services.json` are gitignored (the repo is
public). CI writes them from secrets.

---

## 11. Testing strategy (fast by design)

The rule: **the loop a developer runs dozens of times stays under a minute**. Slow suites exist,
but they run once per task and in CI.

| Suite | What | Runs on | When | Budget |
|---|---|---|---|---|
| Domain | aggregates, value objects, domain services — plain `test` | Dart VM | every TDD cycle | ms per test |
| Application | use cases with **hand-written fakes** of the ports | Dart VM | every TDD cycle | ms per test |
| Presentation | Riverpod notifiers via `ProviderContainer`, ports overridden by fakes | Dart VM | every TDD cycle | ms per test |
| Adapters | Firestore adapter against `fake_cloud_firestore` (in memory, no emulator); geopf / BAN / Overpass parsing with `MockClient` + JSON fixtures captured from the real services | Dart VM | when touched | < 10 s |
| Widgets | widget tests for the critical interactions only: welcome gating, tap-cycle + undo on street tiles, hold → house sheet, building grid, edit mode remove + undo, street card states, join pending screen | `flutter test` (headless) | end of each UI task, CI | ≤ 25 tests, < 60 s |
| Architecture | import rules between layers | Dart VM | every run | < 1 s |
| Coverage | **100 % line coverage** on `domain/`, `application/`, `presentation/` and the adapters' mapping code, checked by a script on `coverage/lcov.info` | — | end of task, CI | piggybacks |
| Rules | Firestore security rules in the Firebase emulator (`@firebase/rules-unit-testing`, `node --test`) | Node + emulator | when `firebase/` changes, CI | < 1 min |
| Instrumented | `integration_test/`: a handful of end-to-end flows in the real app (launch, mark a house + undo, building, edit a street, offline cold start…), ≤ 10 tests | Android emulator (`Medium_Phone_API_36.1`), run by Claude | before every push to `main` | < 3 min |
| Device | Manual checklist on your phone: map render, tap-to-add, offline download, **airplane-mode day** (cold start, mark, restart, reconnect, sync), QR scan | your phone | after every task, and the full checklist before release | — |

**No mutation-testing gate:** Dart has no maintained equivalent of Pitest. To compensate, the
developer agent follows explicit test-writing rules: each branch gets a test whose values would
fail if the condition were inverted or a boundary moved by one; every field of a returned value
object is asserted, not just equality of the whole; no test without an assertion on behaviour.

The MapLibre widget and the offline tile download are SDK glue, kept thin, excluded from the
coverage gate by path, and covered by the device checklist.

Conventions: `test` / `flutter_test`, `mocktail` only for collaborators that are verified,
hand-written fakes for ports, test names `'should <behaviour> when <condition>'`, one behaviour
per test, no real network, no real clock (`Clock` port), no `sleep`.

### Quality gates and CI

`.github/workflows/checks.yml`, on push to `main` and on PRs (Ubuntu runners):

1. `flutter analyze` (zero warnings) + `dart format --set-exit-if-changed`
2. `flutter test --coverage` + coverage gate script
3. `flutter build appbundle --release` (catches release-only breakage: R8, shrinking)
4. Firestore rules tests in the emulator

iOS (later): a separate Codemagic or macOS-runner workflow builds the `.ipa` and uploads it
to TestFlight once the Apple account exists.

---

## 12. Milestones (to be split into tasks next)

| # | Milestone | Shows on screen |
|---|---|---|
| M0 | Scaffolding: Flutter project, layers + architecture test, theme + fonts, go_router shell, Riverpod bootstrap, French ARB, coverage gate, CI, Firebase wiring (Android); spike on `maplibre_gl` + OpenFreeMap + offline region on a phone | empty app builds green in CI; a map renders on a phone |
| M1 | Core domain + Street screen + Fiche maison + Immeuble on a **real reference area** (BAN streets and numbers, marks stored on the phone) | you walk real streets with the app before any backend exists |
| M2 | **Starts with an infrastructure checkpoint with you** (Spark vs Blaze, server-side join with rate limiting, or another backend). Then identity + Firestore: bienvenue, créer / rejoindre (code + QR), approval of newcomers, équipe, corbeille, App Check, live sync, rules + emulator tests | two phones see each other's marks; a guessed code gets nowhere |
| M3 | Map: Accueil map + panel, progress colours, house dots, ajouter des rues (tap → card → add), search, manual street + numbers | real streets, picked on the map |
| M4 | Offline: download step (cache + tiles), pending-writes indicator, Paramètres hors-ligne, airplane-mode checklist | a full day without network |
| M5 | Polish and release: dark mode, accessibility (TalkBack, 200 % font), icon, privacy policy, Play listing | store-ready |
| M6 (v1.1) | Nouvelle campagne: copy / reset, *Reprendre mes rues*, last year's result in the sheets, read-only archive | tournée 49 starts 2027 from 2026 |

M1 comes before Firebase on purpose: the street screen is where the app succeeds or fails,
and a real reference area stored on the phone lets you try it in the street before any backend
exists. No invented data at any stage.

---

## 13. Decisions from the review (2026-10-04)

| # | Question | Answer |
|---|---|---|
| Q1 | Join code | 6 random characters without look-alikes (`K7P-2QX`, ≈ 887 M combinations), shared as a QR code too. The tournée number is displayed but never used to join. |
| Q2 | Who deletes what | Any member adds, edits and deletes streets. Only the creator deletes the tournée or removes members. |
| Q3 | "Refused" status | **No.** The app never records residents' choices or amounts: only whether the door was visited. |
| Q4 | Several tournées per person | Yes. The app opens the last one; the title on Accueil switches (Q21). |
| Q5 | App id | `fr.mandarine.tourneecalendriers`, store name "Tournée Calendriers". |
| Q6 | Public repo | Yes: `google-services.json` is gitignored and injected in CI from a secret. |
| Q7 | minSdk | 26 (Android). iOS 15+ later. |
| Q8 | Street selection | On a map: tap a road → street card → add. Manual entry for what the map or BAN lacks. |
| Q9 | Where the map lives | Accueil = map + "Mes rues" panel; "Ajouter des rues" is a map mode (replaces the Sector list). |
| Q10 | Progress on the map | Streets coloured by progress; houses as status dots when zoomed in. |
| Q11 | Offline | Explicit download of the tournée (data + map tiles); then fully offline, sync when possible. |
| Q12 | Language | French only. |
| Q13 | Adding streets | The map mode is called *Ajouter des rues*. |
| Q14 | Correcting streets | Edit mode on the street screen (✏): remove / add / rename numbers, rename, make a building, stop covering, delete. Manual street always reachable from *Ajouter des rues*. |
| Q15 | Buildings | Described by floor (and staircase when several); one row per floor, top to bottom. |
| Q16 | Tournée identity | Number + centre de secours + code. Number + CS unique; CS picked from a shared list. Joining needs only the code (or QR), with a confirmation of number + CS. |
| Q17 | Next year | One campaign per year inside the tournée. New campaign keeps streets, numbers, buildings, notes; resets statuses, *repasser*, assignees; *Reprendre mes rues 2026*; last year's result shown in the sheets. v1.1, model ready in v1. |
| Q18 | Who starts a campaign, what is kept | The creator. Previous campaign read-only; the one before is deleted. |
| Q19 | Guessed / leaked codes | A code only creates a pending request; any accepted member accepts or refuses. App Check in v1. Soft delete with a 30-day Corbeille. |
| Q20 | Infrastructure | Stay on the free Spark plan for now. **Revisit at the start of M2** (database and server work): server-side join with rate limiting on Blaze, or another option. |
| Q21 | Switching / creating from Accueil | The title is a button: « Mes tournées » sheet with all my tournées (progress, pending requests), *Créer*, *Rejoindre*. |
| Q22 | Technical stack | **Flutter + Riverpod**, strict DDD (hexagonal: domain, use cases, ports, adapters). Android first; iOS later from the same code, built in the cloud (no Mac). Mutation gate dropped (no Dart tool); 100 % coverage gate kept. |

---

## 14. Agent workflow

- Tasks are GitHub issues grouped in milestones M0–M7 (`docs/TASKS.md` maps them).
- `.claude/agents/developer.md`: one agent, takes one task (an issue) and delivers it
  end to end (domain → application → infrastructure → presentation → ui) with TDD, then runs the gates.
- The main session reviews, runs the gates and the instrumented suite on the emulator, commits
  (`Refs #N`), pushes to `main`, then asks you to test on your phone. Issues close only when you
  say so. The agent never commits.
- Any screen change starts from the ASCII sketch in this document and the approved mockup. If a
  task needs a screen that isn't sketched here, the agent stops and asks rather than inventing one.
