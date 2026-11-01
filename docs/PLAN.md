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
- add details to a house: apartments handled one by one, "come back later" with a day and an hour,
- see on a map what is done, partly done and still to do, live, across the whole team.

Once a tournée has been downloaded, the app works **fully offline** (map included) and syncs
with the server whenever the network is available.

### In scope for v1

- Name + team code (or QR) onboarding, create / join a tournée
- Map of the tournée: streets coloured by progress, houses as coloured dots when zoomed in
- Street selection on the map (tap a road), backed by the national address base (BAN)
- Manual entry of missing streets and numbers
- House status (« repasser » with an optional day and hour, #81), apartment units
- Live team sync, full offline mode after download
- French only, light + dark

### Out of scope for v1 (possible later)

- Donations, amounts, residents' answers: never recorded
- Free-text notes on houses and doors: removed for privacy (§8.3, Q23); since #81 the
  « repasser » hint is a day and an hour, so no free text is kept about a house
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
| Campagne | `Campaign` | One year of a tournée (2026, 2027…). Statuses belong to a campaign; streets and buildings carry over |
| Membre | `Member` | A firefighter who joined the tournée |
| Rue | `Street` | A street in a commune, with its house numbers and its shape on the map |
| Numéro / maison | `House` | One address on a street (`12`, `12bis`), with its position when known |
| Logement | `Dwelling` | One unit inside a building (`Apt 3`, `B2`) |
| Statut | `VisitStatus` | `TO_DO` (à faire), `DONE` (fait), `NOBODY_HOME` (personne), `COME_BACK` (repasser): exactly one per house or door |
| Repasser | `VisitStatus.comeBack` + `ComeBack` | A status: the resident asked to come back later, optionally on a day and at about an hour (« samedi vers 18 h », the `ComeBack` value, #81). A building, which has no status, may carry its own « repasser » |
| Mes rues | assignees | Streets the current member has taken |
| Libre | — | A street in the tournée that nobody in the team has taken (a member who left or was removed no longer counts, #91) |

---

## 3. Decisions taken

| Topic | Decision |
|---|---|
| Platform | **Flutter** (Dart): Android first; iOS kept open (same code, built in the cloud once an Apple developer account exists — no Mac needed) |
| Architecture | **Strict DDD, hexagonal**: domain (entities, value objects, aggregates) → application (use cases + ports) → adapters (Firestore, HTTP, map, UI). Riverpod for state and dependency injection |
| Language | **French only.** Strings in `res/values/strings.xml`; no other locale |
| Map | **MapLibre** (`maplibre_gl`, official Flutter plugin, offline regions on Android and iOS) with **OpenFreeMap** vector tiles (OpenStreetMap data, free, no key) |
| Street picking | Tap a road → reverse geocoding (IGN Géoplateforme) gives the BAN street → BAN gives its numbers with positions → the OpenFreeMap vector tiles (OSM) give its shape, stored once (#92) |
| Manual edits | Missing streets and numbers can always be added by hand, offline too |
| Sharing | Live sync through **Firebase Firestore**; its offline cache *is* the local store (no Room) |
| Offline | Explicit "download the tournée" step: all street documents into an unlimited Firestore cache + map tiles of the tournée area into a MapLibre offline region |
| Identity | Firebase **anonymous auth** + display name + 6-character join code or QR |
| Tournée identity | Number + centre de secours + code. Number + CS is unique across the app; the code is the secret used to join |
| Years | A tournée has one campaign per year. A new campaign copies streets, numbers and buildings; statuses and *repasser* start at ○ (v1.1) |
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

Where the app opens (T2.5, decided from the phone alone, so an offline cold start opens
where it should): a tournée open → it (the start screen); otherwise the phone holds streets
of its own (Corbeille included, as in M1) → « Mes rues »; otherwise a request to join waits →
« Demande envoyée » for the latest one; otherwise the phone knows tournées, none open → the
start screen; otherwise → « Bienvenue ». Nothing on the marking path ever waits for a
request.

Before the round (once):

1. Join the tournée with the QR code at the station.
2. Banner "Télécharger pour le hors-ligne" → one tap → streets + map tiles saved (Wi-Fi advised).
3. "Ajouter des rues" → tap each of my roads on the map → "Ajouter et me l'attribuer".
4. A cul-de-sac missing from the map → "Rue absente ? Saisir à la main".

In the street (often offline):

1. Open the app → the map shows my streets coloured; the panel lists them.
2. Tap *Rue des Lilas* → Street screen: odd side on the left, even side on the right.
3. Each door: **tap the tile** → ✓ fait. Again → ✗ personne. Again → ↻ repasser, which opens
   the house's sheet to say when (#81). Again → ○ à faire. Undo snackbar.
4. Building at n°8: tap → unit grid → tap each unit the same way.
5. "Repassez ce soir" → tap the tile up to ↻: its sheet opens by itself → « Aujourd'hui »,
   « 19 h » in « Quand repasser ? » → « OK » (or **hold** the tile → sheet → *↻ Repasser*).
6. Back in range: queued changes sync; the team map updates.

---

## 5. Screens

Agreed in the terminal on 2026-10-04 (ASCII variants), confirmed with visual mockups in
`docs/mockups/`. Phone portrait. Tap targets ≥ 48 dp; street tiles ≥ 56 dp high. Status is never
shown by colour alone: every status has a glyph too.

Glyphs: `○` à faire · `✓` fait · `✗` personne · `↻` repasser · `◐ 7/12` immeuble en partie.

**One gesture everywhere:** tap cycles `○ → ✓ → ✗ → ↻ → ○`; hold opens the details. Same rule for
house tiles and apartment tiles. A building tile opens its unit grid on tap.

**Text fields:** a value refused on the keyboard's « OK » (a street name, a number, numbers to
add, a door name) keeps the focus and the keyboard on its field, with the message under it; a
value taken behaves as with a button. **Typography:** French texts put a non-breaking space
(U+00A0) inside « » and before : ; ? !, so a line never wraps between a sign and its word
(checked on `app_fr.arb` by a test).

### 5.0 Mes rues and Importer des rues

In M1 the app opened on a plain list so the street screen could be used on a real area. From
T3.5 (#30) it is the start screen while no tournée is open; with one open, Accueil (5.3)
shows instead. Mockups: `docs/mockups/Start.dc.html` and `docs/mockups/Import.dc.html`.

```
┌──────────────────────────────┐     ┌──────────────────────────────┐
│ Tournée des calendriers      │     │ ←  Importer des rues         │
│ Mes rues · 3   Villefranche… │     │ Commune                      │
│ [ Filtrer les rues…        ] │     │ [Villefranche-sur-Saône (69400)]
│ Rue Nationale   ▓░░░ 31/403 ›│     │ 312 RUES · 1 COCHÉE [Tout cocher]
│ Rue Pierre Morin ░░░░  0/19 ›│     │ [ Filtrer les rues…        ] │
│ Route de Beaur… ████ ✓ 8/8  ›│     │ ☑ Rue Nationale       403 n° │
│                              │     │ ☐ Rue Pierre Morin     19 n° │
│                              │     │ ☑ Rue de Thizy  déjà importée│  ← greyed
│                              │     │ ☐ Rue Paul… dans la Corbeille│
│                              │     │                              │
│ [   + Importer des rues    ] │     │ [      Importer 1 rue      ] │
└──────────────────────────────┘     └──────────────────────────────┘
```

- **Mes rues** (`/`): the streets on the phone, French order (case and accents ignored:
  « Église » sorts with E), each with a progress bar and « done/total » (green « ✓ 8/8 » once
  complete); the filter ignores case, accents, hyphens and apostrophes. A row opens the street.
  No street yet: « Aucune rue pour l'instant » and « Importez les rues d'une commune pour
  commencer. ». Works offline. Debug builds
  show an app-bar action to the component gallery.
- **Top bar** (T2.7): Accueil's (5.3, Home mockup) already. With a tournée open, its title
  « Tournée 49 · 2026 ▾ » over the CS opens « Mes tournées »; with none, the title stays
  « Tournée des calendriers ». [⚙] opens Paramètres (5.9) either way; [👥] comes with Équipe
  (5.8). From T2.5 the app's name has a ▾ too and opens « Mes tournées » the same way, so a
  phone with streets of its own reaches « Créer » / « Rejoindre » without Paramètres.
- **Streets of the tournée** (T2.8): with a tournée open, « Mes rues », the street screen,
  the sheets, edit mode, « Importer des rues » and the Corbeille work on the streets of its
  current campaign in Firestore, shared live with the team; with none open, on the phone's
  own streets as in M1. Opening another tournée switches them at once: nothing of the one
  left stays on screen, and « Annuler » no longer undoes a change made there. Streets the
  member can no longer read (removed from the tournée) show as none, a street as gone.
- **Moving the phone's streets into the tournée** (T2.8): while a tournée is open, the member
  is one of its active members (as the phone last read it), the phone still holds streets
  (Corbeille left out) and they never went into this tournée, a card sits above the list
  (above « Aucune rue pour l'instant » too; on Accueil from T3.5, above the map):

```
┌──────────────────────────────┐
│ Tournée 49 · 2026 ▾   [👥][⚙]│
│ CS Villefranche              │
│ ┌──────────────────────────┐ │
│ │ 12 rues sont enregistrées│ │
│ │ sur ce téléphone.        │ │
│ │ [Les ajouter à la tournée]│ │  ← primary button
│ │        Plus tard         │ │  ← text button
│ └──────────────────────────┘ │
│ Mes rues · 3   Villefranche… │
│ [ Filtrer les rues…        ] │
└──────────────────────────────┘
```

  « 1 rue est enregistrée… » / « L'ajouter à la tournée » for one. While moving: « Ajout en
  cours… n/N » in place of the buttons. Done: « 12 rues ajoutées à la tournée », or « 10 rues
  ajoutées, 2 déjà dans la tournée » (« Aucune rue ajoutée, … » when all were there), and the
  card never comes back for that tournée (another tournée may still be offered them). « Plus
  tard » hides it for that tournée until the next launch. Each street goes as it is (marks,
  buildings, « repasser » times, removed numbers) with every stamp's `by` made the member's, times kept;
  a street whose BAN street (or id) the tournée already has is skipped and counted. The
  phone keeps its copies, only no longer shown while a tournée is open. No network needed to
  start: Firestore queues the new streets.
- **Pending sync** (T2.9): while a tournée is open and changes made on the phone have not
  reached the server, a line sits above « Ajouter des rues » on Accueil (5.3, Home mockup;
  above « Importer des rues » on this list until T3.5): a cloud glyph and « Modifications de 3 rues en attente d'envoi » (« … d'une rue … »
  for one), read out as such. It goes away once all is sent (§7).
- **Importer des rues**: the commune field searches geo.api.gouv.fr as you type (from two
  characters, after a 300 ms pause; a late answer to older text is ignored); a suggestion shows
  « name (postcode) », « … » after the first of several postcodes. Choosing one closes the
  keyboard and lists its BAN streets in French order, none ticked; streets already in « Mes
  rues » are ticked, greyed and « déjà importée »; streets in the Corbeille read « dans la
  Corbeille », unticked and free to tick. « Tout cocher » / « Tout décocher » act on the
  streets the filter shows (Corbeille ones included); the import takes every ticked street,
  shown or not. A ticked Corbeille street comes back with its marks, without the
  network. While importing: « Import en cours… n/N » and no way back. All imported → back
  to the list with « N rues importées », « N rues restaurées » or « N rues importées,
  M restaurées »; some failed → the screen stays, says why (no network
  first) and keeps them ticked so « Importer » tries them again. No network, service error and
  unknown commune each have a French message, with « Réessayer » for the street list.
- **Kept** (#78, decided 2026-10-17): « Mes rues » gives way to Accueil (5.3); « Importer des
  rues » stays as it is for a phone with no tournée open, and becomes the « Liste » tab of
  « Ajouter des rues » (5.4) while a tournée is open. The start button then reads « Ajouter des
  rues » and opens that screen.

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

Delivered in T2.5 (Welcome mockup): shown only where the app opens on a phone that holds
nothing (§4). The app's logo and name, « Notez chaque porte… », « Votre prénom » (« Visible
par votre équipe. » under it; « Prénom limité à 30 caractères. » when too long), then
« Créer une tournée » and « Rejoindre une tournée », disabled until the name is a valid
`MemberName`. Either keeps the name on the phone (`ChangeMemberName`, the one of Paramètres)
and opens its screen above « Bienvenue »; the field starts from the name kept.

From #75 (5.12): « Créer une tournée » shows only for an admin (so a fresh install, never yet
an admin, shows only « Rejoindre une tournée », in red), and the bottom of the screen shows
« Identifiant de l'appareil : … » with a copy button.

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
│ ──────────────────────────── │    │ │ CS Villefranche          │ │
│ Tournée 49 · CS Villefranche │    │ │ Campagne 2026            │ │
│        ▄▄▄▄ ▄ ▄▄▄▄           │    │ └──────────────────────────┘ │
│ Code K7P-2QX [⧉] [Partager]  │    │ [  Demander à rejoindre  ]   │
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
- **QR payload** (fixed in T2.6): the code's six characters and nothing else, `K7P2QX`
  (`JoinCode.value`): no URL, no prefix. The scanner of « Rejoindre » reads it with
  `JoinCode.parse`, like a typed code, so any other QR code is refused as an invalid code. Drawn
  dark on white whatever the theme, so it scans.
- An admin can regenerate the code from Équipe (old code stops working; members stay).
- **Only admins create a tournée** (and so add a centre de secours), from #75 (5.12).
- **Communes** (#78, Create mockup): between « Centre de secours » and « N° de tournée »,
  « Communes », a chip per commune picked (« Villefranche-sur-Saône (69400) » and ✕, a 48 dp
  target) then the field « + Ajouter une commune… », which searches geo.api.gouv.fr as « Importer
  des rues » does (two characters, 300 ms pause, late answers ignored); a suggestion tapped
  becomes a chip and empties the field, one already picked is not added twice. « Créer » stays
  off until at least one commune is picked; at most 50 (`Tournee.maxCommunes`). Each commune
  keeps the centre geo.api.gouv.fr gives (`centre`), so the map of 5.4 is centred offline.
- Delivered in T2.5 (Create, CreateTaken, Join mockups). Both screens first need the phone's
  account (§6.1): a line « Connexion au serveur… » while it signs in, « Hors ligne : créer ou
  rejoindre une tournée demande le réseau. » with « Réessayer » when it cannot; the server
  is asked nothing before.
  - **Nouvelle tournée:** while « Centre de secours » has the focus and nothing is picked, a
    list under it: the known centres whose station key contains the typed one (all of them
    before a station is named), then « + Ajouter « villef » » unless a known centre is that
    same station; a pick fills the field, a new key typed forgets it. « Nom limité à 80
    caractères. » when too long. « N° de tournée » (« Un numéro de 1 à 9999. ») and
    « Année » (the phone's year, « Une année de 2000 à 2099. »). 300 ms after the centre or
    the number last changed, the server says whether the pair exists (a late answer to older
    input is ignored; no answer offline: « Créer » still asks, and the server refuses a
    duplicate): « ⚠ La tournée 49 du CS Villefranche existe déjà. Demandez le code ou le QR
    code à la personne qui l'a créée. » in a red frame, the number framed red, « Créer »
    disabled, and « Rejoindre avec un code » (replaces this screen with « Rejoindre »).
    « Créer » keeps the tournée among the member's and opens it at once; offline « Pas de
    réseau. Réessayez une fois connecté. », a number taken meanwhile shows as taken. Then,
    the form frozen, a card « Tournée 49 · CS Villefranche est prête. Montrez ce code à
    l'équipe. », the QR code (Équipe's, larger), « 234-567 » with its copy button (Équipe's)
    and « Partager » (Équipe's text); « Continuer » (and back) open the start screen on the new tournée, where the
    phone's streets are offered to it (5.0).
  - **Rejoindre:** « Scanner le QR code » opens the camera full screen (permission asked
    then; refused: « L'appareil photo n'est pas disponible. Saisissez le code à la main. »),
    which closes on the first QR code read; one that is not a code: « Ce QR code n'est pas
    celui d'une tournée. ». Or « Code » in two boxes of three: upper-cased, dash and spaces
    dropped, a whole code typed or pasted in the first fills both, at most three characters
    each; the first box full and valid moves on to the second; a character outside the
    alphabet: « Un code n'a que des lettres et des chiffres, sans 0, O, 1, I ni L. ». A
    complete code is looked up at once: the card « 49 | Tournée 49 · CS Villefranche » over
    « Campagne 2026 » (**no member or street count**: `joinCodes` holds only the preview
    fields, §6.2 — the mockup's « 6 membres · 60 rues » is not shown), « Aucune tournée n'a
    ce code. Vérifiez-le… », or « Pas de réseau : la tournée ne peut pas être affichée. »
    with « Réessayer ». « Demander à rejoindre » (the mockup's label) sends the request and
    opens « Demande envoyée »; a tournée already in « Mes tournées » sends nothing: « Cette
    tournée est déjà dans « Mes tournées ». ».

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
- Delivered in T2.5 (JoinPending mockup): the clock in a yellow ring (« Demande en
  attente » for screen readers), « Demande envoyée », « Tournée 49 · CS Villefranche », the
  text and « Cet écran s'ouvrira tout seul sur la tournée dès que vous serez accepté. »,
  « Annuler la demande » at the bottom. Accepted: the tournée is opened and the start
  screen shows it. Refused: « Demande refusée » (a message over the next screen) and back to
  where the app would open now (§4: « Bienvenue », or the start screen when the phone has
  streets or a tournée open). Cancelled: withdrawn (offline too) and the same way back,
  without the message. Offline nothing comes and the request stays, across restarts. It is
  where the app opens only when the phone has nothing else (§4); while it has a start screen
  a back arrow leads there, so marking never waits for a request.
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
│ ☁ Modifications de 3 rues en…│  ← only while offline writes are pending
│ [   Ajouter des rues   ]     │
└──────────────────────────────┘
```

- **City zoom:** each street of the tournée drawn over the map, coloured by progress:
  fait (all done), en partie, à faire, libre (in the tournée but nobody took it).
- **Street zoom (≥ 16):** one dot per house at its BAN position, coloured and glyphed by status
  (`●` fait, `✗` personne, `↻` repasser, `○` à faire). Houses entered by hand have no position
  and appear only in the lists.
- Tapping one of the tournée's streets on the map opens its street card (see 5.4) with *Ouvrir*.
- The rows of « Mes rues » open the Street screen; a row under « Autres rues de la tournée »
  opens that street's card over the map, as a tap on its line does (#93). Dragging the panel
  up shows the full list; down leaves only the handle and the totals.
- A "locate me" button centres the map on the phone's position (location permission asked
  the first time it is tapped, never at launch).
- Delivered in T3.4 (`ui/map/TourneeMap`, used by 5.3 and 5.4): OpenFreeMap « liberty »;
  street lines under the map's labels, widening with the zoom (« libre »: dark grey dashes as
  wide as the other lines, on a wider opaque white casing so they stand out from the base
  map's grey roads; the casing alone still shows on a GPU that draws no dashes); from zoom 16
  a 30 dp dot per house with the tile glyphs (`✓` fait, `✗`, `↻`, `○`, `◐` building in part,
  dashed ring) and its number under it; the road picked on 5.4 as a dark casing with a white
  core. A tap on a street or on one of its dots names the street; elsewhere it gives the
  point. North stays up (no rotation, no tilt). « Me localiser » (48 dp round, top right)
  centres at zoom 17 and then shows the phone's dot; refused, off or no fix: a message
  (« Réglages » when refused for good). The ⓘ attribution stays visible.
- Delivered in T3.5 (#30, Home and HomeZoom mockups; `ui/screens/home/`): Accueil is the
  start screen while a tournée is open (`/`; with none, « Mes rues » of 5.0 as in M1). Under
  the top bar of 5.0 and its cards (« Administrateur · pas membre », the phone's streets to
  move), the map fills the screen. **Legend** top left, clear of « Me localiser »: line
  samples « faite · en partie · à faire · libre » (« libre » dashed, as wide as the others,
  without the map's white casing), or, once the map is at zoom ≥ 16, house
  dots « fait · personne · repasser · à faire »; a tap folds it into a « Légende » chip, a tap
  on the chip unfolds it (said « Masquer / Afficher la légende »). **Panel**: handle and
  totals « Mes rues · 31/50 » (doors done of the member's streets; « Rues · 9/38 » over every
  street for a visiting admin) and « Équipe : 43 % »; then the member's streets, « Vous n'avez
  pas encore de rue. » when they cover none, and **« AUTRES RUES DE LA TOURNÉE (n) »** with the
  others (free or someone else's), so no street of the tournée is out of reach before anyone
  takes one; « Aucune rue dans la tournée pour l'instant. » with none. Then the pending-sync
  line and « Ajouter des rues ». It rests on half the room; dragging the handle up shows the
  whole list, down only the totals (a quick flick goes one step, a slow release to the nearest
  height); a tap on the handle shows the whole list, or from there brings it back to rest.
  The map keeps « Me localiser », the attribution and its fit clear of the panel at rest.
  **A street tapped on the map** replaces the panel by its street card (5.4, since #31; it
  replaced HomeZoom's « Ouvrir Rue des Lilas · 31/42 »): name, commune, « 31/42 faits » and who
  covers it, « Ouvrir » and « Me l'attribuer » / « La faire aussi » / « Ne plus la faire »,
  offline; its ✕ (48 dp, top right, level with the handle, « Fermer »), a tap elsewhere on the
  map, or the back gesture, brings the list back. The street
  whose card shows has its line lit up (the dark casing and white core of 5.4).
  **A row under « Autres rues de la tournée »** (#93) shows the same card, so a street can be
  taken without finding its line (or when it has none), and moves the map to the street: its
  line, else its houses' positions, plus 60 m; the map stays there once the card is closed. A
  street with no place on the map (typed in by hand) leaves the map where it is. The rows of
  « Mes rues » (every row for a visiting admin) still open the Street screen. The map opens
  on the tournée's streets, else its communes, and stays where the member puts it when the
  team adds a street. Not yet: the download banner (M4).
- **Lines filled in the background** (#92, `presentation/home/missing_shapes.dart`): each
  time Accueil reads the streets, those without a line on the map but with a house on it
  (`Street.needsShape`: imported from a list, or added before their road came) get their
  road from the map's tiles, one street at a time, each **once per session** whatever the
  answer; a failure (offline, service down) stops the run and the next waits 2 minutes,
  when the street that failed is asked again. Nothing is shown meanwhile: the line appears
  when it is stored. Streets typed in by hand (no position) keep no line. Nothing on the
  marking path waits for it.

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
- Delivered in T2.7: the rows keep the order the phone met the tournées (opening one does not
  move them); the open one shows ● and ✓, another ○ (a tap opens it and closes the sheet),
  a request a dashed ○ in grey, « CS … · votre demande est en attente », and cannot be tapped.
  No tournée: « Aucune tournée pour l'instant. ». Still to come: the progress « · 41 % » (with
  the streets on Firestore), « Pas téléchargée » (M4).
- Delivered in T2.6c: another tournée (not the open one) where join requests wait shows
  « CS … · 1 demande en attente » (« 2 demandes… ») and a red dot at the end of its row, said
  by screen readers (« Tournée 12 · 2026, CS Villefranche, 1 demande en attente, ouvrir »);
  its team is followed from the phone's copy first, offline too. The open tournée's requests
  stay on 👥 only.
- **A tournée lost** (T2.6c): when the server says the member was removed (« Retirer ») or
  the tournée deleted, the phone forgets it at once (its row leaves « Mes tournées »; when it
  was the open one, the app goes back to the start screen with none open, whatever screen
  was shown) and says so over the next screen, as « Demande refusée »: « Vous avez été retiré
  de la tournée 49. » or « La tournée 49 a été supprimée. ». Only the server's answer counts:
  offline, or for a tournée never read on this phone, nothing is forgotten; leaving and
  deleting from this phone are not told (the member did it).
- Delivered in T2.5: « + Créer une tournée » (red) and « Rejoindre une tournée » under the
  rows close the sheet and open 5.2 above the screen; a phone without a name asks « Votre
  prénom » (Paramètres' sheet) first and opens nothing if it is closed without one. With no
  tournée open, the app's name in the title opens the sheet too.
- From #75 (5.12): « + Créer une tournée » only for admins; admins also get « Toutes les
  tournées › » under « Rejoindre », and a visited tournée shows « CS … · administrateur ».
- Delivered in T2.6: 👥 sits left of ⚙ while a tournée is open (none otherwise) and opens
  Équipe; a red dot on it while a request waits in the open tournée, said by screen readers
  (« Équipe, 1 demande en attente »). The team is followed as long as a tournée is open.

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
│ Rue Pierre Morin          ✕  │  ← street card (bottom sheet), ✕ closes it
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
| In the tournée, libre (nobody, or only people no longer in the team) | progress | *Me l'attribuer* · *Ouvrir* |
| Mine (maybe shared) | progress, other members | *Ouvrir* · *Ne plus la faire* |
| Someone else's | progress, who covers it | *La faire aussi* · *Ouvrir* |

- Tapping a road calls the reverse geocoder at that point (type `street`) to get the BAN street;
  then BAN gives the numbers and their positions, and the map's tiles give the road's shape. All three
  are needed only once per street, when it is added: **this screen needs the network**.
  Offline, the map still shows and existing streets can still be taken, but adding says
  "Connexion nécessaire pour ajouter une rue" and offers manual entry.
- The search box finds a street by name (BAN search, limited to the tournée's communes) and
  centres the map on it.
- A road with no BAN match (private road, new estate): the card says so and offers manual entry.
- **Carte | Liste** (#78, Pick and AddList mockups): under the title (✕ closes), two 48 dp
  tabs, the chosen one in ink. **Carte** is the map above, opened on the tournée's communes
  (their centres, 2 km around each, `communesArea`), on its streets when no commune has a
  centre (`tourneeArea`), on France when neither; works offline. **Liste** is the checklist of
  « Importer des rues » (5.0) on the tournée's communes: no commune field, a chip per commune
  when there are several (the first chosen at once), « déjà dans la tournée » on a street the
  tournée has, « Ajouter N rues », « Ajout en cours… n/N », then back with « N rues ajoutées à
  la tournée ». A tournée without commune (created before #78) searches the commune as in
  5.0. Delivered in #78: the tabs, the map opened on the communes and the list.
- **Delivered in #31** (`presentation/add_streets/`, `presentation/street_card/`,
  `ui/components/street_card_sheet.dart`): the screen opens on **Carte**. Under the tabs, the
  search pill « Rechercher une rue » (48 dp; the keyboard's search key asks, ✕ empties it) and
  « ✎ Saisir une rue à la main » (48 dp outline, always there, offline). **A tap on a road**
  marks the point (dark dot in a faint halo) and shows the card « Recherche de la rue… »,
  then the street; for a street to add, its road is asked of the map's tiles at once
  (`LookUpStreetShape`) and highlighted when it comes (only the point otherwise), and that
  road is the one stored by « Ajouter… », so it is asked once. **« Ajouter… » never waits
  for the road** (#92): without it yet, the street is added at once, keeps the road
  highlighted when it comes and is given it then (`FillStreetShape`); if the road could
  not be found, Accueil fills it later (5.3). **A tap on a tournée
  street's line or dot** shows its card at once, offline, with its own road. The card (white
  sheet, handle, name in 28 dp titles over the commune, facts in grey chips, red then outline
  button): to add « 19 numéros · Pas encore dans la tournée », « Ajouter et me l'attribuer »,
  « Ajouter sans m'attribuer » (« Ajout en cours… » meanwhile), « Rue absente de la carte ?
  Saisir à la main »; once added it becomes the street's card. A tournée street « 31/42
  faits » and « Libre » / « Vous la faites (avec Manu) » / « Faite par Manu et Julie »
  (teammates named in the team's order; « Faite par un autre membre » when none can be
  named, the team not read yet), with the actions of the table; take and release need no network and have no
  « Annuler » (the other button undoes it). Failures: « Connexion nécessaire pour ajouter une
  rue » (offline), « Aucune rue connue ici » (no BAN match), « Le service des adresses ne
  répond pas », each with a hint and « Saisir une rue à la main ». The card's own ✕ (48 dp,
  top right, level with the handle, « Fermer »; the name keeps clear of it) closes it, and so
  does the back gesture, first; the top bar's ✕ closes the screen. **The search** lists « name / commune » rows over the map
  (« Aucune rue trouvée. », « Connexion nécessaire pour chercher une rue. »); it searches the
  tournée's communes, or the communes of its streets for a tournée without commune; picking a
  row moves the map 200 m around the street and shows its card. A newer tap or search always
  wins over a late answer.

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

- **✕** removes a number (undo snackbar; a number that already has a mark — a status, a
  « repasser », or a mark on one of its doors — asks for confirmation first). The
  house goes to the Corbeille with its marks (5.11).
- **+ numéros** opens the *Ajouter des numéros* sheet: one number, a list or a range
  (`12bis, 21-25`), with a preview. New numbers land on the right side automatically.
  Numbers already in the street are skipped; a number in the Corbeille comes back with its
  marks.
- **Tapping a tile** opens a small sheet: change the number (`3` → `3bis`, refused when
  another house, shown or in the Corbeille, has it), then *Transformer en immeuble…* (5.7) for
  a house, or « Ouvrir l'immeuble » for a building: every change to a building itself (floors,
  doors, back to a single house) is made from its grid (5.7, T1.18).
- The name field renames the street for the whole team.
- *Ne plus la faire* removes me from its assignees; *Supprimer* deletes it for everyone
  (confirmation, any member may do it — see Q2).
- A manual street has no shape on the map; it appears in the lists, marked "saisie à la main".

Edit mode details fixed in T1.10 (`lib/presentation/edit_street/`,
`lib/ui/screens/edit_street/`, mockups Edit and Numbers):

- **Top bar** « ✕ Modifier la rue [OK] ». The name field (« Nom de la rue ») is stored when the
  screen is left — « OK », ✕ and the back gesture all leave the same way —, when the
  keyboard's « OK » is pressed and when the app goes to the background (it may then be killed;
  T1.14, as the house sheet's texts); a name equal to the stored one (once cleaned, §6.1
  `StreetName`) stores nothing. A blank name says « Le nom de la rue ne peut pas être vide. »
  (« Nom limité à 150 caractères. » when too long) and keeps the screen open; going to the
  background then stores nothing and leaves the name and its message in the field.
- **Numbers**: dashed tiles of 56 dp, odd on the left, even on the right, one column when the
  street has numbers on one side only (decided as on the street screen); a building reads
  « 8 · immeuble ». « + numéros » closes each column (both open the same sheet); under them
  « Touchez un numéro pour le renommer ou le transformer en immeuble. ».
- **✕** removes at once with « N° 3 supprimé [Annuler] » (4 s, the street screen's snackbar).
  A number with marks (`House.hasMarks`) asks first: « Supprimer le n° 3 ? — Ce numéro a des
  marques (statut, « repasser » ou portes marquées). Elles partent avec lui à la
  Corbeille. [Annuler] [Supprimer] ». Opening any sheet hides the snackbar.
- **« Ajouter des numéros »**: field « Numéros » (placeholder `12bis, 21-25`, keyboard open),
  helper « Un numéro, une liste ou une plage (21-25). ». The preview follows each key:
  « Aperçu · 6 numéros », the numbers (up to twelve, then the first ten, « … » and the last),
  « Déjà dans la rue : 4 » (skipped) and « Revient de la Corbeille avec ses marques : 5 ». A
  wrong item is named instead: « « x » n'est pas un numéro. », « « 12bis-14 » : une plage relie
  deux numéros simples, comme 21-25. », « « 123456 » : 99999 au plus. », « « 12é » : après le
  numéro, un complément en lettres sans accent (12bis, 3A). », « « … » : complément de 16
  caractères au plus. », « 500 numéros au plus à la fois. ». « Ajouter » is disabled until a
  number would be new; the sheet closes once added. Adding has no « Annuler » (✕ removes).
- **Tap a number** → a small sheet « 3 Rue des Lilas »: field « Numéro » with « Changer le
  numéro » (refusals: the number messages above, « Le 5 est déjà dans la rue. », « Le 7 est
  dans la Corbeille : ajoutez-le avec « + numéros » pour le retrouver avec ses marques, ou
  choisissez un autre numéro. »; the same number just closes), then « N° 3 → 3bis
  [Annuler] ». A house offers *Transformer en immeuble…* (« Décrire l'immeuble », §5.7, then
  back to the edit mode). A building offers « Ouvrir l'immeuble » (dark outline, building icon)
  instead (T1.18): its grid opens over the edit mode, and « Changer en maison » chosen there
  closes it back to the edit mode with « N° 8 changé en maison [Annuler] ».
- **« Supprimer la rue »** (red outline) asks « Supprimer la rue ? — « Rue des Lilas » part à
  la Corbeille avec ses numéros et leurs marques, pour toute l'équipe. » then goes back to
  « Mes rues », where the street no longer shows. **« Ne plus la faire »** (T3.3, dark
  outline, left of « Supprimer la rue », both half width) shows only to a member who covers the
  street: it removes them from its assignees at once (`ReleaseStreet`, no confirmation, no
  « Annuler »), the edit mode stays open and the button goes. Otherwise « Supprimer la rue »
  takes the whole width.
- Not yet: the Corbeille screen (§5.11) comes in M2.

« Rue à la main » delivered in #31 (Manual mockup, `/ajouter-des-rues/a-la-main`,
`presentation/manual_street/`): « ← Rue à la main »; « Nom de la rue » (« Nom limité à 150
caractères. »; a blank name only disables the button); « Commune », a list of the tournée's
communes (else those of its streets), the first chosen; a tournée with neither searches its
commune as « Ajouter une commune… » does (network); « Du n° » / « Au n° » (digits), « Les deux |
Impairs | Pairs », « Numéros en plus » (« Séparés par des virgules. »); « APERÇU · 59 NUMÉROS »
with the numbers (the add-numbers sheet's short list) or the item that is wrong; « Fonctionne
sans réseau. La rue n'aura pas de tracé sur la carte. »; « Ajouter la rue » (enabled with a
name, a commune and a number) gives the street to the member who typed it and goes back to the
map with « « Chemin des Vignes » ajoutée à vos rues. ».

```
  number sheet of a building (T1.18)
┌──────────────────────────────┐
│ 8  Rue des Lilas             │
│ Numéro [ 8                 ] │
│ [    Changer le numéro     ] │
│ [ 🏢  Ouvrir l'immeuble    ] │
└──────────────────────────────┘
```

### 5.6 Rue — two sides of the street (used 95 % of the time)

```
┌──────────────────────────────┐
│ ← Rue des Lilas          [✏] │  ← edit mode (5.5)
│   31/42 · ✗3 · ↻1 ☐ Masquer faits │
│   côté impair │  côté pair    │
├──────────────┼───────────────┤
│ [ 1     ○ ]  │ [ 2     ✓ ]   │
│ [ 3     ✓ ]  │ [ 4     ✓ ]   │
│ [ 3bis ✗×2]  │ [ 6     ○ ]   │
│ [ 5     ↻ ]  │ [▦ 8 ◐7/12 ›] │
│ [ 7     ○ ]  │ [10     ○ ]   │
│ [ 9     ○ ]  │ [12     ✗ ]   │
│ [11     ○ ]  │ [14     ○ ]   │
├──────────────┴───────────────┤
│ 7 → Personne     [Annuler]   │  ← snackbar, 4 s
└──────────────────────────────┘
```

- Odd numbers on the left, even on the right, each column sorted ascending
  (`3 < 3bis < 3ter < 3quater < 3A < 4`). Both columns scroll together.
- Tile: number, status glyph, tinted background per status, and « ×3 » after the glyph once
  the house was tried twice or more with nobody home (#80). Nothing else: no note (§8.3).
- **Tap** cycles `○ → ✓ → ✗ → ↻ → ○` (light haptic tick); **hold** opens the Fiche maison.
  The tap that brings a house to **↻ opens its Fiche maison by itself** (#81), to say when to
  come back; see §5.7.
- Building tile: tap opens the Immeuble grid. Whatever its status (○, `◐ n/m`, ✓, ↻), it shows
  the building icon (▦, the one of « Transformer en immeuble… ») before its number and a « › »
  at its right edge, in the colour of its text; single houses have neither (T1.21). TalkBack
  ends its label with « ouvrir »: « Numéro 8, immeuble, 7 sur 12 faits, ouvrir », « Numéro 8,
  immeuble, fait, ouvrir ». On a narrow phone the number gives way first (ellipsis), but keeps
  room for a digit: past that, the glyph and count shrink, so a tile never overflows (« 12bis »
  with « ◐ 12/120 » in a half column at 360 dp and 1.3× text).
- A street with numbers on one side only shows a single column.

Details fixed in T1.7 (`lib/presentation/street/`, `lib/ui/screens/street/`):

- Each side is listed in its own order; a row of the list is the n-th tile of each side (as the
  mockup's two columns). Rows are built lazily with a fixed height, so a street of 400 numbers
  scrolls smoothly.
- Tile look: a house shows its status (↻ tinted blue for « repasser »). A building shows ✓ when
  every door is done, `◐ n/m` when some are, ○ (or ↻ with its own « repasser ») when none is —
  doors « repasser » count as not done, so a building whose doors are all ↻ shows ○ (T1.16). No
  dot: the note it marked is gone (T1.20).
- Header « 31/42 · ✗ 3 · ↻ 1 » counts every door, whatever is hidden; ↻ counts the doors
  « repasser » plus the buildings with their own « repasser » (`Progress.toComeBack`). « Masquer faits » hides the
  tiles shown ✓ (houses done, buildings all done) and is remembered per street on the phone.
  The single column is decided on all the street's numbers, not on the visible ones.
- A tap gives a light haptic tick at once, then TalkBack hears « Numéro 7, personne » and the
  snackbar « 7 → Personne [Annuler] » shows for 4 s, replacing any previous one; « Annuler »
  undoes that last tap only. A tap to ↻ shows no snackbar (the previous one goes too): TalkBack
  hears « Numéro 7, repasser » and the sheet opens, with its own « Annuler » (#81, §5.7). The snackbar belongs to the screen and leaves with it. While no
  snackbar shows, the hint « Appui : ○ → ✓ → ✗ → ↻ → ○ · Appui long : détails » floats in its
  place. A refused undo (the number was removed meanwhile) does nothing.
- A street missing from the phone, or in the Corbeille, shows « Cette rue n'est plus sur ce
  téléphone. » with the back arrow.

Tries with nobody home, fixed in #80 (`NobodyHomeTries`, §6.1):

- A house (or a door) counts its **tries with nobody home**: the first « personne » is try 1;
  « Repassé, toujours personne » in its sheet (§5.7) adds one. The tap cycle is unchanged
  (`○ → ✓ → ✗ → ↻ → ○`): moving into ✗, by a tap or the status control, never adds a try, it
  only makes sure there is at least one; ↻ → ○ (the end of the tap cycle) resets the count, so
  ✗ → ↻ → ○ → ✓ → ✗ by taps starts again at 1. The count is kept on ✓ and ↻.
- The tile shows « ×N » after the glyph **from 2 tries**, on ✗, ✓ and ↻ alike (a house done
  at the third visit keeps its « ×2 »); door tiles of the grid too. A building tile shows none.
- TalkBack: « Numéro 7, personne, 3e passage » on ✗; « Numéro 7, fait, 2 passages sans
  personne » (or « repasser, … ») on the other statuses; nothing more below 2 tries. The
  announcement after a tap uses the same words.
- The snackbar says « 7 → Personne (3e passage) [Annuler] » whenever a house becomes ✗ with
  2 tries or more (« Repassé, toujours personne », or a tap from ✓ that keeps an earlier
  count); « 7 → Personne » below.
- A new campaign (v1.1, §5.10) starts every house to do, hence at 0 tries.

### 5.7 Fiche maison (hold a tile) and Immeuble (by floor)

```
  single house (hold)                 building (tap)
┌──────────────────────────────┐    ┌──────────────────────────────┐
│ (street screen, dimmed)      │    │ (street screen, dimmed)      │
├──────────────────────────────┤    ├──────────────────────────────┤
│ 5 Rue des Lilas              │    │ ✕ 8 Rue des Lilas  ◐ 15/24   │
│ ┌──────┬──────┬──────┬─────┐ │    │ (Esc. A | Esc. B)  ← if > 1  │
│ │  ○   │  ✓   │  ✗   │  ↻  │ │    │ 5e  [51✓][52○][53✗][54↻]     │
│ │À fai.│ Fait │Pers. │Rep. │ │    │ 4e  [41✓][42✓][43✓][44○]     │
│ └──────┴──────┴──────┴─────┘ │    │ 3e  [31✗][32✓][33✓][34✓]     │
│ ✗ 2 passages sans personne   │    │ 2e  [21✓][22✓][23○][24✓]     │
│ [Repassé, toujours personne] │    │ 1er [11○][12✓][13✓][14✗]     │
│  (yellow on ✗ / ↻, else grey)│    │ RdC [01✓][02○]               │
│ Quand repasser ? (grey ≠ ↻)  │    │                              │
│ (Aujourd'hui)(Demain)(Sam. 24)…→   │                              │
│ Heure [ 18 h            ▾ ]  │    │                              │
│ Le samedi 24 oct. vers 18 h  │    │                              │
│ [ Transformer en immeuble… ] │    │                              │
│ Modifié par Léa · 14:02      │    │                              │
└──────────────────────────────┘    │                              │
                                    │ Appui : ○→✓→✗→↻→○ · détails  │
                                    │ [Gérer l'immeuble ▾][Repasser]│
                                    └──────────────────────────────┘
                                      ▾ opens: Modifier les étages
                                               Modifier les portes
                                               Changer en maison
```

- **Floors from top to bottom**, the way you climb the stairs. One row per floor, its doors
  left to right. A row with more doors than fit wraps onto a second line under the same label.
- Same gesture as everywhere: tap cycles `○ → ✓ → ✗ → ↻ → ○`, hold opens the door's sheet.
- **Several staircases:** a segmented control (Esc. A | Esc. B …) above the floors, shown only
  when the building has more than one; the header count covers the whole building.
- A building whose floors are unknown is a single row labelled "Logements".
- Building status is derived, never stored: done when all doors are done, to do when none are,
  otherwise partial (`◐ done/total`).
- No free note on a house, a door or a building (T1.20, §8.3): only the status and « Quand
  repasser ? », a day and an hour (#81), no free text.

Fiche maison details fixed in T1.8 (`lib/presentation/house_sheet/`,
`lib/ui/screens/street/house_sheet.dart`):

- **Hold** a single-house tile opens the sheet (a building tile: #13). Opening it hides the
  snackbar of the last tap: its « Annuler » would put the whole house back, wiping the sheet's
  changes. The sheet shows « 5 Rue des Lilas », the status control (screen readers: a radio
  group « Statut »), the « Quand repasser ? » block, and the last change.
- **A tap to ↻ opens the sheet by itself** (#81, mockup HouseComeBack), on the street screen
  and on a door of the Immeuble grid alike: the tap is stored and said as any tap, but instead
  of its snackbar the sheet opens, so the day can be given at once. That sheet has no
  *Transformer en immeuble…*; it keeps the tries block (on ↻ it is enabled), and ends with
  « Annuler » (outlined) and « OK » (accent red), 52 dp, side by side. « Annuler » waits for the
  choices already made to be stored, then puts back the house (or door) as it was before the
  tap — status, time, tries — through the same undo as the snackbar's, and closes; nothing else
  is offered to undo afterwards. « OK », a swipe down or a tap on the dimmed street close it,
  the house staying ↻ with what was chosen. A held sheet has neither button. Every sheet
  scrolls when it is taller than the screen.
- **Each control is stored at once** through `SetHouseDetails` (one change each, stamped); the
  tile behind follows live. A control set to what the house already has stores nothing, so
  opening and closing a sheet never stamps a house. Changes run one after the other, each on
  the house as the previous one left it.
- **Status control** (T1.16): four choices « ○ À faire | ✓ Fait | ✗ Personne | ↻ Repasser »,
  glyph above the word, 64 dp high, a visible line between two choices, the chosen one in ink
  (the rounded outline clips it at either end).
- **« Quand repasser ? »** (T1.16): a block always under the status control, so choosing a
  status never moves the sheet — blue while « Repasser » is chosen, greyed (nothing answers)
  otherwise. Choosing « Repasser » starts without a time; choosing another status drops it
  (§6.1). The line of the last change keeps its place before the first change, so that change
  does not move the sheet either.
- **Day and hour** (#81, replacing the free hint of ≤ 20 characters; mockup HouseComeBack): the
  block holds « Quand repasser ? », a row of **day chips** scrolling sideways — « Aujourd'hui »,
  « Demain », then the next five days as « Sam. 24 » (a week in all, from today on the phone's
  calendar and clock, `Clock` port) — 40 dp pills in a 48 dp tap target, the chosen one filled
  in the come-back blue; screen readers hear a radio group « Jour » and the dated chips whole
  (« samedi 24 octobre »). Then « Heure » and a list « Pas d'heure », « 8 h » … « 21 h », greyed
  until a day is chosen. Then a summary line: « Pas de jour choisi », « Aujourd'hui »,
  « Demain vers 18 h », « Le samedi 24 oct. vers 18 h ». A day already gone shows as past:
  « C'était hier vers 18 h », « C'était le mercredi 14 oct. »; such a day (or one a teammate
  set past the week) gets a chip of its own, in date order (« Hier » before « Aujourd'hui »).
  Each choice is stored at once (one `ComeBackSet` each, stamped); a new day keeps the hour
  chosen; tapping the chosen day again leaves no time at all (the hour with it): « ↻ » without
  time stays valid. A building's own « Repasser » (ticked) shows the same block.
- **Last change**: « Modifié par Léa · 14:02 » today, « Modifié par Léa · 3 oct. à 14:02 »
  before, in the phone's time zone; « par vous » for the member on the phone; nothing when the
  house was never changed. The name is read from the open tournée's team (offline from the
  phone's copy); when the phone cannot name anyone (no tournée open, a member no longer in the
  team) the line is « Modifié à 14:02 » / « Modifié le 3 oct. à 14:02 » (#89).
- *Transformer en immeuble…* (with the building icon of the mockup) closes the sheet and opens
  « Décrire l'immeuble »; « Valider » there opens the new building's grid (one sheet at a time).
- **Tries with nobody home** (#80, mockup HouseNobody): a block between the status control and
  « Quand repasser ? »: « ✗ 2 passages sans personne » (« 1 passage… », « 0 passage… ») and the
  button « Repassé, toujours personne » (52 dp). Pale yellow (`#FDF3DC`, the button outlined
  `#D99A22`) with the button enabled while the status is ✗ or ↻; greyed, button disabled,
  otherwise. It is **always there**, like « Quand repasser ? », so choosing a status never moves
  the sheet: a block appearing on ✗ would push the status control up and bring the button under
  the finger for a second tap.
- **« Repassé, toujours personne »** waits for every change asked before to be stored, then
  closes the sheet; the screen behind makes the house ✗ with one more try (a ↻ loses its
  time, as with any other status), stamped like any mark, and shows « 7 → Personne (3e passage)
  [Annuler] » with the announcement « Numéro 7, personne, 3e passage ». « Annuler » puts the
  house back as it was (status, time, tries). The door sheet does the same over the grid
  (« 51 → Personne (3e passage) »); the building's own sheet has no such block.

Immeuble details fixed in T1.9 (`lib/presentation/building/`, `lib/ui/screens/building/`):

- **Tap** a building tile opens the grid, a full-height sheet (a 40 dp strip of the street
  stays visible). **Hold** a building tile opens the building's own « Repasser » sheet, as the
  button under the grid does: no status (a building's status comes from its doors), the blue
  « ☐ ↻ Repasser » box (ticking it shows « Quand repasser ? », its day chips and hour), no
  *Transformer en immeuble…*.
- Header « ✕ 8 Rue des Lilas  ◐ 15/24 »: the ◐ glyph is always drawn, the count covers every
  staircase. A long street name ends with « … », the count always shows.
- **Closing** (T1.22): the ✕ left of the number (48 dp, « Fermer » for screen readers; the
  same ✕ as « Modifier la rue » and « Modifier les portes ») closes the grid exactly as a swipe
  down does, which still works: back to the screen that opened it, the door marks kept, the
  snackbar of the last door gone with the grid. The staircase control « Esc. A · 7/12 | Esc. B · 8/12 » (48 dp, not the mockup's 44:
  tap targets) shows only with more than one staircase; the grid opens on staircase A and comes
  back to it when the chosen one disappears.
- Floors top first, labelled RdC, 1er, 2e… (« Logements » for unknown floors); four doors a row,
  wrapping under the label; a floor without doors is hidden. A door shows its label and glyph
  in the status colours (↻ for « repasser »).
- **Under the grid** (T1.18): « Gérer l'immeuble ▾ » next to « Repasser » (48 dp each; T1.20).
  « Gérer l'immeuble » opens a menu sheet titled « Gérer l'immeuble » — a sheet like every
  other choice of the app, rows of 56 dp — with « Modifier les étages » (« Décrire
  l'immeuble » over the grid), « Modifier les portes » (its screen over the grid, back to it
  when left) and « Changer en maison ». The last asks first when a door has marks
  (« Changer en maison ? — Les portes de l'immeuble et leurs marques (statuts,
  « repasser ») seront perdues. [Annuler] [Changer en maison] »), then the grid closes back
  to the screen that opened it (street, or edit mode), which shows « N° 8 changé en maison
  [Annuler] ». Opening the menu hides the snackbar of the last door.
- **Tap** a door: light haptic tick, TalkBack hears « Escalier A, 5e, porte 51, fait » (the
  staircase is named only when there are several; « Logements » is not said), and the snackbar
  « 51 → Fait [Annuler] » shows for 4 s (a tap to ↻ opens the door's sheet instead, with
  « Annuler » and « OK », as on the street screen, #81) over the hint « Appui : ○ → ✓ → ✗ → ↻ → ○ · Appui
  long : détails », as on the street screen. The snackbar belongs to the grid and leaves with it;
  opening any sheet over the grid hides it.
- **Hold** a door: the door sheet, the Fiche maison's controls (four statuses, the tries with
  « Repassé, toujours personne », « Quand repasser ? ») without *Transformer en immeuble…*, titled « 51 · Esc. B · RdC · 8 Rue des Lilas » (staircase only when several).
  Stored through `MarkDwelling`: only that door is stamped.

« Décrire l'immeuble » details fixed in T1.9:

- Title « Décrire l'immeuble », then « 8 Rue des Lilas ». A house starts at 1 staircase, RdC–2e,
  2 doors a floor, « 51, 52… »; « Modifier les étages » starts from the building: its style and,
  **for each staircase**, its highest floor and its largest floor (the default when that is
  larger than a plan allows).
- **« Même chose pour chaque escalier »** (T1.18), a box under « Escaliers » shown from two
  staircases: ticked, one « Étages » and one « Portes par étage » set every staircase alike;
  unticked, each staircase has its own pair under « ESC. A », « ESC. B »… (screen readers:
  « Étages, escalier B »), so B can be RdC–2e with 2 doors while A is RdC–5e with 4. It starts
  ticked for a house and for a building whose staircases are alike, unticked otherwise.
  Ticking it again gives every staircase A's floors and doors (refused, still unticked, when
  that passes 500 dwellings). A new staircase takes the floors and doors of the last one; « − »
  removes the last staircase.
- The **Étages** stepper runs « Inconnus » (one « Logements » row), « RdC », « RdC–1er », …
  « RdC–50e »: (−) on « RdC » gives « Inconnus », (+) on « Inconnus » gives « RdC ».
- A step the domain refuses (`BuildingPlan.perStaircase`) leaves the answers as they were and says why
  above the preview, until the next step that is taken: « Au moins 1 escalier. », « 26 escaliers
  au plus (A à Z). », « Les sous-sols ne sont pas comptés. », « 50 étages au plus. », « Au moins
  1 porte par étage. », « 26 portes par étage au plus avec 5A, 5B… », « 500 logements au plus
  par immeuble. ». Answers already taken are never undone by a change of the street meanwhile.
- Preview « APERÇU · 48 LOGEMENTS » and « Esc. A et B : RdC 01–04, 1er 11–14 … 5e 51–54 »: no
  staircase prefix for one staircase, « Esc. A à C » from three; every floor up to three, then
  RdC, 1er … top floor; a floor of one door shows its label alone. When the staircases differ,
  one line each, shorter: « Esc. A : RdC 01–04 … 5e 51–54 » then « Esc. B : RdC 01–02 … 2e 21–22 »
  (the RdC and the top floor, « … » when floors lie between).
- « Valider » on a building whose new layout drops doors with marks asks first: « Modifier les
  étages ? — 3 portes marquées n'existent plus dans ce plan : leurs statuts et
  « repasser » seront perdus. [Annuler] [Modifier] » (`Building.markedDoorsDroppedBy`).
- « Libres » starts with the placeholder labels 1, 2, 3… of each floor; « Modifier les portes »
  renames them.

*Transformer en immeuble…* / *Modifier les étages* sheet:

```
┌──────────────────────────────┐
│ Décrire l'immeuble           │
│ 8 Rue des Lilas              │
│ Escaliers        (−) 2 (+)   │
│ ☐ Même chose pour chaque escalier
│ ESC. A                       │
│ Étages      (−) RdC–5e (+)   │
│ Portes par étage (−) 4 (+)   │
│ ESC. B                       │
│ Étages      (−) RdC–2e (+)   │
│ Portes par étage (−) 2 (+)   │
│ Numéros ( 51, 52… | 5A, 5B… | libres )
│ Aperçu · 30 logements        │
│ [         Valider         ]  │
└──────────────────────────────┘
```

- Afterwards each floor can be adjusted on its own (add / remove a door, rename a door), from
  « Modifier les portes » under the grid. "Libres" lets you type the labels (e.g. "Gauche", "Droite").
- Changing the layout keeps the statuses (and « repasser ») of doors whose label still
  exists on the same floor of the same staircase.

« Modifier les portes » details fixed in T1.12 (`lib/presentation/building/adjust_doors_*`,
`lib/ui/screens/building/adjust_doors_screen.dart`, `rename_door_sheet.dart`, mockup Doors):

- Opened from the grid: « Gérer l'immeuble », then « Modifier les portes » (T1.18); leaving it
  comes back to the grid. A full screen
  « ✕ Modifier les portes [OK] » with « 8 Rue des Lilas » under the title; ✕, « OK » and back
  all just leave, since every change is stored at once (through `DescribeBuilding`, offline).
- « Esc. A | Esc. B » only with more than one staircase (it comes back to A when the chosen
  one disappears). Floors top first (RdC, 1er, 2e…, « Logements » for unknown floors); each
  door is a dashed tile « label ✕ » as wide as its label, the tiles wrap under the floor
  label, and a « + » square (ink outline) closes each floor. **Empty floors are listed**
  (unlike the grid), so a door can be added back. Under the floors: « Touchez une porte pour
  la renommer (« Gauche », « 5A »…). ». The title and « 8 Rue des Lilas » under it are 6 dp
  apart (T1.19).
- **Hit areas** (T1.19): the label zone of a tile runs from its left edge to 18 dp past the
  label, so a tap aimed at the number renames; the ✕ zone is the last 36 dp of the tile. That
  is narrower than the 48 dp minimum, a deliberate trade-off: the ✕ stays 52 dp tall (the
  tile's height), and a ✕ hit by mistake is undone with « Annuler » (or asked first when the
  door has a mark).
- **Every change offers « Annuler »** for 4 s (T1.19), as in the street's edit mode; the next
  change, or opening a sheet, hides it, so only the latest change can be undone.
- **+** adds a door at the end of the floor with the building's next label (the number or
  letter after the count of doors on the floor, skipping taken ones; « Libres » goes on with
  3, 4…), with « Porte 13 ajoutée [Annuler] ». Refusals show in a 4 s message: « 500 logements
  au plus par immeuble. », « 26 portes par étage au plus avec 5A, 5B… ».
- **✕** removes at once with « Porte 53 supprimée [Annuler] » (4 s; « Annuler » puts the
  building back as it was before the removal). A door with a mark (a status, « repasser »
  included) asks first: « Supprimer la porte 52 ? — Elle a déjà une marque (fait, personne
  ou repasser), qui partira avec elle. « Annuler » la ramène juste après. [Garder]
  [Supprimer] » (« Supprimer » in red). The building's last door is refused before anything
  is asked: « C'est la dernière porte de l'immeuble. Pour en refaire une maison, revenez à
  l'immeuble : « Gérer l'immeuble », puis « Changer en maison ». ».
- **Tap a door** → a small sheet « Porte 11 », « Esc. A · 1er · 8 Rue des Lilas » (staircase
  only when several, no floor for « Logements »), field « Nom de la porte » (prefilled and
  selected, keyboard open), « Renommer ». The door keeps its marks. Refusals under the field
  until the next edit: « Ce nom est déjà pris à cet étage. », « Le nom de la porte ne peut pas
  être vide. », « Nom limité à 12 caractères. ». Once renamed, the sheet closes with « Porte 11
  → Gauche [Annuler] » (« Annuler » gives the door its name back, marks kept). The name it
  already has just closes the sheet, stores nothing and offers no « Annuler ».

### 5.8 Équipe (👥)

```
┌──────────────────────────────┐
│ ← Tournée 49                 │
│   CS Villefranche · 2026     │
│  ▄▄▄▄ ▄ ▄▄▄▄ Code K7P-2QX [⧉]│  ← ⧉ copies the code
│  █▄▄█ ▀ █▄▄█ [Partager]      │
│              [Nouveau code]  │  ← admins only (#75)
│ EN ATTENTE (1)               │  ← only when requests exist
│ Julie · il y a 2 min         │
│ [ Accepter ]  [ Refuser ]    │  ← any accepted member, any admin
│ MEMBRES (5)                  │
│ Manu (vous) · admin   5 rues │
│ Léa                 3 rues [⋮]│  ← admins only: retirer
│ Paul · admin        0 rues [⋮]│
│ Corbeille · 2 éléments     › │  ← 5.11
│ CAMPAGNE 2026                │
│ [ Démarrer une nouvelle campagne ] │  ← admins only, v1.1 (5.10)
│ [  Quitter la tournée  ]     │  ← every member
│ [  Supprimer la tournée ]    │  ← admins only
└──────────────────────────────┘
```

**From #75 (5.12) the creator has no power of their own:** read « the creator » below as « an
admin » for « Nouveau code », « Retirer », « Supprimer » and the campaign; « · admin » replaces
« · créateur »; every member may leave, admins and the creator included, so a member sees
« Quitter » and an admin both « Quitter » and « Supprimer » (mockups Team, TeamMember).

- A request shows the name the newcomer typed and how long ago it was sent. Any accepted member
  can accept or refuse, so nobody has to wait for the creator.
- *Retirer* (creator only) cuts the member's access at once; what they marked stays, stamped
  with their name. Combine with *Nouveau code* if the code has leaked.
- Delivered in T2.6 (Team mockup): title « Tournée 49 » over « CS Villefranche · campagne
  2026 »; the code card (QR, « Code K7P-2QX » and its copy button ⧉ — puts the code as shown,
  `K7P-2QX`, on the clipboard and says « Code copié », TalkBack « Copier le code », 48 dp,
  offline too —, « Partager » — the phone's share sheet with « Tournée 49 · CS Villefranche »
  and the code —, « Nouveau code » for the creator, at once,
  no confirmation); « EN ATTENTE (n) » only with requests: name, « a demandé à rejoindre · il
  y a 2 min », « Accepter » (green) and « Refuser », no confirmation; « MEMBRES (n) »: every
  active member, one row each, oldest first (the creator first), « (vous) » and « · créateur »;
  ⋮ → « Retirer » on the others for the creator, asking « Retirer Léa ? » first; « Corbeille · n
  éléments › » (« · vide »). At the bottom one button: « Supprimer la tournée » for the creator
  (asks « Supprimer la tournée 49 ? »), « Quitter la tournée » for the others (asks too, since
  coming back needs the code and an approval); both then forget the tournée on the phone and go
  back to the start screen with none open. Answering, removing and leaving work offline; a
  new code and deleting need the network (« Pas de réseau. Réessayez une fois connecté. »). A
  command a teammate made pointless meanwhile says « L'équipe a changé entre-temps. ». A
  tournée that cannot be read (removed, deleted, or never read on this phone offline) shows
  « L'équipe ne peut pas être affichée : … ». Times: « à l'instant », « il y a 2 min », « il
  y a 3 h », « hier », then the day (« 3 oct. »). Still to come: the street counts « 5 rues »
  (with the assignees, M3) and « CAMPAGNE » / « Démarrer une nouvelle campagne » (v1.1).
- **Communes** (#78): after the Corbeille, « COMMUNES (n) », a row per commune of the tournée
  with ✕ (« Retirer Gleizé » for screen readers), never on the last one, then « + Ajouter une
  commune », which opens a sheet with the field of « Nouvelle tournée » (5.2); a commune picked
  is added and the sheet closes. A tournée created before the communes shows only the button.
  Any active member or admin may change them, offline too (sent later); a pending member sees
  them without ✕ or button. « Cette commune est déjà dans la tournée. », « Une tournée a au
  plus 50 communes. », or « L'équipe a changé entre-temps. » when a teammate removed one
  meanwhile. Removing a commune keeps the streets added from it.
- From T2.6c a member removed, or a tournée deleted, is forgotten by the phone as soon as the
  server says so, with a message (« Vous avez été retiré de la tournée 49. », 5.3), which
  closes Équipe; « L'équipe ne peut pas être affichée » stays for a tournée never read
  offline.

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
│ Version       1.0.0        › │  → Nouveautés
│ Licences                   › │
│ Données © OpenStreetMap, BAN │
└──────────────────────────────┘

  Nouveautés
┌──────────────────────────────┐
│ ← Nouveautés                 │
│ 1.1.0  20 oct. 2026          │  (example of a later version)
│ • Un bouton copie le code de │
│   la tournée.                │
│ 1.0.0  16 oct. 2026          │
│ • Première version.          │
└──────────────────────────────┘
```

- **Prénom** opens a sheet « Votre prénom » + « Enregistrer » (the keyboard's « OK » too):
  `MemberName` rules; blank → « Écrivez votre prénom. », too long → « Prénom limité à 30
  caractères. », the sheet stays. Kept on the phone, then written to the member's own
  document in every tournée of « Mes tournées » they are active in, so Équipe shows the new
  name to the team (T2.7b). Works offline (sent when the network is back); a pending request
  (which cannot rename itself, 8.2) and a tournée the phone cannot read offline are skipped,
  then caught up (T2.7c): whenever the server shows the member active in one of their
  tournées under another name than the phone's, the phone sends its own.
- **Mes tournées** shows the open one (« 49 · 2026 ») and opens the sheet of 5.3.
- **Thème** opens « Système | Clair | Sombre »: a tap redraws the app at once and closes the
  sheet. « Sombre » uses the first dark palette, reviewed in T5.1.
- **Confidentialité** opens a page saying 8.3 in French: compte, données enregistrées,
  position, hébergement, suppression.
- **Version** (from `pubspec.yaml`, `appBuildName`) has a › : a tap opens **« Nouveautés »**
  (Changelog mockup): each version, newest first, with the day it came out (« 16 oct.
  2026 ») and what it brings in short French lines for the members (not commit messages).
  The list ships inside the app (`ui/screens/settings/changelog.dart`, its lines in
  `app_fr.arb`), so it works offline. **Each release (#37) adds its entry at the top and
  sets its date**; 1.0.0 « Première version. » is the only one so far.
- **Licences** opens Flutter's licences page (packages and bundled fonts).
- **Identifiant de l'appareil** (#75, 5.12): the last row of APPLICATION, the whole uid,
  « Administrateur » under it when admin, and a copy button.
- Credits under the list: « Carte © contributeurs OpenStreetMap, OpenFreeMap.
  Adresses{N}: Base Adresse Nationale. »
- HORS-LIGNE comes with the download (T4.2).

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
│ Remis à zéro                 │    │                              │
│  ○ statuts, « repasser »     │    │                              │
│  ○ qui fait quelle rue       │    │                              │
│ 2026 reste consultable.      │    │                              │
│ [  Démarrer 2027  ]          │    │                              │
└──────────────────────────────┘    └──────────────────────────────┘
```

- Copied: streets (with shapes and edits), numbers, buildings and their floors. Reset: statuses, *repasser*, last-change info, assignees.
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
  marks intact. This is the safety net against mistakes and against a member who
  makes a mess.
- Items older than 30 days are purged by the first member's app that is online (no server
  needed), and at the latest when a new campaign starts.
- Delivered in T2.6 (Trash mockup), opened from Équipe: the deleted streets (« Rue Gambetta »
  over « 22 numéros · supprimée par Paul · hier ») and the numbers removed from the streets
  still shown (« 14ter Rue des Lilas » over « supprimé par Léa · 3 oct. »), the latest first;
  the numbers removed from a deleted street come back in sight with it. A member no longer
  in the team reads « un membre ». « Restaurer » brings the item back at once for everyone,
  with its marks; nothing when empty but « La corbeille est vide. ». Works offline, with
  whichever street storage is bound.
- The 30-day purge (T2.6b) runs by itself, with nothing on screen, when the app starts and
  each time a tournée is opened, on the streets bound (the tournée's, or the phone's own while
  none is open): each street deleted more than 30 days ago goes for good, and each number
  removed more than 30 days ago (counted from its own removal, the street deleted or not).
  At 30 days exactly it is still kept. Offline, the phone's copy changes at once and the
  deletes are sent later; the server refuses any that is not past 30 days by its own clock
  (a teammate restored it meanwhile), and the item comes back.

### 5.12 Administrateurs (#75)

```
  Toutes les tournées (admin)        Accueil, admin not a member
┌──────────────────────────────┐    ┌──────────────────────────────┐
│ ← Toutes les tournées        │    │ Tournée 12 · 2026    [👥][⚙]│
│   Administrateur · 4 tournées│    │ CS Gleizé                    │
│ CS VILLEFRANCHE              │    │ ┌──────────────────────────┐ │
│ Tournée 49 · 2026          › │    │ │🛡 Administrateur · pas    │ │
│   5 membres · vous en êtes … │    │ │  membre       [Rejoindre]│ │
│ CS GLEIZÉ                    │    │ └──────────────────────────┘ │
│ Tournée 12 · 2026        • › │    │ (map)                        │
│   3 membres · 1 demande …    │    ├──────────────────────────────┤
│ CS ANSE                      │    │ Rues · 9/38                  │
│ Tournée 7 · 2025           › │    │ Rue de la Gare        9/30   │
│   Aucun membre               │    │ [   + Ajouter des rues   ]   │
└──────────────────────────────┘    └──────────────────────────────┘
```

Decided with the user (2026-10-12 and 2026-10-16, issue #75; mockups AllTournees, HomeAdmin,
TeamMember, and Welcome, Switcher, Team, Settings updated):

- **Who is an admin.** An `admins/{uid}` document (no fields) added by hand in the Firebase
  console; the rules check it, the app follows it (`AdminStatus`, cached by Firestore, so it is
  known offline once read). Admins are **global**: an admin manages, joins and reads / adds /
  removes streets in **every** tournée, member or not. Granting and revoking from the app: out
  of scope. Anonymous auth loses the uid on reinstall or on a new phone: the admin reads the
  new one on the phone (below) and adds it in the console again. Until the app has read the
  document, the phone is not an admin (nothing admin-only shows).
- **Identifiant de l'appareil** (the Firebase uid): a line at the bottom of Bienvenue
  (« Identifiant de l'appareil » and a copy button, TalkBack « Copier l'identifiant de
  l'appareil », « Identifiant copié », the uid under them), and the last row of Paramètres →
  APPLICATION (the uid under the label, « Administrateur » under it when admin, same copy
  button). The uid is shown **whole** (asked after the phone test, 2026-10-17), in the
  phone's monospace font and selectable by a long press; it wraps rather than being cut
  when the text is large. The copy puts it on the clipboard. Bienvenue and
  Paramètres sign in when they open (`signInIfNeeded`): offline with no account yet, the line
  of Bienvenue is not shown and the row reads « Pas encore de compte : connectez-vous au
  réseau. ».
- **Non-admins** never see « Créer une tournée » (Bienvenue, « Mes tournées »), with no hint
  in its place; only « Rejoindre une tournée ». Adding a centre de secours happens only in
  « Nouvelle tournée », so it is admin-only too.
- **Équipe** (5.8): « Nouveau code », ⋮ → « Retirer » and « Supprimer la tournée » for admins
  only (member or not); the creator has no power of their own any more. Admins remove any
  other active member, admins included. Accepter / Refuser: any active member and any admin.
  « Quitter la tournée »: every member, admins included, even the last one (no guard: an empty
  tournée stays and admins manage it from « Toutes les tournées »). A member row shows « ·
  admin » for an admin (any signed-in user may `get` `admins/{uid}`); « · créateur » is gone.
  Existing tournées are kept as they are.
- **« Toutes les tournées »** (admins only): « Toutes les tournées › » under Créer and
  Rejoindre in the « Mes tournées » sheet. Every tournée of the app, grouped under its centre
  (« CS GLEIZÉ », centres by name, tournées by number then campaign), each row « Tournée 12 ·
  2026 » over « 3 membres » (« 1 membre », « Aucun membre » in red), « · vous en êtes membre »
  when the admin is an active member, « · 1 demande en attente » with a red dot (said by
  TalkBack); « Administrateur · n tournées » under the title. It needs the network: « Pas de
  réseau : la liste ne peut pas être affichée. » with « Réessayer ». A tap opens the tournée.
- **Opening a tournée as an admin** who is not a member: it is remembered in « Mes tournées »
  as **visited** (a third `MemberStatus`, `visiting`: row « CS Gleizé · administrateur », a
  shield instead of the ring) and opened on the normal screens: map, streets panel (« Rues ·
  9/38 » instead of « Mes rues »), streets, houses, marks, Corbeille and Équipe, all as a
  member, plus the admin's powers. A banner under the title on Accueil: shield, « Administrateur
  · pas membre » over « Vous n'êtes pas dans l'équipe de cette tournée. » and « Rejoindre »
  (come-back blue, `#D6E6F5` / `#1D4E7A`). A visitor is not listed in MEMBRES. Their marks are
  stamped with their uid; where a name is shown for a uid that is not a member: « un
  administrateur ».
  - **« Rejoindre »** makes the admin an active member at once (their own document, `active`,
    accepted by themself, no code, no approval); the banner goes and the row becomes a normal
    one. Offline: « Pas de réseau. Réessayez une fois connecté. ».
  - At the bottom of Équipe a visitor has « Retirer de Mes tournées » (forgets it on the
    phone, writes nothing) instead of « Quitter », and « Supprimer la tournée ».
  - A visited tournée deleted, or the phone no longer an admin, is forgotten as in 5.3 « A
    tournée lost », with « La tournée 12 a été supprimée. » or « Vous n'êtes plus
    administrateur : la tournée 12 est retirée de Mes tournées. ».
- **A revoked admin** (#87): the phone may still believe it is an admin's for a moment after
  `admins/{uid}` is removed (« Créer » or « Nouveau code » still on screen). The server refuses
  the admin's command and the screen says « Vous n'êtes plus administrateur. » where it says
  « Pas de réseau » for the same command: under « Créer » in « Nouvelle tournée » (« Créer »
  then stays off), in place of the list in « Toutes les tournées » (no « Réessayer »), in the
  snackbar of Équipe (« Nouveau code », « Retirer », « Supprimer la tournée ») and of the banner
  (« Rejoindre »). The same message when the phone already knows it (the tournée refuses the
  command itself). « Retirer », « Accepter » and « Refuser » are sent in the background (they
  work offline): a refusal by the server only takes the change back on the screen, as for any
  queued write (PLAN §7). The listeners of a visited tournée that may no longer be read never
  show an error: Équipe reads « unavailable », the streets show none, and the revocation is told
  by the `admins/{uid}` listener as above.
- Delivered in #75 (`lib/presentation/admin/`, `all_tournees/`, `account/device_id_state.dart`,
  `lib/ui/screens/all_tournees/`, `start/admin_visit_banner.dart`):
  - « Toutes les tournées » is read once each time it opens (and on « Réessayer »), not
    followed live. Centres are ordered by their station key (the name without « CS » / « CIS »,
    French order), so « CS Villefranche » comes before « CIS Villefranche Est »; a centre is
    named as its first tournée names it. A tap opens the tournée and goes back to Accueil.
    « Toutes les tournées › » goes through « Votre prénom » first when the phone has no
    name, like « Créer » and « Rejoindre » (joining as an admin needs one); so does
    « Rejoindre » of the banner. Under the list, the mockup's line « Ouvrez une tournée pour
    la gérer… »; « Aucune tournée pour l'instant. » when there is none.
  - The banner sits at the top of the start screen (the map comes in M3); its header reads
    « Rues · 38 » instead of « Mes rues · 38 ». In « Mes tournées » a visited tournée has a
    shield (green when open, grey otherwise) and ✓ when open.
  - Équipe: an admin's bottom row holds « Quitter la tournée » (or « Retirer de Mes
    tournées » for a visitor, no confirmation: nothing is written) and « Supprimer la
    tournée » side by side; a non-admin has « Quitter » alone (« Retirer de Mes tournées »
    alone for a visitor no longer an admin). The dark avatar marks « (vous) » (both
    mockups), no longer the creator. An admin may « Retirer » any other member.
  - Corbeille: someone not in the team is « un administrateur » when `admins/{uid}` says so
    (asked once per uid while the Corbeille shows), « un membre » otherwise.
  - Paramètres: « Connexion au serveur… » while the screen signs in. Bienvenue keeps the
    room of its line while it signs in, so the buttons do not move.
  - Not done: the instrumented suite has no admin flow (it would need a real `admins/{uid}`
    document for the emulator's uid); widget tests cover the flows.

---

## 6. Data model

### 6.1 Domain model (pure Dart: no Flutter, no Firebase, no MapLibre)

Strict DDD. Two aggregates match the two things people change independently; everything
inside an aggregate changes only through its root, which enforces the invariants.

| Aggregate (root) | Contains | Invariants it guards |
|---|---|---|
| `Tournee` | `Member`s, `JoinCode`, `RescueCentre`, current campaign year, `TourneeCommune`s (#78) | one creator; members are pending or active; only active members accept others; only the creator removes members, regenerates the code, starts a campaign; communes unique by INSEE code, 1–50 from creation, never the last one removed |
| `Street` (one per campaign) | `House` entities, each with an optional `Building` → `Staircase` → `Floor` → `Dwelling` | numbers unique in the street; a building's status is derived, never set; deleting is soft (Corbeille) |

Value objects (immutable, validated at construction, equal by value): `JoinCode` (6 chars from
the alphabet), `RescueCentreKey` (normalised name), `TourneeNumber`, `MemberName`,
`HouseNumber` (12 + "bis", with the
French ordering), `StreetName`, `InseeCode` (the five-character commune code, `2A`/`2B`
in Corsica), `VisitStatus` (`toDo`, `done`, `nobodyHome`, `comeBack`), `ComeBack` (when to come back: an optional day and hour, #81), `CalendarDay` (a date without time or zone, #81),
`NobodyHomeTries` (the tries with nobody home, #80),
`GeoPoint`, `StreetShape`, `Progress`, `ProgressLevel`
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
- **`ComeBack`** (#81, replacing the free hint of ≤ 20 characters of T1.20): when to come
  back, a `day` (`CalendarDay`) and an optional `hour` of `8..21` (`ComeBack.hours`), or no
  time at all (`ComeBack.withoutTime`). `create(day:, hour:)` refuses an hour without a day
  (`hourWithoutDay`) and an hour outside 8–21 (`hourOutOfRange`); any day is taken, a past one
  too (the sheet says it is past). Structured so the reminders (#82) can read it, and so no free
  text is kept about a house at all: the free `Note` was removed for privacy (T1.20, §8.3).
- **`CalendarDay`** (#81, `lib/domain/shared/`): a date of the calendar, years 2000–2999,
  without time or time zone, so two phones agree on « samedi » whatever their clocks;
  `create(year, month, day)` refuses a date that does not exist (`noSuchDay`); `of(time)` takes
  the day of a `DateTime` as it reads (the screens give the phone's local time); `plusDays`,
  `daysSince`, `weekday` count whole calendar days (in UTC, free of summer time).
- **`NobodyHomeTries`** (#80): a count `0..99` (`create` refuses others: `outOfRange`; `none`
  = 0); `next` adds one, `99` stays `99`. `keptBy(status, tries)` is the rule a status puts on
  it: to do → none; nobody home → at least one (the first « personne » is a try); done and
  « repasser » → kept. The `House` and `Dwelling` factories run it (a building has none), so a
  stored « personne » without a count reads as its first try.
- Invalid input returns a failure value (`Result` = `Ok` | `Err`, `lib/domain/shared/`),
  never an exception.
- **Identifiers** (`MemberId`, `StreetId`, `BanStreetId`) are opaque, made by adapters, never
  typed by a person: a blank one is a bug and throws `ArgumentError`. `MemberId` is generated on
  the phone in M1 and holds the Firebase uid from M2. **`Commune`**: INSEE code (5 characters,
  `2A`/`2B` for Corsica, stored upper-case) + non-blank name, built with a failure value.
  **`ChangeStamp`** (`by` member, `at` time) is a house's last change and a street's deletion;
  `at` always comes from the caller (`Clock` port), never `DateTime.now()`.

`Street` rules fixed in T1.2 (`lib/domain/street/street.dart`):

- `Street.create` sorts the houses by `HouseNumber` and refuses two equal numbers
  (`duplicateHouseNumber`); `houses`, `oddHouses`, `evenHouses` are read-only lists (0 is even).
- **« Repasser » is a status** (T1.16, replacing the T1.2 flag): a single house or a door has
  exactly one of the four statuses, never « personne » and « repasser » at once. It carries a
  `ComeBack` (its time, possibly none) **exactly when** its status is `comeBack`: the `House` and
  `Dwelling` factories enforce it (`ComeBack.keptBy(status, comeBack)`), so `markHouse` to
  `comeBack` starts without time (or keeps the time it already had) and any other status drops
  the time. `setComeBack(number, comeBack)` on a single house only sets the time of a house
  « repasser »; on a house not « repasser », or with null, it is refused (`notComeBack`).
- **Tries with nobody home** (#80): a single house or a door has the `tries` its status allows
  (`NobodyHomeTries.keptBy`); `markHouse` / `markDwelling` give the new status and the tries
  follow it (never one more). `markNobodyHomeAgain(number)` / `markDwellingNobodyHomeAgain(number,
  key)` (« Repassé, toujours personne ») make it « personne » with `tries.next`, its time
  dropped, stamped; refused unless it is « personne » or « repasser » (`notToVisitAgain`), and
  on a building (`houseIsBuilding`). They return `HouseNobodyHomeAgain` /
  `DwellingNobodyHomeAgain` (the new `tries`, `before`, the stamp), undone like any house or door
  change. Every other command keeps the tries (time, rename, renumber, layout keeping a door);
  a house laid out as a building loses its own (its doors count theirs).
- Commands `markHouse` and `setComeBack` stamp the house with
  `by`/`at` and return `Result<(Street, Change), HouseChangeFailure>`; an unknown number is
  `unknownHouse`. `delete(by, at)` / `restore()` set and clear the street's `deletion`
  (Corbeille); houses are untouched. Marking a street in the Corbeille is allowed.
- Each **house change** (`HouseMarked`, `ComeBackSet`) carries the street id, the
  new value, the stamp and **the house as it was** (`before`): undo restores that exact house
  without re-reading, and storage writes only the named fields (`HouseMarked` writes the status
  with `HouseMarked.comeBack`, the time the house has after it: kept, none, or null).
- `Progress` counts the doors done, nobody home, come back and to do (the four partition
  `total`), plus `buildingComeBacks` (buildings with their own « repasser », not doors); the
  header's ↻ is `toComeBack` = doors « repasser » + those buildings.
  A street's progress is the sum (`+`) of its houses' `progress`; a building contributes its
  dwellings (below).

Building rules fixed in T1.3 (`lib/domain/street/building/`):

- **Shape.** `House.building` is null for a single house. A `Building` has a `DoorLabelStyle`
  and `Staircase`s named `A`…`Z` (`StaircaseName`, at most 26); each staircase lists its
  `Floor`s **top floor first** (the grid order), each floor its `Dwelling`s left to right. A
  floor's `level` is 0 for the RdC, 1 for the 1er…; **unknown floors** are one floor with
  `level: null` per staircase, shown as « Logements ». A floor may be empty (its doors removed).
- **`DwellingLabel`**: trimmed, 1–12 characters (code points), case and inner spaces kept
  (`Gauche` ≠ `gauche`); typed text goes through `parse` (failure value), labels made by code
  through the constructor (throws). **Labels are unique within a floor**, so « Gauche » /
  « Droite » can be on every floor. A door is named by `DwellingKey(staircase, level, label)`,
  stored under `"<letter><level>-<label>"` — `"A5-51"`, `"A0-Gauche"`, and `"A-Gauche"` when
  the floors are unknown. Unambiguous: the letter is one character, the level only digits, and
  the first dash ends it (a label may contain dashes).
- **`Dwelling`**: label, status, « repasser », last change; a done dwelling drops its
  « repasser », like a house.
- **Restoring from storage** (`Building.create(style, staircases)`, for T1.6 / T2.3): checks
  every invariant and fails with a `NewBuildingFailure` — at least one staircase, unique
  staircase names, floor levels 0–50 and unique per staircase, a « Logements » row (null level)
  only alone, labels unique per floor, at least one door, at most 500. Staircases are sorted by
  name and floors top first whatever order they come in; an empty floor is allowed.
- **Layout generation** (`BuildingPlan` → `generate()`): a plan is a `DoorLabelStyle` and one
  `StaircasePlan(topFloor, doorsPerFloor)` per staircase, `A` first (T1.18).
  `BuildingPlan.perStaircase(staircases, style)` checks each staircase — top floor 0–50 (or
  unknown: one « Logements » row), doors per floor ≥ 1, with style `5A` at most 26 doors per
  floor — and the whole building: staircases 1–26, at most **500 dwellings** in all (a building
  lives inside its street document, PLAN §6.2). `BuildingPlan.create(staircaseCount, topFloor,
  doorsPerFloor, style)` is the simple case, every staircase alike; `isUniform` tells whether
  they are. Each breach is a `BuildingPlanFailure`. Door numbers are padded per staircase (a
  staircase of 10 doors reads `101–110`, its neighbour of 4 keeps `11–14`). Labels:
  - `51` (`floorAndNumber`): floor then door number — RdC `01–04`, 1er `11–14`, 5e `51–54`,
    10e `101–104`. With **10 doors or more** per floor the door number is padded to the width of
    the count (RdC `001–010`, 1er `101–110`), so floor 1 door 11 (`111`) never reads like floor
    11 door 1 (`1101`).
  - `5A` (`floorAndLetter`): floor then letter — RdC `0A`, 5e `5A–5D`; stops at `Z`.
  - free (`free`): placeholders `1, 2, 3…` on each floor, renamed door by door, floor by floor
    (« Gauche », « Droite »).
  - unknown floors: no floor prefix — `1…n` (`51` and free), `A…` (`5A`).
- **Derived status** (`BuildingStatus`, never stored): done when every door is done, to do when
  none is (doors where nobody was home or « repasser » count as not done: a building whose doors
  are all ↻ is to do), partial otherwise (`◐ done/total`).
- **A building is to do itself**: the `House` factory sets a building's own status to to do; its
  doors carry the statuses. It keeps its own « repasser » (« Repasser » under the grid), free of the rule above since it has no status; that « repasser » counts in the street's
  ↻ (`Progress.buildingComeBack`) but not as a door. A single house « repasser » described as a
  building gives its « repasser » (time kept) to the building.
  The street's progress counts the building's doors instead of the house.
- **Commands** (on `Street`, each stamped with `by`/`at`):
  - `markHouse` on a building is refused (`houseIsBuilding`); `setComeBack` on a building sets
    its own « repasser ».
  - `describeBuilding(number, plan)` makes a house the building the plan lays out, or lays an
    existing building out again: doors whose label still exists **on the same floor of the same
    staircase** keep their status, « repasser » and last change; the others are dropped.
    `Building.markedDoorsDroppedBy(plan)` counts the doors with marks a new layout would drop,
    so the screen can ask first (T1.9).
  - Per-floor adjust: `addDoor(number, staircase, level)` appends a door labelled by the style —
    the next number (or letter) after the floor's door count, skipping labels already taken on
    that floor, never zero-padded (`110` after `19`); refused at 500 doors
    (`tooManyDwellings`) or after `Z` (`noLabelLeft`). `removeDoor` refuses the building's last
    door (`lastDwelling`) and leaves an emptied floor in place. `renameDoor` keeps the door's marks
    and refuses a label another door of the same floor has (`duplicateLabel`).
  - `removeBuilding(number)` turns it back into a single house: done if every door was done
    (its « repasser » then dropped), otherwise « repasser » with the building's time when it had
    its own, to do when not; doors dropped.
  - `markDwelling` and `setDwellingComeBack` (the time of a door « repasser »; refused
    otherwise: `notComeBack`) change one door and stamp only that door.
- **Changes.** Layout commands return `BuildingLaidOut` (the new building + the whole house
  `before`): storage rewrites that house's building, undo puts `before` back. A layout change is
  rare and made from « Gérer l'immeuble », so a teammate marking a door of the same building at that same
  instant may be overwritten. `BuildingRemoved` carries the new status (and `comeBack`, the
  time the single house keeps). Door commands return a `DwellingChange` (`DwellingMarked`, `DwellingComeBackSet`) with the house number, the staircase, the floor level, the door `before`
  and its `key`, so storage writes field paths such as `houses.8.dwellings.A5-51.status` and
  undo restores that door.

Editing rules fixed in T1.4 (`lib/domain/street/`):

- **`StreetName`**: trimmed, each run of spaces or line breaks inside made one space, 1–150
  characters (code points, as the `ComeBack` hint); case and accents kept. `Street.create` cleans and checks
  the name the same way (`invalidName`), so a BAN name, a stored one and a typed one follow one
  rule, which the security rules can enforce too.
- **Typed numbers** (`house_numbers_input.dart`, a domain service of pure functions):
  - `parseHouseNumbers` (the « + numéros » sheet and « Numéros en plus »): items separated by
    `,` (also `;` or line breaks), spaces and empty items ignored; an item is one number read
    like `HouseNumber.parse`, or a range of two plain numbers `21-25` (both sides; spaces around
    the dash, an en dash, and a backwards range `25-21` accepted).
  - `manualStreetNumbers` (the manual form): « Du » / « Au » are plain numbers 0–99999; one
    blank means the other alone, both blank means the extras only, swapped when backwards; the
    range keeps `Sides.both | odd | even` (0 is even); the extras are kept whatever the side.
  - Both return the numbers sorted in street order, each once, or a `NumbersFailure` naming
    what is wrong: `InvalidNumber(token, reason)`, `InvalidRange(token)` (suffix, missing
    bound, `1-2-3`, bound above 99999), `InvalidBound(from | to, text)`, `TooManyNumbers`.
  - **At most 500 numbers** per input (`maxNumbersAtOnce`): a range is counted before it is
    expanded, so a typo like `1-99999` is refused without building anything.
- **Removed numbers.** `Street.removedHouses` holds `RemovedHouse`s (the house exactly as it
  was + the `removal` stamp: « supprimé par Léa · 3 oct. »), sorted by number. They are out of
  `houses`, the sides and the progress, and house commands do not see them (`unknownHouse`).
  **A number is unique among shown and removed houses together** (it is the storage key).
- **Commands** (each returns its change; `NumberChangeFailure` when refused):
  - `Street.manual(id, name, commune, numbers)`: no BAN id, one new to-do house per number.
  - `addNumbers(numbers)` → `NumbersAdded(added, restored, alreadyThere)`: new houses are
    unmarked and land on their side by number; a number already shown is skipped and listed;
    **a number in the Corbeille is restored with its marks**. `nothingNew` when nothing would
    change (no number, or all shown already).
  - `removeNumber(n, by, at)` → `NumberRemoved`: allowed with marks; `House.hasMarks` (status
    ≠ to do, « repasser », or a door with either; `lastChange` and a bare layout are
    not marks) is the query the screen asks before, and `NumberRemoved.hadMarks` repeats it.
  - `restoreNumber(n)` → `NumberRestored` (carries the removal, so undo can put it back);
    `notRemoved` otherwise. It is the undo of `removeNumber`.
  - `renameNumber(n, newNumber, by, at)` → `NumberRenamed` (a `HouseChange`: `before`, stamp,
    `after`): the house keeps its status, « repasser » and building, is stamped, and moves
    to its new place and side. Refused: `sameNumber`, `numberTaken` (shown), `numberRemoved`
    (in the Corbeille: restore it or choose another number). Storage deletes `houses.3` and
    writes `houses.3bis`.
  - `renameStreet(StreetName)` → `StreetRenamed(before, name)`.

Address directory rules fixed in T1.5 (`lib/application/ports/address_directory.dart`,
`lib/infrastructure/ban/`):

- **`GeoPoint`** (`lib/domain/shared/`): latitude −90…90, longitude −180…180 (bounds included,
  NaN / infinity refused), built with a failure value. The BAN writes `[longitude, latitude]`.
- **Port `AddressDirectory`**: `streetsOf(InseeCode)` → `CommuneStreets` (the `Commune`, its
  `DirectoryStreet`s — BAN id, `StreetName`, BAN number count — in the BAN's order, and
  `skippedStreets`); `numbersOf(BanStreetId)` → `StreetNumbers` (id, name, commune, the
  `DirectoryNumber`s — `HouseNumber` + optional `GeoPoint` — in the BAN's order, possibly none,
  plus `invalidNumbers` and `duplicateNumbers`). Failures: `AddressDirectoryFailure.noNetwork`
  (connection, socket, TLS error or no answer within 15 s), `notFound` (HTTP 404),
  `serviceError` (any other status, a body that is not UTF-8 JSON, or not the expected
  document).
- **Real data never breaks an import**: a street entry without a non-blank id, a valid
  `StreetName` or a whole count ≥ 0 is skipped and counted; `lieu-dit` entries are kept like
  streets (they can hold numbers). A number entry that is not a valid `HouseNumber` is skipped
  and counted (`invalidNumbers`); a number already read (the BAN lists some twice, with two
  positions; `a` = `A`) is skipped and counted (`duplicateNumbers`), **the first one wins**; an
  entry without a usable position keeps its number with no position (no dot on the map).
- Requests send `User-Agent: TourneeCalendriers/1.0 (+<repo URL>)` and decode the body as
  UTF-8 whatever the headers say. The mapping functions live in `infrastructure/ban/mappers/`
  and are tested on fixtures captured from Villefranche-sur-Saône (`test/fixtures/ban/`).

Use cases and phone storage fixed in T1.6 (`lib/application/use_cases/`,
`lib/domain/street/street_repository.dart`, `lib/infrastructure/local_storage/`):

- **`House.position`** (`GeoPoint?`): where the entrance is, from the BAN; null for a number typed
  by hand or one the BAN gives no position. Every command keeps it (a renumbered house too).
- **Undo** (`Street.undo(change)`): puts back exactly what the change replaced and returns the
  change the undo makes, itself undoable. A house change (mark, « repasser », layout, door
  added / removed / renamed, back to a single house, renumbering) puts the **whole house** back,
  last change included → `HouseReverted(replaced, house)` (storage writes the whole house entry,
  deleting the old key when it renumbers back). A door change puts that door back →
  `DwellingReverted`. `NumberRemoved` → restore; `NumberRestored` → removed again with its old
  removal stamp; `StreetRenamed` → old name; `StreetDeleted` → restored. Refused (`UndoFailure`):
  `otherStreet`, `gone` (the house, number or door is no longer there), `numberTaken` (the old
  number was taken again, shown or in the Corbeille), `notUndoable` (`NumbersAdded`, removed with ✕
  instead; `StreetRestored`). Whatever changed on that house or door since is overwritten.
- `describeBuilding` fails with `BuildingChangeFailure.unknownHouse`, like the other layout
  commands.
- **Ports.** `StreetRepository` (domain): `find`, `findByBanId` (Corbeille included), `watch(id)`,
  `watchAll()` (not deleted) and `watchDeleted()` (the Corbeille's streets, T2.3) as `Stream`s
  that give the value now then after each change,
  `add(street)`, `save(street, change)` (each adapter writes what suits it: the whole street on
  the phone, the change's fields in Firestore), `purge(id)` (T2.6b: the street removed for
  good, memory first; the file deleted on the phone, the document in Firestore). Storage failures are exceptions, not failure
  values. Application ports: `Clock` (UTC), `IdGenerator` (ASCII letters and digits), and
  `IdentityProvider.currentMember`: in M1 a member id made once with `IdGenerator` and kept in a
  file; from M2 (T2.1) the uid of the phone's anonymous Firebase account
  (`infrastructure/firebase_auth/`). The sign-in starts in the background at launch and is
  never waited for; Firebase keeps the session on the phone, so later starts know the uid
  offline. Until the very first sign-in succeeds (first launch offline), changes are stamped
  with the M1 phone id. Creating or joining a tournée cannot stand in like that (the rules let
  in the uid only, §8.2): they go through the port `MemberAccount` (T2.1c, same adapter):
  `signedInMember` (from the phone, null before the first sign-in) and `signInIfNeeded()`
  (`Result<MemberId, SignInFailure.noNetwork>`), which waits for the sign-in already on its
  way (one at a time, never two accounts) or tries again after a failed one, so the network
  coming back is enough, no restart. `signIns` (a broadcast stream) tells the member each time
  a sign-in gives the phone its account (T2.6e), so what needs the account starts then. Use
  cases `ReadSignedInMember`, `SignIn` and `ObserveSignIn`; the
  onboarding screens show `AccountNotifier` (auto-disposed, so each opening of a screen is a
  new try): `AccountSigningIn` | `AccountSignedIn(member)` | `AccountOffline` (« hors ligne »,
  with « Réessayer » → `retry()`). Nothing of it runs on the marking path.
- **Use cases** (one class, one `call`; each loads the street, runs the root's command, saves,
  returns the change for « Annuler »; refusals are `CommandFailure<F>` = `StreetNotFound` |
  `CommandRefused(reason)`, `F` being the street's failure enum): `SetHouseDetails`
  (one `Mark` of a house: `StatusMark`, `ComeBackMark`, `NobodyHomeAgainMark` (#80); a tap on a tile is a `StatusMark`
  of the next status, the house sheet stores each control on its own), `MarkDwelling` (same `Mark`s on a door),
  `DescribeBuilding` (`LayOutBuilding`, `AddDoor`, `RemoveDoor`, `RenameDoor`,
  `BackToSingleHouse`), `EditStreetNumbers` (`AddNumbers`, `RemoveNumber`, `RestoreNumber`,
  `RenameNumber`, `RenameStreet`, `DeleteStreet`), `UndoLastChange(change)` (the screen keeps the
  last change), `ObserveStreet`, `ObserveStreets` (not deleted, by name ignoring case, then id),
  `ListCommuneStreets` (the import screen's list). They rely on the **memory-first** promise of
  every `StreetRepository` adapter: `find` answers from memory and `save` puts the new street
  in memory before it first waits, so two quick taps never lose one another.
- **`ImportReferenceArea(InseeCode, only?)`**: lists the commune, then imports the chosen streets
  (or, with no choice, every street whose BAN count is above 0; the others are counted in
  `emptyStreets`), one at a time in the BAN's order, with a progress callback. **Re-importing
  never wipes marks**: a street whose BAN id is already stored is left as is and reported
  (`StreetAlreadyImported`); if it is in the Corbeille it is restored (`Street.restore`, houses
  and marks kept) and reported (`StreetRestoredFromCorbeille`) (T1.17). The chosen
  streets already stored are handled first, before the BAN is asked: they need no network, and
  when they are all the BAN is not asked at all; if the commune then cannot be listed, the
  other chosen streets are reported failed with its failure. A street the BAN refuses or answers
  nonsense for is reported (`StreetImportFailed`) and the import goes on; once the network is
  gone (`noNetwork`), the remaining new streets are reported failed without a request (each would
  wait 15 s), and importing again finishes the job. Chosen ids the commune does not list are
  reported in `unknownStreets`. Only a commune that cannot be listed, when no chosen street is stored, fails the whole
  import.

Start screen rules fixed in T1.11 (`lib/domain/shared/french_text.dart`,
`lib/application/`):

- **French text** (a domain service): names are compared and filtered on a search key — lower
  case, accents dropped (`é` → `e`, also typed as a separate mark), `œ`/`æ` spelled out, hyphens
  and apostrophes read as spaces, spaces collapsed. `ObserveStreets` sorts with it (then by id).
- **Port `CommuneSearch`** (`search(name)` → `CommuneMatch`es: `Commune` + five-digit
  postcodes; failures `noNetwork`, `serviceError`), adapter `GeoCommuneSearch`
  (`infrastructure/geo_api/`, 10 s timeout). An entry without a valid `Commune` or a postcode
  that is not five digits is left out. Use cases `SearchCommunes` (nothing asked under two
  characters) and `FindImportedStreets` (BAN ids already on the phone, each `active` or `inCorbeille`).

Tournée rules fixed in T2.2 (`lib/domain/tournee/`):

- **`JoinCode`**: 6 characters of `ABCDEFGHJKMNPQRSTUVWXYZ23456789`. `generate(Random)` draws
  each one from the injected source (`Random.secure()` in the app, a scripted source in
  tests). `parse` ignores case, spaces and the dash, and fails with `invalidCharacter`
  (reported first) or `wrongLength`. `value` `K7P2QX` is stored and put in the QR; `display`
  `K7P-2QX` is shown.
- **`RescueCentre`**: the name as typed (trimmed, spaces joined, case and accents kept, 1–80
  code points, else `tooLong`) and its **`RescueCentreKey`**: the name's French search key
  (§6.1, T1.11) cut into words of `a–z 0–9` (any other character separates), without one
  leading prefix `CS`, `CIS`, `centre de secours` or `centre d'incendie et de secours` and the
  article `de / d' / du / des` right after it (kept when it is the last word), words joined
  with `-`: `CS Villefranche`, `cis villefranche`, `Centre de secours de Villefranche` →
  `villefranche`; `CS Villefranche-sur-Saône` → `villefranche-sur-saone`. Nothing left
  (`CS`, `!?`) → `blank`. Two names are the same station when their keys are equal
  (`isSameStationAs`); the key is the `rescueCentres` document id and the first half of the
  `tourneeKeys` id (§6.2).
- **`TourneeNumber`** 1–9999 and **`CampaignYear`** 2000–2099: `create(int)` or `parse(text)`
  (digits only, spaces around and leading zeros ignored; `notANumber`, `outOfRange`).
  **`MemberName`**: trimmed, spaces joined, 1–30 code points (`blank`, `tooLong`).
  **`TourneeId`** is opaque like the other ids.
- **`Member`** (entity): id (the uid), `MemberName`, `requestedAt` and `acceptance` (a
  `ChangeStamp`: `acceptedBy` / `acceptedAt`). Its status is derived: pending while
  `acceptance` is null, active otherwise; the creator accepted themself at creation.
- **`Tournee`**: `Tournee.createdBy(…)` makes a new one whose only member is its creator,
  active; `Tournee.create(…)` rebuilds a stored one and fails with `duplicateMember` or
  `creatorNotActive` (the creator missing or pending). Members are sorted by request time, then
  id; `pendingMembers`, `activeMembers`, `memberOf`, `isCreator`.
- **Commands** return `(Tournee, change)` or a `TourneeCommandFailure`. The one acting must be
  in the tournée (`notAMember`) and active (`requestPending`), except to leave:

  | Command | Who | Refused when |
  |---|---|---|
  | `accept(member, by, at)` | any active member | `unknownMember`, `alreadyActive` |
  | `refuse(member, by)` | any active member | `unknownMember`, `alreadyActive` |
  | `remove(member, by)` | the creator (`notCreator`) | `unknownMember`, `creatorStays`, `memberPending` (refuse it instead) |
  | `leave(by)` | any member but the creator; a pending one cancels their request | `creatorStays` |
  | `regenerateCode(by, random)` | the creator | — (draws again if it gets the old code) |
  | `delete(by)` | the creator | — |
  | `rename(name, by)` | any active member, for themself only (no member parameter) | — |

  **The creator can neither leave nor be removed** (the tournée would have nobody to run it):
  they delete the tournée instead.

  **From #75 (5.12) the commands take who acts as an `Actor`** (the member id and whether they
  are an admin) instead of checking the creator: `accept` / `refuse` by an active member or an
  admin; `remove(member, by)` by an admin (`notAdmin`) on any other active member, admins
  included; `leave(by)` by any member, the creator too (`creatorStays` and `notCreator` go);
  `regenerateCode` and `delete` by an admin (`notAdmin`), member or not; a new
  `joinAsAdmin(member, at)` adds an admin who is not in it as active at once, accepted by
  themself (`notAdmin`, `alreadyMember`) → `AdminJoined`; `rename` unchanged. `notAMember` /
  `requestPending` stay for a non-admin. `Tournee.create` no longer requires the creator
  among the active members (they may have left); `createdBy` stays as information only.
  `MemberStatus` gains `visiting` for a `TourneeSummary` (an admin who opened a tournée they
  are not in); `Member` itself stays pending / active. `TourneeLoss` gains `adminRevoked`.
  Ports: **`AdminStatus`** (application) `watchIsAdmin()` (false until read; any signed-in
  uid) and `isAdmin(uid)` for the « · admin » labels; `MemberAccount` exposes the uid for
  « Identifiant de l'appareil »; `TourneeDirectory.watchAllTournees()` gives the rows of
  « Toutes les tournées » (id, number, centre, campaign, active-member count, pending count,
  whether the caller is active), `noNetwork` when the server cannot answer.

  Delivered in #75: **`Actor(member, isAdmin)`** (`lib/domain/tournee/actor.dart`) is taken by
  `accept`, `refuse`, `remove`, `regenerateCode`, `delete` and `joinAsAdmin(by, name, at)`;
  `leave(by)` and `rename(name, by)` keep a `MemberId` (being an admin changes nothing for
  them). A non-admin hears first what keeps them from acting at all (`notAMember`,
  `requestPending`), then `notAdmin`; `joinAsAdmin` checks `notAdmin` before
  `alreadyMember`. An admin may `remove` themself (it is a leave; no failure was specified).
  `NewTourneeFailure` keeps only `duplicateMember`; `Tournee.creator` and `isCreator` are
  gone. `AdminJoined` is a `MemberChange`; storage first asks the server for the tournée
  (offline: `TourneeWriteFailure.noNetwork`), then sends the member document like the other
  member writes. **`AdminStatus`** (application port): `watchIsAdmin()` and `Future<bool>
  isAdmin(uid)` (false when it cannot tell); the use cases read the phone's flag with
  `watchIsAdmin().first` (false until known). `MemberAccount` needed no change: its
  `signedInMember` is the uid. The directory method is **`allTournees(caller)`**, one read
  of the server (a `Future`, not a stream: the screen reads it when it opens). For a
  `visiting` summary, `watchMembership` follows the tournée document (gone on the server →
  `deleted`) and the phone's own `admins/{uid}` (gone on the server → `adminRevoked`) instead
  of the member document. Use cases (`lib/application/use_cases/admins.dart`, `team.dart`):
  `ObserveAdminStatus`, `IsMemberAdmin`, `ListAllTournees` (signs in first), `OpenAsAdmin`
  (kept active when the admin is in it, `visiting` otherwise, then opened), `JoinAsAdmin`
  (the phone's name; none → `TeamProblem.noName`; then the summary accepted), `ForgetVisitedTournee`.
  Presentation: `adminProvider` (kept alive, false until known or on error), `deviceIdProvider`
  (on `accountProvider`, so the screen showing it signs in), `allTourneesProvider`;
  `TeamShown` has `iAmAdmin`, `iAmIn` and `MemberRow.isAdmin` (each other member asked
  once), `TeamActionFailure.noName`.
- **Changes** (`TourneeChange`, sealed): `MemberAccepted` (the member as accepted),
  `MemberRefused`, `MemberRemoved`, `MemberLeft` (the member as they were), `MemberRenamed`
  (the member with the new name; storage writes `displayName` only),
  `JoinCodeRegenerated(before, code)`. `delete` returns a `TourneeDeleted` holding the whole
  tournée (storage needs its code, centre and number to free them); it is not a
  `TourneeChange`.
- **Port `TourneeRepository`** (domain): `find(id)`, `watch(id)` (null when there is no such
  tournée or this member may no longer read it), `add(tournee)` → `AddTourneeFailure`
  (`alreadyExists`, `noNetwork`), `save(tournee, change)`, `delete(TourneeDeleted)` (from T2.6 both return
  `TourneeWriteFailure.noNetwork` for what needs the server, see below). A pending
  newcomer cannot read the tournée (§8.2), so the join (code lookup, request) goes through the
  `TourneeDirectory` port (Q20), not this one.

« Mes tournées » fixed in T2.7 (`lib/domain/tournee/`, `lib/application/`):

- **`TourneeSummary`** (value): what the phone keeps of one of the member's tournées — id,
  number, centre, campaign, `MemberStatus` (pending while the request waits; for a request,
  what the join preview showed, since a pending newcomer cannot read the tournée).
  `accepted()` gives it active.
- **`MyTournees`** (value): the summaries in the order the phone met them, each id once, and
  `currentId`, the open one, always an active one of the list. `none`; `remember(summary)`
  adds at the end or replaces in place, never opens (the open one stays while « Créer » /
  « Rejoindre » run), and closes the open one should it come back pending; `open(id)` →
  `OpenTourneeFailure` (`unknownTournee`, `requestPending`); `forget(id)` drops it, leaving
  none open when it was the open one (which to open next is the member's choice).
- **Port `MyTourneesStore`** (application): `myTournees` (sync, loaded at start-up),
  `changes` (each list saved), `save`. Use cases `ReadMyTournees`, `ObserveMyTournees`,
  `OpenTournee` (writes nothing when already open), `WatchJoinRequest` (`TourneeDirectory.
  watchRequest` as `MemberAccount.signedInMember`; nothing before the first sign-in) and
  `SettleJoinRequest` (active → the summary accepted, not opened; null → forgotten; pending or
  not a request → nothing). `MyTourneesNotifier` (kept alive) follows each pending request
  while the app runs (a failing listener leaves it pending); `currentTourneeProvider` is the
  open tournée the screens of a tournée follow. From T2.6c it also follows the team
  (`ObserveTeam`) of each active tournée not open: `TourneeRow.waitingRequests` (0 when it
  cannot be read).
- **A tournée lost** (T2.6c): **`TourneeLoss`** (domain enum) `removed` | `deleted`.
  `TourneeDirectory.watchMembership(summary, member)` emits once the server says the member is
  no longer in it, never from the phone's copy nor for a deletion made on this phone.
  `WatchMembership` (as `MemberAccount.signedInMember`, nothing before the first sign-in);
  `ForgetLostTournee(id, loss)` → `LostTournee(summary, loss, wasOpen)` after `forget`, or
  null (unknown any more, or still a request: nothing saved). `TourneeLossNotifier` (kept
  alive, listened to by `TourneeApp`) follows each active tournée of « Mes tournées » (a
  failing listener keeps it; on a phone that never signed in, it starts again on the tournées
  kept then once `ObserveSignIn` tells a sign-in, T2.6e) and gives a
  `TourneeLossNotice(tournee, number, loss, wasOpen)`;
  the app shows the message on its `ScaffoldMessenger` and goes to the start screen when it
  was the open one.
- **A name to catch up** (T2.7c): `TourneeDirectory.watchOwnName(tournée, member)` emits the
  name the server holds on the member's own document while it is active (never from the
  phone's copy, a pending request, or a snapshot with `hasPendingWrites`). `WatchOwnName` (as
  `MemberAccount.signedInMember`, nothing before the first sign-in; `distinct`, so a rename
  the server refused is not sent in a loop) and `CatchUpMemberName(tournée, heard)`: when the
  phone's `MemberName` differs from the one heard, the same `Tournee.rename` as « Prénom »;
  equal cleaned names, no name on the phone, an unreadable tournée or a refused rename send
  nothing. `TourneeLossNotifier` listens to it for each tournée it follows, so a rename made
  while the request waited reaches the team once accepted, with no rules change.
- **Port `PhoneSettings`** (application): `memberName` (null until given), `theme`
  (`ThemeChoice` system / light / dark), setters. Use cases `ReadPhoneSettings`,
  `ChangeMemberName` (`MemberName.create`, nothing kept when refused), `ChooseTheme`.

Onboarding fixed in T2.5 (`lib/application/use_cases/choose_start_point.dart`,
`create_tournee.dart`, `join_tournee.dart`, `lib/presentation/`):

- **`ChooseStartPoint`** (`MyTourneesStore`, the phone's `StreetRepository`): `StartOnStreets`
  | `StartOnWelcome` | `StartOnRequest(summary)`, in the order of §4. It takes the first value
  of `watchAll` / `watchDeleted` without waiting for the stream to be let go. Also where the
  app goes once a request is refused or cancelled. `launchPlaceProvider` (a `FutureProvider`
  read once) gives the router its first location; `TourneeApp` shows the bare ground until
  then.
- **Créer:** `ListRescueCentres`, `CheckTourneeTaken` (the directory, `noNetwork`) and
  `CreateTournee(centre, number, campaign, creatorName)`: `signInIfNeeded` (its `noNetwork`
  → `CreateTourneeFailure.noNetwork`), `Tournee.createdBy` with an `IdGenerator` id, a
  `JoinCode.generate` from the bound `Random` and the `Clock`, `TourneeRepository.add`
  (`alreadyExists` | `noNetwork`), then the summary remembered **and opened**; returns the
  tournée as stored (its code possibly replaced).
- **Rejoindre:** `PreviewJoin` (the directory), `RequestToJoin(preview, name)`: a tournée
  already in « Mes tournées » → `alreadyJoined` (asking again would turn an active member
  back into a request); else `signInIfNeeded` (→ `noNetwork`), the pending `Member` stamped
  with the `Clock` sent with `requestToJoin`, and the preview remembered as a pending
  summary. `CancelJoinRequest(tournee)`: `cancelRequest` as the signed-in member (none: only
  forgotten), then `forget`.
- **Following a request:** « Mes tournées » (`MyTourneesNotifier`, T2.7) already follows and
  settles each pending request; `JoinRequestNotifier` (family by tournée) watches it:
  `RequestWaiting(number, centre, canLeave)` | `RequestAccepted` (after `OpenTournee`) |
  `RequestClosed(refused, next)` | `RequestUnknown`. A request gone while shown is refused
  unless « Annuler » was pressed; one gone before the screen opened is not called refused.
  `FirestoreTourneeDirectory.watchRequest` tells nothing for a snapshot of the phone's copy
  without the document (`metadata.isFromCache`, `requestStatusesIn`): only the server can say
  a request is gone, so an offline start never drops it.
- **Presentation:** `WelcomeNotifier`, `NewTourneeNotifier` (duplicate check after
  `duplicateCheckDelayProvider`, 300 ms; answers about older input dropped) and
  `JoinTourneeNotifier` (late previews dropped) each wait for `AccountSignedIn` before asking
  the server, so after an offline first start « Réessayer » is enough, no restart.

Équipe and Corbeille fixed in T2.6 (`lib/application/use_cases/team.dart`,
`observe_corbeille.dart`, `lib/domain/street/corbeille.dart`, `lib/presentation/`):

- **Use cases** of Équipe, each acting as `IdentityProvider.currentMember` (the tournée's root
  checks they may): `ObserveTeam` (`TourneeRepository.watch`), `ReadCurrentMember`,
  `AcceptMember` (stamped with the `Clock`), `RefuseMember`, `RemoveMember`, `LeaveTournee`
  and `DeleteTournee` (both then `forget` the tournée in « Mes tournées »),
  `RegenerateJoinCode` (draws from the injected `Random`, `Random.secure()` in the app;
  returns the code as stored). Refusals are `TeamFailure` = a `TeamProblem` (`tourneeGone`: cannot be
  read, `offline`, `noName`, `notAdmin`) | `TeamCommandRefused(TourneeCommandFailure)`.
- **`TourneeRepository.save`** returns the tournée as stored and **`delete`** the deletion,
  or `TourneeWriteFailure.noNetwork` for what needs the server: a new code (the transaction)
  and deleting (which first reads the tournée from the server, so offline it fails before
  deleting anything). Member changes never fail (queued).
- **Corbeille** (domain service `corbeilleOf(streets)`): a `DeletedStreet` (id, name, shown
  numbers, `removal`) per street in the Corbeille and a `RemovedNumber` (street id and name,
  number, `removal`) per removed number of the other streets; latest removal first, then
  street name (French order), street id, number. `ObserveCorbeille` combines `watchAll` and
  `watchDeleted` once both answered. « Restaurer » is `EditStreetNumbers` with `RestoreStreet`
  (new, `Street.restore`) or `RestoreNumber`.
- **30-day purge** (T2.6b, `lib/domain/street/corbeille_retention.dart`,
  `lib/application/use_cases/purge_corbeille.dart`): `corbeilleRetention` = 30 days and
  `isPastRetention(removal, now)` (strictly more than 30 days). `Street.isPastRetention(now)`
  (deleted, and past it) and `Street.purgeNumbers(now)` → `(Street, NumbersPurged)` or null
  when none; `NumbersPurged(purged: [RemovedHouse])` frees the numbers, is `notUndoable`, and
  is stored as one delete of `houses.<label>` per number. `PurgeCorbeille(streets, clock)`
  reads `watchDeleted` and `watchAll` once, re-reads each street with `find`, `purge`s the
  streets past 30 days and saves the `NumbersPurged` of the others; it returns
  `(streets: n, numbers: n)`. `corbeillePurgeProvider` (presentation, `FutureProvider`, no
  retries) runs it and is built again when another street storage is bound; `TourneeApp`
  listens to it, which starts it.
- **Presentation:** `teamProvider` (kept alive, follows `currentTourneeProvider`):
  `NoTeam` | `TeamLoading` | `TeamUnavailable` | `TeamShown` (number, centre, campaign, code,
  `qrData`, `iAmCreator`, `RequestRow`s, `MemberRow`s with `isMe`, `isCreator`, `canRemove`;
  `waitingRequests` for the dot); commands answer `TeamActionFailure` `teamChanged` |
  `offline`. `corbeilleProvider` (auto-disposed) names `by` through the team. `RecentTime`
  (`JustNow`, `MinutesAgo`, `HoursAgo`, `Yesterday`, `OnDay`) on the phone's calendar.
- **Firestore settings** (PLAN §7) are applied in one place, `bootstrap/firebase.dart`
  (`offlineFirestore`: persistence on, `CACHE_SIZE_UNLIMITED`), before the database's first
  use and once per process; `bindAdapters` asks for the database once, lazily, for every
  Firestore adapter.

Streets on Firestore fixed in T2.8 (`lib/bootstrap/bindings.dart`,
`lib/application/use_cases/move_streets_into_tournee.dart`, `lib/presentation/`):

- **Binding.** `streetRepositoryProvider` follows `currentTourneeProvider` (its id and
  campaign only): a `FirestoreStreetRepository` of the open tournée's current campaign,
  closed (`onDispose`) when another tournée or none is opened; the phone storage
  (`phoneStreetRepositoryProvider`, one `LocalStreetRepository`) while none is open. Every use
  case watches it, so it is built again with the new storage. A Riverpod 3 notifier is
  **kept** when it builds again (only its `ref` is new): notifiers reset what they read in
  `build` (`FollowsStreet`, « Mes rues »), the kept undo change remembers the `ref` it was
  made under and is dropped once that `ref` is no longer `mounted`, and the Corbeille waits
  while its stream reloads (`isLoading`) rather than showing the old tournée's items. A
  stream that fails (the member may no longer read the tournée) shows no street, or the
  street as gone.
- **Pending sync** (T2.9): `pendingSyncProvider` follows the same rule through one private
  provider of `bindAdapters` (the open tournée's `FirestoreStreetRepository`, or null): the
  very adapter bound as the street repository, so one listener serves both; while no
  tournée is open, a stand-in that always says 0. `ObservePendingSync` hands the count to
  `PendingSyncNotifier` (`AllSent` / `ChangesWaiting(streets)`; a failed stream shows
  nothing).
- **`Street.restampedBy(member)`** (also on `House`, `Building`, `Dwelling`, `RemovedHouse`,
  `ChangeStamp`): every stamp — each house's and door's last change, each removed number's
  removal, the street's deletion — made by `member` at the time it had; nothing else
  changes.
- **Port `MovedStreetsLog`** (application): `wereMovedInto(tournée)`, `rememberMovedInto`.
  Use cases `CountStreetsToMove(tournée)` (0 when they went there, when the member is not an
  active member of the tournée as `TourneeRepository.find` gives it, or the phone holds none
  out of its Corbeille) and `MoveStreetsIntoTournee(tournée, onProgress)`: each phone street
  out of the Corbeille, unless the tournée has its id or its BAN id (Corbeille included), is
  `add`ed restamped by `IdentityProvider.currentMember`; then the tournée is remembered;
  returns `StreetsMoved(moved, alreadyThere)`. Started again after an interruption, it skips
  what already went. `MoveStreetsNotifier` (`NoStreetsToMove` | `StreetsToMove(count)` |
  `MovingStreets(done, total)`; « Plus tard » in `postponedMovesProvider`, in memory).
- **Size.** One `set` per street (≈ 60 document writes for a typical member, a few kB to
  ≈ 100 kB each). The rules only count nothing on a new street (`isNewStreet`: the houses are
  a map, not checked one by one), so no bulk limit refuses a big street; the 1 MB document
  limit is far off (a street of 1 500 numbers and a 500-door building ≈ 300 kB, rules test).

Geometry and map layers fixed in T3.1 (`lib/domain/geometry/`, `lib/domain/map/`,
`lib/domain/street/street_shape.dart`, `progress_level.dart`):

- **`StreetShape`**: the lines of a street (one per OSM way), each of two points or more (a
  shorter one is dropped); `StreetShape.none` for a street typed in by hand or unknown to OSM.
  `Street.create(shape:)` takes it (none by default), `Street.manual` has none. Equal by value,
  line by line. Stored from T3.3 (§6.2, §6.3). Since #92 one command sets it, once:
  `Street.fillShape(shape)` → `StreetShapeFilled` (refused `ShapeFillFailure.alreadyShaped`
  when the street has a shape, `noLine` for a shape without line; not undoable), and
  `Street.needsShape` says a street waits for one (no shape, out of the Corbeille, a house
  with a position).
- **Simplification** (`simplifyLine`, Douglas–Peucker): a point is kept only when *strictly*
  farther than the tolerance from the simplified line; distances are measured on a plane tangent
  at the segment's start (`metresFromSegment`, to the closest point of the segment, ends
  included). `StreetShape.simplified()` uses 2 m.
- **Codec** (`encodePolyline` / `decodePolyline`): Google's encoded polyline, precision 5
  (0.00001°, rounded to nearest); one text per line (`StreetShape.encode` / `decode`). Decoding
  fails with `malformed` (character outside `?`…`~`, value cut short or over six 5-bit chunks,
  a latitude without its longitude) or `outOfRange` (a point off Earth), never throws.
- **`ProgressLevel.of(progress, taken:)`**: `done` when every door is done and nothing is left
  to come back to (no building « repasser »), whether or not someone holds the street; otherwise
  `free` when nobody took it; otherwise `toDo` when every door is to do, `partial` when any door
  was visited (« personne » and « repasser » count as visited, not done). A street without any
  door is never done.
- **`MapLayers.of(streets)`**: a `StreetLine` (street id, shape, level) per street with a
  shape and a `HouseDot` (street id, number, position, `HouseDotStatus`) per house with a
  position, streets in the Corbeille left out. A single house's dot shows its status; a
  building's shows `comeBack` when it has its own « repasser », otherwise `toDo` / `partial` /
  `done` from its doors. Dots show from zoom 16 (`MapLayers.houseDotsMinZoom`). A street is
  taken when it has an assignee (T3.3).
- **`tourneeArea(streets)`**: the `GeoBounds` (south, west, north, east; never across the
  antimeridian) around every shape point and house position of the streets, Corbeille included
  (a street may be restored offline), plus 300 m; null when no street has a place on the map.
  `GeoBounds.around(points)` and `expandedBy(metres)` (longitude margin counted at the widened
  side farthest from the equator, clamped at the poles and ±180°) also serve the communes'
  points of #78.

Address and shape adapters fixed in T3.2 (`lib/application/ports/address_directory.dart`,
`street_shapes.dart`, `lib/infrastructure/ban/`; shapes from the map's tiles since #92,
`lib/infrastructure/map_tiles/`):

- **`AddressDirectory.streetAt(GeoPoint)`** → `StreetMatch` (BAN id, `StreetName`, `Commune`,
  the geocoder's one `GeoPoint` for the street). The Géoplateforme reverse geocoder (`type=street`,
  `limit=1`) measures the distance to that one point, not to the road, and answers the nearest
  street **whatever the distance**, possibly in the next commune; the card shows the name found.
  `notFound` only when it answers nothing (or nothing readable).
- **`AddressDirectory.searchStreets(text, commune:)`** → the `StreetMatch`es of one commune, best
  first, at most 10 (one call per commune of the tournée). The text is trimmed and cut before its
  first letter or digit; under 3 or over 200 characters (counted as code points) it finds nothing
  without a request (the service refuses it with HTTP 400). Same failures as the BAN lookup
  (`noNetwork`, `notFound` on 404, `serviceError`); an unreadable feature is left out. One
  adapter, `BanAddressDirectory`, serves the four calls (same timeout, 15 s).
- **Port `StreetShapes.shapeOf(name:, area:)`** (#92) → `StreetShape` as OpenStreetMap
  draws it on the map, **not simplified** (the caller calls `simplified()` before storing),
  `StreetShape.none` when no road matches; `StreetShapesFailure.noNetwork` (no answer within
  10 s) | `serviceError` (any status but 200 or 204, an unreadable TileJSON or tile). The
  **area** is `shapeSearchArea(positions)`: the street's house positions (and, for a street
  to add, the BAN's point of the street) plus 150 m, so a road of the same name in the next
  commune is left out. The **name** matches by `StreetName.matches`: the same `searchKey`
  (case, accents, `œ`, apostrophes and hyphens read as spaces), whole name only.
- **The adapter `OpenFreeMapStreetShapes`** reads the TileJSON
  `https://tiles.openfreemap.org/planet` once for the tile address (its first `tiles`
  entry, with the weekly version of the map in it; forgotten after a tile is refused), then
  the **zoom-14** tiles covering the area (at most 16, else no shape), one after the other,
  and keeps the named lines of the last 64 tiles in memory. Each tile is a Mapbox Vector Tile
  (protobuf, read by a small hand-written decoder: `mappers/protobuf_reader.dart`,
  `vector_tile.dart`; a gzipped body is uncompressed); the **`transportation_name`** layer
  gives the named roads (`name`). The lines of the name are cut to their tile (each tile
  repeats a strip of its neighbours), cut to the area (`clipLine`), and joined where their
  ends meet within 1 m (`joinLines`), across tiles too. A 204 is an empty tile.
Street picking fixed in T3.3 (`lib/domain/street/street.dart`, `lib/application/use_cases/`):

- **`Street.assignees`** (`Set<MemberId>`, read-only): the members who cover the street (their
  « Mes rues »); empty is « libre ». `Street.create(assignees:)` and `Street.manual(assignees:)`
  take them (none by default). `take(member)` → `StreetTaken` (refused `alreadyAssigned`),
  `release(member)` → `StreetReleased` (refused `notAssigned`), `AssignmentFailure`; the other
  assignees stay, nothing else changes. Undo releases a take and takes a release back (`gone`
  when it was undone by hand meanwhile). `restampedBy(member)` makes a covered street
  covered by `member` alone (the phone's own id of M1 is no member of the tournée).
- **Ex-members are ignored** (#91, `lib/domain/tournee/team_roster.dart`): someone removed
  (« Retirer ») or gone (« Quitter la tournée ») stays in `assignees` in Firestore (the rules
  let a member add or remove only themself, 8.2), but no longer covers the street.
  `TeamRoster.of(team, me:)` keeps the assignees in `team.members` (pending requests
  included) and `me`, who always counts (a visiting admin is no member); `assigneesOf(street)`
  and `isTaken(street)`. While the team is not read yet (`team == null`, an offline cold start
  before it was ever cached) it is `TeamRoster.unknown`, which trusts every assignee, so
  streets never flash to « libre ». The map's lines (`MapLayers.of(streets, roster:)`) and
  the street card (`StreetCardInTournee.of`) read the assignees through it: a street held
  only by ex-members is « libre » and anyone may « Me l'attribuer » it (`arrayUnion`, the
  stale uid stays). Known limit: a street taken only by an admin visiting the tournée (no
  member of it) shows « libre » to the team: the roster knows only the team, not the admins.
- **`LookUpStreet(StreetLookup)`** — `StreetAtPoint(GeoPoint)` (a tap: the geocoder) or
  `FoundStreet(StreetMatch)` (a search result) — gives the street card's subject:
  `StreetOfTheTournee(match, street)` when the tournée has its BAN id out of the Corbeille (its
  numbers are not asked), otherwise `StreetToAdd(match, numbers)` with the BAN's numbers and
  positions (`numberCount`). Failures are the `AddressDirectoryFailure`s: `notFound` (no BAN
  match), `noNetwork` (offline), `serviceError`. Changes nothing.
- **`AddStreetFromMap(numbers, assignToMe:, shape:)`** stores a `StreetToAdd`'s street with
  the road the card found (`LookUpStreetShape`, simplified), or without shape while it has
  none: since #92 it **never asks the map nor waits for it**. A street of the Corbeille with
  that BAN id comes back with its marks instead, and is taken when asked and not yet
  covered. `AddStreetFailure.alreadyInTournee` and `serviceError` (the BAN gave a number
  twice).
- **`LookUpStreetShape(streetToAdd)`** (#92): the road around the street's numbers and the
  BAN's point of it, simplified. **`FillStreetShape(streetId, road:)`** (#92): a street that
  needs a shape gets the road given, or else the one the map draws around its houses,
  simplified, through `Street.fillShape` (read again after the map answered: a teammate's
  phone may have filled it); `ShapeFillOutcome.filled | noRoad | notNeeded`, or the
  `StreetShapesFailure`. `assignToMe` puts the member on the phone in `assignees` (the
  card's two buttons).
- **`AddManualStreet(name, commune, numbers, assignToMe:)`** (« Rue à la main »): `Street.manual`,
  offline, assigned to the member when asked (a street without shape cannot be tapped on the
  map to be taken).
- **`TakeStreet(streetId)`** / **`ReleaseStreet(streetId)`**: the member on the phone, through
  the root; offline; `CommandFailure<AssignmentFailure>`.
- **`SearchStreet(text, communes:)`**: `AddressDirectory.searchStreets` for each commune in turn
  (the tournée's communes, which #78 stores; #31 passes them in), results in commune order, a
  BAN id listed once; the first failure fails the search; no commune → nothing, no request.

Communes of a tournée fixed in #78 (`lib/domain/tournee/`, `lib/application/use_cases/team.dart`):

- **`TourneeCommune`**: a `Commune` (INSEE code + name) and an optional `GeoPoint` centre, the
  one geo.api.gouv.fr gives at pick time (`CommuneMatch.centre`, from its `centre` field,
  `[longitude, latitude]`), equal by value. `Tournee.communes` keeps them in the order added,
  read-only.
- `Tournee.createdBy(…, communes:)` takes one to `maxCommunes` (50) communes of different codes
  (anything else throws an `ArgumentError`: « Nouvelle tournée » never sends it).
  `Tournee.create` (storage) takes none to 50 (`duplicateCommune`, `tooManyCommunes`), so a
  tournée created before #78 reads with none.
- **Commands** (any active member or admin, like answering a request): `addCommune(commune,
  by:)` → `CommuneAdded` (refused `communeAlreadyIn` by INSEE code, `tooManyCommunes`);
  `removeCommune(code, by:)` → `CommuneRemoved` with the commune as stored (refused
  `unknownCommune`, `lastCommune`). Use cases `AddCommune`, `RemoveCommune` (offline, queued)
  and `ObserveTourneeCommunes(id)` (the communes now and on each change of them, not of the
  team; none while the tournée cannot be read). `CreateTournee(…, communes:)`.
- **Map area**: `communesArea(communes)` = the centres plus 2 km (`communeMarginMetres`), null
  without centre; `addStreetsArea(communes, streets)` = that, else `tourneeArea(streets)`.

Accueil fixed in T3.5 (#30, `lib/domain/street/my_streets.dart`, `lib/presentation/home/`):

- **`MyStreets.of(streets, member)`**: `mine` (the streets whose `assignees` hold the member:
  « Mes rues »), `others` (free or someone else's; a street held only by ex-members is among
  them, « libre » on its card and line, #91) and `all`, each in the order given,
  Corbeille left out; `myProgress` and `teamProgress` add up their doors. `MyStreets.none`
  before the streets are read. `ObserveMyStreets()` gives them in French order for the member
  on the phone (`IdentityProvider`), now and on each change, offline.
- **`Progress.donePercent`**: the doors done in whole percent, rounded down (199 of 200 is
  99: 100 % means finished), 0 without door; « Équipe : 41 % ».
- **`homeArea(communes, streets)`**: `tourneeArea(streets)`, else `communesArea(communes)`.
  Accueil decides it once, when the streets are first read, so a street added meanwhile
  never moves the map. `MapLayers.showsHouseDots(zoom)`: zoom ≥ 16, when the legend explains
  the dots.

Firestore adapters fixed in T2.3 (`lib/infrastructure/firestore/`, `lib/application/ports/`):

- **Port `TourneeDirectory`** (application, Q20): what someone outside a tournée asks of the
  server. `preview(JoinCode)` → `JoinPreview` (code, tournée id, number, centre, campaign: what
  « Rejoindre » shows) or `JoinFailure` (`unknownCode`, `noNetwork`); `requestToJoin(preview,
  member)` stores the newcomer's pending member document; `watchRequest(tournée, member)` →
  pending, active, or null once refused or cancelled; `cancelRequest`; `watchMembership(summary,
  member)` (T2.6c: the member's own document, which the rules always let them read; once the
  server has it no more — not `isFromCache`, not `hasPendingWrites` — the reservation
  `tourneeKeys/{key}` read from the server tells `removed` while it still names the tournée,
  `deleted` otherwise; a `permission-denied` is passed on as an error, never taken as a
  loss); `watchOwnName(tournée, member)` (T2.7c, the same document); `isTaken(centre,
  number)` and `rescueCentres()` (sorted by name) for « Créer », failing with
  `DirectoryFailure.noNetwork`. The code, the number and the centres are asked of the server,
  never answered from the phone's copy.
- **Port `PendingSync`** (application): `watchUnsentStreets()`, the number of streets holding
  changes the server has not received yet (`hasPendingWrites` of each street document). Streets,
  not changes: Firestore tells per document, and its queue survives a restart (§7).
- **`FirestoreStreetRepository`** (streets of one campaign, also the `PendingSync`): one listener
  on the campaign's `streets` collection, served from the phone's cache first; every read answers
  from what it gave, and `add` / `save` put the street in memory and hand the write to Firestore
  **without waiting for the server** (offline the write waits on the phone, across restarts).
  A write the server refuses is taken back out of the phone's copy by Firestore and logged. An
  unreadable street document is left out, not fatal.
- **`FirestoreTourneeRepository`**: creating a tournée and a new code run in a **transaction**
  (needs the server, fails at once offline with `noNetwork`, sees a number or code taken at the
  same second). A join code another tournée already holds is replaced by a new one drawn from
  the injected `Random` (up to 10 draws, then a `StateError`): `add` returns the tournée as
  stored. Accepting, refusing, removing and leaving are queued like street writes. Deleting
  reads the campaigns, streets and members from the server and deletes the campaigns and
  streets in batches of 500, then the members (the creator's last) with the tournée, its code
  and its reservation in one batch, so a member's phone sees its membership and the
  reservation go together and says « supprimée », not « retiré » (T2.6c).
- **Undo is stamped with who undoes, now** (`HouseReverted`, `DwellingReverted`): the adapter
  writes the current member and the `Clock`'s time as `by` / `at`, not the old stamp, since the
  rules accept only the caller's uid (§8.2). The domain's undo still puts the exact house back;
  the stored one carries the new stamp, which the listener then shows.
- **Times** are the phone's (`Clock`), stored as Firestore `Timestamp`s and read back in UTC: a
  mark made offline keeps the time it was made, not the time it reached the server.

```dart
// Sketch of the core (T1.2–T1.6 delivered the uncommented members; the rest come with their tasks)
final class Street {                       // aggregate root
  final StreetId id;
  final String name;
  final Commune commune;
  final BanStreetId? banId;                // null when entered by hand
  final StreetShape shape;                 // map (T3.1): none when entered by hand
  final Set<MemberId> assignees;          // "Mes rues" (T3.3): who covers it, empty = libre
  final List<House> houses;                // always sorted by HouseNumber, numbers unique
  final List<RemovedHouse> removedHouses;  // numbers in the Corbeille, with their marks (T1.4)
  final ChangeStamp? deletion;             // set = in the Corbeille

  /// Every change returns the new street *and* what changed, so the Firestore adapter
  /// can write only that field (houses.12.status) instead of the whole document.
  Result<(Street, HouseMarked), HouseChangeFailure> markHouse(
      HouseNumber n, VisitStatus s, {required MemberId by, required DateTime at});
  // setComeBack, delete, restore; fillShape (#92);
  // buildings (T1.3): describeBuilding, addDoor, removeDoor, renameDoor, removeBuilding,
  //                   markDwelling, setDwellingComeBack;
  // tries (#80): markNobodyHomeAgain, markDwellingNobodyHomeAgain;
  // edit mode (T1.4): Street.manual, addNumbers, removeNumber (soft), restoreNumber,
  //                   renameNumber, renameStreet
  // undo (T1.6): undo(change) → (Street, HouseReverted | DwellingReverted | …)
  Progress get progress;
}

final class House { HouseNumber number; VisitStatus status; ComeBack? comeBack;
                    ChangeStamp? lastChange; Building? building;     // building: status is toDo
                    GeoPoint? position;                              // the map dot (T1.6)
                    NobodyHomeTries tries; }                         // « ×3 » (#80); none on a building
final class Building { DoorLabelStyle style; List<Staircase> staircases;   // A, B…
                       BuildingStatus get status; Progress get progress; }
// Staircase { StaircaseName name; List<Floor> floors /* top first */ }
// Floor { int? level /* null = « Logements » */; List<Dwelling> dwellings }
// Dwelling { DwellingLabel label /* unique on its floor */; VisitStatus status; ComeBack? comeBack;
//            ChangeStamp? lastChange; NobodyHomeTries tries }   — named by DwellingKey(staircase, level, label)

sealed class StreetChange { /* HouseMarked, ComeBackSet, BuildingLaidOut,
                               BuildingRemoved, DwellingMarked, DwellingComeBackSet,
                               HouseNobodyHomeAgain, DwellingNobodyHomeAgain (#80),
                               StreetDeleted, StreetRestored, StreetShapeFilled (#92),
                               NumbersAdded, NumberRemoved, NumberRestored,
                               NumberRenamed, StreetRenamed,
                               HouseReverted, DwellingReverted (undo, T1.6) */ }
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
admins/{uid}                                      ← no fields; added by hand in the console (#75)
rescueCentres/{centreKey}                         ← "villefranche"; the CS picker lists these
    name: "CS Villefranche"
tourneeKeys/{centreKey}_{number}                  ← "villefranche_49": guarantees number + CS is unique
    tourneeId
joinCodes/{code}                                  ← "K7P2QX": readable only by exact code (get, not list)
    tourneeId, number, centreName, campaign      ← what the join preview shows; nothing else

tournees/{tourneeId}
    number: 49, centreKey, centreName, joinCode, createdBy, createdAt,
    currentCampaign: 2026,
    communes: [ { code: "69264", name: "Villefranche-sur-Saône",
                  lat: 45.9837 | null, lon: 4.726 | null }, … ]
                                                  ← #78: in the order added; absent on a
                                                    tournée created before (reads as none);
                                                    an unreadable entry, or a second one of a
                                                    code, is skipped when read, at most 50 kept
  members/{uid}
    displayName: "Manu", status: "pending" | "active", requestedAt, acceptedBy, acceptedAt,
    joinCode                                      ← only on a newcomer's request: the code used
  campaigns/{year}                                ← one per year: 2026, 2027…
      startedAt, previousYear: null | 2026
    streets/{streetId}
      name, communeName, communeCode, banId,
      shape: ["<encoded polyline>", …],           ← one per OSM road, simplified, ≈ 1 KB a street;
                                                    [] for none; written once, with the street
                                                    or later while still [] (#92), never replaced
      assignees: [uid, …],                        ← who covers it, sorted when the street is
                                                    written; [] for nobody (T3.3)
      deletedAt, deletedBy                        ← set = in the Corbeille (5.11); null otherwise
      houses: {                                   ← a map inside the street document
        "12":  { n: 12, sfx: null, lat, lon, status: "DONE", comeBack: null,
                                          ← key = the number's label ("3bis", "3A"), n + sfx
                                            say the same; lat / lon null without position;
                                            status TO_DO | DONE | NOBODY_HOME | COME_BACK;
                                            comeBack = when, only when COME_BACK (on a
                                            building: its own « repasser »): "" for no
                                            time, "2026-10-24" a day, "2026-10-24T18" a
                                            day and an hour 8–21 (#81)
                 by: uid, at: timestamp,  ← last change, both null before any
                 tries: 2,                ← tries with nobody home (#80), 1–99; absent = 0
                                            (written from the first try, removed when 0)
                 deletedAt: null, deletedBy: null },   ← set = number in the Corbeille
        "8":   { n: 8, …, status: "TO_DO",        ← a building is always TO_DO itself
                 labelStyle: "FLOOR_AND_NUMBER",  ← FLOOR_AND_NUMBER | FLOOR_AND_LETTER | FREE
                 layout: [ { esc: "A", floor: 5, doors: ["51", "52"] },
                           { esc: "A", floor: 4, doors: [] }, … ],
                                          ← staircases A→Z, floors top first (floor null for
                                            the « Logements » row), doors left to right; it
                                            keeps the doors' order and the emptied floors
                 dwellings: { "A5-51": { status, comeBack, by, at, tries? }, … } }
                                          ← the marks of each door; key = letter + level +
                                            "-" + label ("A0-Gauche"; "A-Gauche" when the
                                            floors are unknown). A single house has none of
                                            labelStyle, layout, dwellings
      }
```

The street document fixed in T2.3 (`infrastructure/firestore/mappers/`): field names above,
statuses and label styles under fixed names. `prev` (last campaign's status) comes with the new
campaign (v1.1). `shape` and `assignees` came with the map (T3.3): a document written before
has neither and reads as no shape, nobody covering it. `tries` (#80) is written only from the
first try and read as 0 when absent (or null), so older documents, and the marks of an app
older than #80 (which leave the field as it was), need no rewriting: the domain reads it
through the status (none when to do, at least one when nobody is home).
`comeBack` held a free hint (« après 19h ») before #81 (`infrastructure/shared/mappers/
come_back_text.dart` reads and writes the time for both stores): any text that is not a time
the app writes reads as « repasser » with no time set, never as unreadable, and is replaced the
next time the house (or door) is written; nothing is migrated in bulk.
**Writes name field paths by segments** (`FieldPath(['houses', '8', 'dwellings', 'A0-Porte
1.2', 'status'])`), never dotted text: a typed door label may hold a dot. What each change
writes:

| Change | Fields written (under `houses.<n>` unless said) |
|---|---|
| mark, « Repassé, toujours personne », « repasser » of a house | `status`, `comeBack`, `tries` (the count, or deleted when 0), `by`, `at` (« repasser » day or hour: `comeBack`, `by`, `at`) |
| mark, « Repassé, toujours personne », « repasser » of a door | `dwellings.<key>.status`, `.comeBack`, `.tries`, `.by`, `.at` (day or hour: no `status`, no `tries`) |
| layout (describe, add / remove / rename a door) | `status`, `comeBack`, `tries` (deleted), `by`, `at`, `labelStyle`, `layout`, then each door `dwellings.<key>` whole; each door dropped is deleted |
| back to a single house | `status`, `comeBack`, `tries` (deleted), `by`, `at`; `labelStyle`, `layout`, `dwellings` deleted |
| numbers added | each new `houses.<n>` whole in one update; each one restored: `deletedAt`, `deletedBy` = null, in an update of its own (the rules check one by one only a write changing one house, T2.4) |
| number removed / restored | `deletedAt`, `deletedBy` (set / null) |
| number renamed | `houses.<old>` deleted, `houses.<new>` whole |
| street renamed, deleted, restored | `name`; `deletedAt`, `deletedBy` (top level) |
| shape found later (`StreetShapeFilled`, #92) | `shape` (top level), the whole list, only while the stored one is absent or `[]` |
| street taken, released (T3.3) | `assignees`: `arrayUnion([uid])` / `arrayRemove([uid])`, never the whole array, so two members taking it at once both stay |
| undo of a house (`HouseReverted`) | as a layout change, or `houses.<old>` deleted and `houses.<n>` whole when it renumbers back; `by` / `at` = who undoes, now |
| undo of a door (`DwellingReverted`) | `dwellings.<key>` whole, `by` / `at` = who undoes, now |
| 30-day purge of numbers (`NumbersPurged`, T2.6b) | each `houses.<n>` deleted, in an update of its own |
| 30-day purge of a street (`StreetRepository.purge`, T2.6b) | the street document deleted |
| commune added / removed (#78, on `tournees/{id}`) | `communes`: `arrayUnion([entry])` / `arrayRemove([entry])`, never the whole list, so two members adding at once both stay |

A building is never written as one map that would replace the doors: two writes crossing (a
door marked while a teammate lays the building out again) leave at most a door entry the
layout does not list, or a house entry without `n` (a mark landing just after a renumbering);
reading skips both.

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

- **M1 phone storage** (the streets while no tournée is open; Firestore's cache holds a
  tournée's, T2.8):
  `infrastructure/local_storage/`, in the app support folder (private, kept across updates).
  One JSON file per street, `streets/<id>.json` (a commune of ≈ 300 streets / 6 000 numbers would
  make one file of a few MB rewritten at every tap; a street's file is a few kB to ≈ 100 kB).
  Schema `version: 3` (T1.20: no `note`; T1.16: status `comeBack`, its time in `comeBack` only
  then — the same text as in Firestore since #81, "" / "2026-10-24" / "2026-10-24T18"; T3.3 added `shape`, the encoded lines, and `assignees`, member ids, without a new
  version: a file without them reads as no shape, nobody; #80 added `tries` on houses and doors
  the same way, written from the first try, absent = 0), written and read by pure mappers (`mappers/street_json_mapper.dart`). Version 1 files
  (« repasser » as a flag) are still read: a house or door to do or nobody home with a
  `comeBack` becomes « repasser ». Every file written before #81 may hold a free hint in
  `comeBack` (« après 19h »): it reads as « repasser » with no time set (no new version: the
  text goes the next time the street is written). Version 1 and 2 files held a
  free `note` on houses, doors and buildings: reading drops it (every other mark kept), and
  **a file of an older version is written again in version 3 as soon as it is read** (not at
  the next change), so no note stays on the phone. Mappers go
  through the domain's checks (`Street.create`, `Building.create`, `ComeBack.create`…); statuses and
  label styles under fixed names, times as ISO 8601 UTC. Every file is read once into memory,
  which answers all reads and is updated at once on a write (listeners told), then the file is
  written to `<id>.json.tmp` and renamed over the old one (a kill mid-write leaves the old
  street), writes queued one after the other. An unreadable file (newer version, damaged) is
  skipped and left on the disk. The phone's own member id is kept in `member_id` (from M2 it
  only stands in until the first Firebase sign-in, §6.1). No network, ever: works
  after an offline cold start.
- `street_view.json` in the same folder (port `StreetViewPreferences`, T1.7): « Masquer faits »
  per street, `{ version: 1, hideDone: [streetId…] }`, read once at start-up; an unreadable file
  means nothing hidden.
- `my_tournees.json` in the same folder (port `MyTourneesStore`, T2.7): « Mes tournées » and
  the open one, `{ version: 1, open: id | null, tournees: [{ id, number, centre, campaign,
  status: "active" | "pending" | "visiting" }] }` (`visiting` from #75; an older app reads
  such a file as unreadable, so as none), read once at start-up, so the last tournée reopens after
  an offline cold start. `settings.json` (port `PhoneSettings`): `{ version: 1, name: "Manu" |
  null, theme: "system" | "light" | "dark" }`. Same writing as the streets (`.tmp` then
  rename, queued); an unreadable file means none / defaults and is left until the next save.
  Files of the storage folder rather than `shared_preferences`: no plugin, plain Dart tests.
- `moved_streets.json` (port `MovedStreetsLog`, T2.8): the tournées the phone's streets went
  into, `{ version: 1, movedInto: [tourneeId…] }`, read once at start-up; an unreadable file
  means none (moving again skips what is already there).
- Offline download date and size per tournée (M4).
- MapLibre offline region per tournée (tiles), behind the `OfflineMapStore` port.

---

## 7. Sync and offline behaviour

**Goal:** once "Télécharger pour le hors-ligne" has run, the app can be used for a whole day with
no network, including a cold start, and loses nothing.

| What | How it works offline |
|---|---|
| Sign-in | The anonymous Firebase session is persisted on the phone; no network needed at start-up. After an offline first start, the sign-in is tried again when Créer / Rejoindre need it (§6.1) |
| Tournée data | Firestore persistent cache with **unlimited size** (no eviction). The download step runs one read of every street of the tournée, so all of them are in the cache |
| Live updates | Snapshot listeners serve the cache at once, then the server when reachable |
| Writes | Applied locally at once, queued by Firestore, survive restarts, sent when back online |
| Map | MapLibre offline region covering the tournée's bounding box + 300 m margin, zooms 12–17 (≈ 10 MB, measured in the T0.4 spike: OpenFreeMap tiles stop at z14, fonts are most of it). Street lines and house dots are drawn from the cached street documents, not from the network |
| New streets in the tournée added by teammates | Arrive with the next sync; their map tiles are already covered if they are inside the downloaded area, otherwise the banner asks to update the download |

- The pending-writes indicator (« ☁ Modifications de 3 rues en attente d'envoi », « … d'une
  rue … » for one) comes from the snapshot metadata `hasPendingWrites` (port `PendingSync`,
  T2.3): it counts the **streets** with writes waiting, since Firestore tells it per document,
  and words it so (not « 3 modifications »). The Firestore street adapter of the open tournée
  is the `PendingSync` too (one listener for both); with no tournée open the phone's streets
  are never sent, so nothing is pending. Shown only while the count is above 0.
- The banner and the Paramètres section show the download state; "Mettre à jour" re-runs both
  parts (streets and tiles).
- What needs the network: creating / joining a tournée, the download itself, and **adding a
  street from the map** (reverse geocoding, BAN, the map's tiles for its line; the line of a
  street added without it is filled later, when online, #92). Adding a street by hand, adding
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
| Server-side join with rate limiting (Cloud Function, needs the Blaze plan) | Large-scale guessing even from the real app | **Later, if needed** (decided at the M2 checkpoint, Q20): v1 stays on Spark. The join goes through the `TourneeDirectory` port, so moving to a callable function is an adapter swap with no data migration. Per-uid limits are weak anyway (anonymous accounts are free to create); App Check is the real gate |

### 8.2 Security rules (`firebase/firestore.rules`, tested in the emulator, §11)

- `tournees/{id}/**`: read and write only for members with `status == "active"`.
- `members/{uid}` create: only by that uid, only `status: "pending"`, only with the tournée's
  current join code. Update `pending → active` or delete a pending request: any active member.
  Delete an active member: the creator, or the member themself (*Quitter*). Update
  `displayName` only: the member themself, active, a name as `MemberName` cleans it (≤ 30).
- `joinCodes/{code}`: `get` for signed-in users, `list` denied; holds only the preview fields.
- `tourneeKeys/{key}`: `get` allowed (creation must know the pair is taken); create only if
  absent; never updated; deleted only with the tournée.
- `rescueCentres`: readable by signed-in users (station names only), create-only.
- Street and house writes: field-path updates only on `status`, `comeBack`, `tries`, `by`, `at`,
  `assignees`, `deletedAt/By`, numbers and dwellings; `status` in the enum; `comeBack` a time
  as the app writes it (#81, `isComeBackTime`: "", a day "2026-10-24" of the years 2000–2999,
  or a day and an hour "2026-10-24T18" of 08–21), so no free text at all (no `note`, §8.3; the
  free hint of before #81 is refused in a write, one already stored only goes when the house is
  next written); `tries` (#80, on a house or a door, `hasTries`) optional, an integer 1–99 when
  present, absent on a number just added; not tied to the status, so a mark by an app older
  than #80, which leaves it as it was, is still accepted;
  `by` must equal the caller's uid; `at` must be a timestamp. It is the phone's time of the
  change, not the server's (T2.3): a mark queued offline reaches the server hours later and
  must keep the time it was made, so the rules cannot require `at == request.time`.
- Only the creator: delete the tournée, regenerate the code, start a campaign. Previous
  campaigns are read-only.

**Admins (#75, 5.12)** change the rules as follows; where they contradict the lines above and
below, these win:

- `isAdmin()` = `exists(/databases/$(database)/documents/admins/$(request.auth.uid))`.
  `admins/{uid}`: `get` for signed-in users, never `list`, never written by a client.
- **Creating** a tournée (its reservation, code, first campaign, creator member) and a
  `rescueCentres` entry: admins only.
- **Reading and listing** `tournees` and everything under them: active members **or admins**
  (only admins may `list` `tournees` and query `members` of any tournée).
- **Streets** (every write allowed to a member, the 30-day purge included): active members or
  admins, `by` = the caller as before.
- **Members:** accept / refuse a request: an active member or an admin. Delete an active
  member: an admin (any member, admins included), or the member themself (*Quitter*, the
  creator too: their document no longer waits for the deleting batch). An admin creates their
  own document already `active`, `acceptedBy` = themself, without a code (« Rejoindre » of
  5.12).
- **New code, deleting the tournée, starting a campaign:** admins only, member or not. The
  deleting batch deletes every remaining member document (there may be none).
- Delivered in #75 (`firebase/firestore.rules`, `firebase/test/admins.test.mjs`): the
  deletion no longer requires the deleter's member document to go (the rules cannot list
  the members; the adapter deletes those that exist, since deleting a missing member
  document is refused). The undo of « Restaurer » may name an admin as the remover of a
  number (`exists(admins/{deletedBy})`), as an admin outside the team may have removed it.
  An admin's own active document (creation or « Rejoindre ») is one rule,
  `isAdminMembership`. The rules tests seed `admins/manu` (the creator) and `admins/sam`
  (in no tournée); the older tests that gave the creator powers now name an admin.

What the adapters write (T2.3), which the rules must allow:

- **Create** (one transaction): reads `tourneeKeys/{key}`, `joinCodes/{code}` (more than one
  if a code is taken) and `rescueCentres/{key}`; writes `tourneeKeys/{key}`,
  `joinCodes/{code}`, `tournees/{id}`, `members/{creator}` **already `active`** (accepted by
  themself), `campaigns/{year}`, and `rescueCentres/{key}` only when absent.
- **Join:** the request is `members/{uid}` with `status: "pending"` and the `joinCode` used
  (the rule compares it with the tournée's). The newcomer **reads their own member document**
  while pending (« Demande envoyée » follows it) and deletes it to cancel.
- **Accept:** updates `status`, `acceptedBy` (the caller), `acceptedAt` only. Refuse, remove,
  leave: delete the member document. **Rename** (« Prénom »): updates the caller's own
  `displayName` only.
- **New code** (one transaction): reads `joinCodes/{new}`, updates `tournees/{id}.joinCode`,
  deletes `joinCodes/{old}`, creates `joinCodes/{new}`.
- **Delete:** lists `campaigns`, their `streets` and `members` from the server, deletes the
  campaigns and streets in batches of ≤ 500, then one batch: `joinCodes/{code}`,
  `tourneeKeys/{key}`, `tournees/{id}`, the other members' documents and the creator's own.
- **Streets:** the writes of the table in §6.2. Whole entries (a number added or renamed, a
  layout, an undo) carry door entries with the `by` / `at` they already had, possibly a
  teammate's: only the entries that change carry the caller's uid. The undo of « Restaurer »
  writes back the removal it undoes (`deletedBy` possibly a teammate's).
- `rescueCentres` is listed (a query), not only read by id.

Rules fixed in T2.4 (`firebase/firestore.rules`, emulator tests in `firebase/test/`, `npm test`):

- **Reading.** A tournée, its members, campaigns and streets: active members only. A pending
  newcomer reads their own member document and nothing else; someone outside reads nothing.
  `joinCodes` and `tourneeKeys`: `get` when signed in, never `list`. `rescueCentres`: `get`
  and `list` when signed in. Anything not described is refused.
- **Values.** Every document holds exactly its fields (no more, no fewer) with the domain's
  limits: tournée number 1–9999, campaign 2000–2099, join code 6 characters of the alphabet,
  centre key words of `a–z 0–9` joined by `-`, names cleaned as the domain cleans them
  (one line, trimmed, single spaces): member ≤ 30, centre ≤ 80, street ≤ 150; commune code
  `69264` / `2A004`; house number 0–99999 with a suffix of ≤ 16 lowercase letters and digits,
  stored under its label; position in range or both null; statuses and label styles among
  their fixed names; a `comeBack` time exactly on « repasser » (a building may keep its own);
  a stamp a write sets is the caller's (`by` = uid, `at` a timestamp), a new house has
  none; no `note` anywhere. Lengths are counted in code points
  with a pattern (`matches('(?s).{0,20}')`): the rules' `size()` counts UTF-16 units
  (🚒 = 2), the patterns count 🚒 as 1, as `characterCount` does.
- **Times** are only required to be timestamps, never compared with `request.time`: the
  phone's clock stamps a mark made offline hours before it reaches the server, and a phone
  whose clock is ahead would see its marks refused and silently taken back, while a forged
  time harms nothing (it is shown, never used to order writes). The one exception is the
  30-day purge (T2.6b), which compares a **stored** `deletedAt` with `request.time`; so a
  member who writes a removal time forged 30 days back can purge it at once. **Accepted risk**
  (decided 2026-10-16, T2.6d): members are trusted and the code is the secret; bounding a new
  `deletedAt` to a window of `request.time` would refuse removals synced late, and would still
  leave the undo of « Restaurer » open, which puts back a teammate's earlier removal with its
  old time.
- **Creating a tournée** is accepted only whole: the tournée checks with `getAfter` that the
  same transaction writes its reservation (create-only, so number + station stay unique), its
  code (create-only, so no one replaces another tournée's preview; the preview must repeat
  the tournée's number, station and campaign), its creator `active` and accepted by
  themself, and its first campaign (the current year). Each of those documents in turn is
  accepted only from the tournée's creator and must match the tournée as written.
- **Members.** A request is the caller's own document, `pending`, with the tournée's current
  code. Any active member accepts (status, `acceptedBy` = caller, `acceptedAt` only) or refuses
  a request; the newcomer cancels it. The creator removes an active member; a member leaves.
  An active member renames themself: their own document, `displayName` only, a cleaned name
  ≤ 30 (T2.7b); nobody renames someone else, not even the creator. A pending member cannot
  rename themself: a name changed while the request waits is sent by the phone once accepted
  (T2.7c), so the rules stay as they are.
  The creator's own document goes only in the batch that deletes the tournée.
- **New code** (creator): only `joinCode` changes, the new code document is created and the old
  one deleted in the same transaction. **Deleting** (creator): the contents first (campaigns,
  streets), then one batch where the tournée goes only with its code, its reservation and the
  creator's member document, the other members with them (from T2.6c). Previous campaigns are
  read-only (streets are written only in `currentCampaign`); the creator alone deletes
  campaigns outright, and streets outright, which only the deletion does, except the 30-day
  purge below.
- **30-day purge** (T2.6b): any active member deletes a street of the current campaign whose
  `deletedAt` is more than 30 days before `request.time`, and drops one house of the
  `houses` map per write whose `deletedAt` is too (nothing else changing in that write).
  A street or a number removed 30 days ago or less, or restored, cannot be purged.
- **Streets.** The rules language has no loops, and cannot name the key a write changed (a set
  has no index): the house or door is found by value (`values().removeAll(…)`: the one entry
  that is new; each holds its own number or stamp). So a write may:
  - change **one house in place**: its marks (status, time, `by` = caller, `at`), its layout
    (labelStyle, layout, doors; house stamp = caller), its removal (`deletedBy` = caller, or
    null to restore it), each checked field by field;
  - change **one door** of a building: the door entry whole and valid, `by` = caller;
  - **move one house** (renumbering or its undo): the new entry whole and valid, under its
    label, stamped by the caller;
  - **add houses** (« numéros en plus »): one new house is checked whole (unmarked, not a
    building, under its label); several are only counted (≤ 500);
  - change the street's `name` or its deletion (`deletedBy` = caller), never its commune or BAN
    id;
  - **drop one house** of the Corbeille removed more than 30 days ago (the purge).
  Anything else (two houses changed at once, a house deleted outright before its 30 days in the Corbeille, a mark landing on a
  number or a door that is no longer there) is refused. **What the rules cannot check one by
  one** — the houses of a new street and of several numbers added at once, and the doors and
  layout of a building written whole — are only counted (doors ≤ 500, layout rows ≤ 26 × 51);
  making them checkable would need writes split into small fixed-size chunks.
- **A removal put back by an undo of « Restaurer »** keeps the teammate's stamp (§6.2): the
  rules accept a number's `deletedBy` that is the caller or an active member of the tournée
  (so a member could also name a teammate as the remover of a number; the stricter choice,
  stamping that undo with who undoes as for houses and doors, would change T2.3's undo).
- Fields no adapter writes yet (`prev` and a new campaign in v1.1) are refused: the task that
  writes them extends the rules and their tests.
- **Communes** (#78): a new tournée must hold `communes`, a list of 1 to 50 entries; the first
  entry is checked whole (`code` an INSEE code, `name` trimmed, not blank, ≤ 100, `lat` / `lon`
  in range or both null, nothing else), the others only counted. Any active member or admin
  updates `communes` alone, by one entry: an addition (checked whole, ≤ 50 in all) or a
  removal that leaves at least one. A tournée stored before has no list: it counts as empty, so
  its first commune can be added. Duplicates of a code cannot be ruled out (no loops): the
  reader skips them.
- **Shape and assignees** (T3.3): optional on a new street (an app of before the map writes
  neither); `shape` a list of at most 1 000 lines (counted, not checked line by line), never
  changed afterwards, except **filled once** (#92, `isShapeFill`): an update of `shape` alone,
  1 to 1 000 lines (the first a text), while the stored shape is absent or `[]` (an older
  app never writes it; two phones filling at once cannot replace each other's);
  `assignees` on a new street `[]` or `[caller]`. An update may change
  `assignees` only by adding or removing **the caller** (set comparison, no duplicate): nobody
  puts a teammate on a street or takes them off it.
- Indexes (`firebase/firestore.indexes.json`): `houses` of `streets` is exempt from
  single-field indexing (its thousands of sub-fields would count against the index limits and
  slow every write); no query of the adapters needs a composite index.

### 8.3 Privacy

- **Auth:** anonymous Firebase account created on first launch. The uid is the member id.
  Reinstalling the app creates a new uid, so the person rejoins with the code and is approved
  again (their old member row can be removed by the creator).
- **Data stored:** addresses and their positions (public data), visit statuses, when to come
  back (a day and an hour, #81), first names of the members. No free text about a house: the
  « repasser » hint of ≤ 20 characters became a day and an hour (#81), and the free note on houses, doors and buildings was removed (T1.20, Q23) as
  too likely to hold personal data (GDPR), and notes already stored on a phone are erased when
  the app reads them. No donations, no residents' names, no residents' answers.
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
| Street under a tap | `https://data.geopf.fr/geocodage/reverse?lon={lon}&lat={lat}&index=address&type=street&limit=1` | Returns BAN `id` = idVoie (`69264_1460`), `name`, `citycode`, `city`, one point of the street; always the nearest street, whatever the distance |
| Street search by name | `https://data.geopf.fr/geocodage/search?q={q}&index=address&type=street&citycode={code}&limit=10` | For the search box; `q` 3–200 characters starting with a letter or digit, else HTTP 400 |
| Commune by name | `https://geo.api.gouv.fr/communes?nom={q}&fields=nom,code,codesPostaux,centre&boost=population&limit=5` | Import screen (5.0), the communes of a tournée (5.2, 5.8): `nom`, `code` (INSEE), `codesPostaux`, `centre` (GeoJSON point); `[]` when nothing matches |
| Streets of a commune | `https://plateforme.adresse.data.gouv.fr/lookup/{inseeCode}` | `voies[]`: `idVoie`, `nomVoie`, `nbNumeros`, `type`; 404 for an unknown commune |
| Numbers of a street | `https://plateforme.adresse.data.gouv.fr/lookup/{idVoie}` | `numeros[]`: `numero`, `suffixe`, `position.coordinates` [lon, lat]; a number may appear twice; 404 for an unknown street |
| Shape of a street | OpenFreeMap TileJSON `https://tiles.openfreemap.org/planet` (its `tiles` template, versioned weekly: `…/planet/20261011_080001_pt/{z}/{x}/{y}.pbf`), then the z14 vector tiles around the street's houses, layer `transportation_name`, property `name` (§6.1, #92) | Same data as the map. A tile ≈ 50–250 kB, ≈ 0.1 s; max zoom 14. Lines clipped per tile with a buffer: cut and joined by the app. Fallback when empty: no shape, house dots only. Replaced Overpass (#92: 41 s then 502 on 2026-10-18) |

All of them are wrapped behind domain interfaces (`AddressDirectory`, `CommuneSearch`, `StreetShapes`), so the rest
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
├── infrastructure/  Adapters implementing the ports: firestore/, ban/ (BAN + geopf, http),
│                    map_tiles/, maplibre_offline/, firebase_auth/, preferences/, mappers.
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
- **Use cases** are the only entry point to behaviour: `SetHouseDetails`, `AddStreetFromMap`,
  `AddManualStreet`, `EditStreetNumbers`, `DescribeBuilding`, `CreateTournee`,
  `RequestToJoin`, `AcceptMember`, `DownloadTournee`, `StartCampaign`, … A use case loads the
  aggregate through its port, calls the root, saves the `StreetChange` through the port.
- **Adapters translate**: Firestore maps ⇄ aggregates, `StreetChange` → field-path updates,
  geopf / BAN JSON, vector tiles → value objects. Translation code is pure functions, tested alone.
- The map is split the same way: the domain computes *what* to draw; `ui/map/` only turns that
  into MapLibre GeoJSON sources and layers, and taps into coordinates.

### 10.2 Stack

| Concern | Choice |
|---|---|
| SDK | Flutter stable + Dart 3 (versions pinned at scaffolding, M0) |
| State + DI | `flutter_riverpod` 3 (Notifier / AsyncNotifier), **no code generation**: faster builds, readable code |
| Navigation | `go_router` |
| Models | Dart 3 `final class` / `sealed class` / records; value equality hand-written in the domain (no `freezed`, no build_runner) |
| Backend | FlutterFire (official): `firebase_core`, `cloud_firestore`, `firebase_auth` (anonymous), `firebase_app_check` (Play Integrity on Android, App Attest on iOS). Spark (free) plan, decided at the M2 checkpoint (Q20); Blaze-ready |
| Map | `maplibre_gl` (official MapLibre plugin) + OpenFreeMap tiles; offline regions |
| HTTP | `http` (geopf, BAN, OpenFreeMap tiles), `MockClient` in tests |
| QR | `qr_flutter` (draw), `mobile_scanner` (scan; camera permission asked on tap) |
| Location | `geolocator`, only for "locate me" |
| Share | `share_plus` |
| Settings | `shared_preferences` |
| i18n | `flutter_localizations` + ARB, **French only** (`app_fr.arb`) |
| Fonts | Atkinson Hyperlegible + Barlow Condensed bundled as assets (OFL), so they work offline |
| Lint | `flutter_lints` + strict analysis options (`strict-casts`, `strict-raw-types`), architecture test |
| Android | minSdk 26; release signed with the upload key (`TOURNEE_RELEASE_*` from `~/.gradle/gradle.properties` or env, debug key as fallback so CI builds); `flutter build appbundle`; published to Play by the `release-store` skill (`tool/publish_play.py`), Play App Signing holds the app key |
| iOS (later) | iOS 15+; built and signed in the cloud (Codemagic or GitHub Actions macOS runner) → TestFlight. Needs the Apple developer account only, no Mac |

### 10.3 Firebase setup (manual, done once by you)

1. Create a Firebase project, Firestore in `europe-west`, enable Anonymous sign-in and App Check.
2. `dart pub global activate flutterfire_cli`, then `flutterfire configure` for Android
   (`fr.mandarine.tourneecalendriers`); iOS is added the same way later.
3. Install the Firebase CLI (`npm i -g firebase-tools`) for the rules deploys
   (`firebase deploy --only firestore --project <id>` from `firebase/`). The emulator tests
   need no global CLI: `firebase/package.json` pins its own.

The generated `firebase_options.dart` (moved to `lib/bootstrap/`, the only layer that reads
it: `flutterfire configure --out=lib/bootstrap/firebase_options.dart`) and
`google-services.json` are gitignored (the repo is public), and so is the root `firebase.json`
`flutterfire` writes. CI writes the first two with `tool/write_firebase_config.sh` from the
secrets `FIREBASE_OPTIONS_DART` and `GOOGLE_SERVICES_JSON` (each the base64 of its file, also
set as Dependabot secrets). App Check (`bootstrap/firebase.dart`) uses Play Integrity in
release builds and the debug provider in debug builds, with a fixed debug token registered in
the console and passed by `--dart-define-from-file` (kept out of the repository). Both
SHA-256 (upload key, Play app signing key) are registered on the Firebase Android app, and
the Play Console app is linked to the Firebase Cloud project for Play Integrity.

---

## 11. Testing strategy (fast by design)

The rule: **the loop a developer runs dozens of times stays under a minute**. Slow suites exist,
but they run once per task and in CI.

| Suite | What | Runs on | When | Budget |
|---|---|---|---|---|
| Domain | aggregates, value objects, domain services — plain `test` | Dart VM | every TDD cycle | ms per test |
| Application | use cases with **hand-written fakes** of the ports | Dart VM | every TDD cycle | ms per test |
| Presentation | Riverpod notifiers via `ProviderContainer`, ports overridden by fakes | Dart VM | every TDD cycle | ms per test |
| Adapters | Firestore adapter against `fake_cloud_firestore` (in memory, no emulator); geopf / BAN parsing with `MockClient` + JSON fixtures captured from the real services, vector tiles built byte by byte by the tests | Dart VM | when touched | < 10 s |
| Widgets | widget tests for the critical interactions only: welcome gating, tap-cycle + undo on street tiles, hold → house sheet, building grid, edit mode remove + undo, street card states, join pending screen | `flutter test` (headless) | end of each UI task, CI | a few per UI task; the whole suite stays under 60 s |
| Architecture | import rules between layers | Dart VM | every run | < 1 s |
| Coverage | **100 % line coverage** on `domain/`, `application/`, `presentation/` and the adapters' mapping code, checked by a script on `coverage/lcov.info` | — | end of task, CI | piggybacks |
| Rules | Firestore security rules in the Firebase emulator (`@firebase/rules-unit-testing`, `node --test`): `cd firebase && npm ci && npm test` starts the emulator itself (`firebase emulators:exec`, demo project, versions pinned for Node 18+, Java 11+) | Node + emulator | when `firebase/` or the Firestore adapters change, CI | < 1 min |
| Instrumented | `integration_test/`: a handful of end-to-end flows in the real app, ≤ 10 tests over both files. `app_test.dart` (launch, mark a house + undo, building, edit a street, offline cold start…) on the real project, Firestore offline. `admin_test.dart` (create a tournée, « Toutes les tournées » → Rejoindre, revocation → « Vous n'êtes plus administrateur. ») against the local Auth + Firestore emulators with the real rules: the test adds and removes `admins/{uid}` itself (`tool/admin_e2e.sh`) | Android emulator (`Medium_Phone_API_36.1`), run by Claude | before every push to `main` | < 3 min |
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
| Q2 | Who deletes what | Any member adds, edits and deletes streets. Only the creator deletes the tournée or removes members. **From #75: only admins** (5.12). |
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
| Q17 | Next year | One campaign per year inside the tournée. New campaign keeps streets, numbers, buildings; resets statuses, *repasser*, assignees; *Reprendre mes rues 2026*; last year's result shown in the sheets. v1.1, model ready in v1. |
| Q18 | Who starts a campaign, what is kept | The creator (an admin from #75, 5.12). Previous campaign read-only; the one before is deleted. |
| Q19 | Guessed / leaked codes | A code only creates a pending request; any accepted member accepts or refuses. App Check in v1. Soft delete with a 30-day Corbeille. |
| Q20 | Infrastructure | **Decided at the M2 checkpoint (2026-10-05): Spark (free), Blaze-ready.** Join on the phone (`joinCodes` get → pending member) behind a `TourneeDirectory` port; App Check + approval are the guard; the Corbeille purge runs on members' phones (5.11). Move to Blaze (1 click, no data migration) and a rate-limited callable join + scheduled purge when real usage nears Spark's shared daily quota (50 k reads, 20 k writes for the whole app ≈ 10 busy tournées a day) or abuse shows up. Another backend was rejected: it loses Firestore's offline cache. |
| Q21 | Switching / creating from Accueil | The title is a button: « Mes tournées » sheet with all my tournées (progress, pending requests), *Créer*, *Rejoindre*. |
| Q22 | Technical stack | **Flutter + Riverpod**, strict DDD (hexagonal: domain, use cases, ports, adapters). Android first; iOS later from the same code, built in the cloud (no Mac). Mutation gate dropped (no Dart tool); 100 % coverage gate kept. |
| Q23 | Notes | **Removed for privacy, 2026-10-05** (after the phone test of M1): a free note on a house, door or building is too likely to hold personal data (GDPR). No note field anywhere; notes already on a phone are erased when the app reads them (storage schema v3). The « repasser » hint stayed, limited to 20 characters (was 50); since #81 it is a day and an hour, no free text. |

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
