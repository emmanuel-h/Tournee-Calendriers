# Tournée Calendriers — App plan

Status: **screens chosen, mockups in review** · 2026-10-04 · mockups: `docs/mockups/`
Tasks: GitHub issues, mapped in `docs/TASKS.md`.

The app UI is **entirely in French**. This document is in English; every screen sketch shows
the real French copy.

---

## 1. Goal

Each year, firefighters sell calendars door to door. Each firefighter covers a set of
streets, and a team shares the whole area (its *secteur*). The app lets each person:

- pick the streets they cover **by tapping them on a map**, and add missing streets or numbers by hand,
- mark every house as **done / to do / nobody home**, quickly, with one hand, in the street,
- add details to a house: apartments handled one by one, "come back later" with a day and an hour,
- see on a map what is done, partly done and still to do, live, across the whole team,
- count the money of each outing (« tournée »): dons per payment method, totals only, never tied
  to a house (#63, §5.13); a house remembers only how many calendars it took.

Once a secteur has been downloaded, the app works **fully offline** (map included) and syncs
with the server whenever the network is available.

### In scope for v1

- Name + team code (or QR) onboarding, create / join a secteur
- Map of the secteur: streets coloured by progress, houses as coloured dots when zoomed in
- Street selection on the map (tap a road), backed by the national address base (BAN)
- Manual entry of missing streets and numbers
- House status (« repasser » with an optional day and hour, #81), apartment units
- Live team sync, full offline mode after download
- Tournées (#63, §5.13): dons per payment method during an outing, free calendars, a recap to
  recount the money, the secteur's totals per campaign (never per member). Only totals leave
  the phone; a house keeps its number of calendars, no amount
- French only, light + dark

### Out of scope for v1 (possible later)

- Residents' answers: never recorded (a refusal is a status, ⊘). A don is **never tied to a
  house, a door or an address**: only a tournée's totals per payment method are kept; a house
  keeps only how many calendars it took (§5.13, §8.3)
- Free-text notes on houses and doors: removed for privacy (§8.3, Q23); since #81 the
  « repasser » hint is a day and an hour, so no free text is kept about a house
- English or other languages
- Starting next year's campaign from this year's (v1.1). **The v1 data model is built for it** (§6): a secteur holds
  one campaign per year, so nothing needs migrating when the button ships
- Route planning / navigation, statistics beyond progress, exports, web dashboard

---

## 2. Vocabulary

Code uses English names, the UI uses French.

| UI (FR) | Code | Meaning |
|---|---|---|
| Secteur | `Sector` (code renamed from `Tournee` in #116; Firestore `sectors/`) | A team's area, identified by its **number + centre de secours + code**. Lives across years. **Renamed 2026-11-02** from « Tournée » (#63), on every screen and in this whole document (#115); « tournée » now only names one outing (below) |
| Centre de secours (CS) | `RescueCentre` | The fire station the secteur belongs to, e.g. CS Villefranche |
| Campagne | `Campaign` | One year of a secteur (2026, 2027…). Statuses belong to a campaign; streets and buildings carry over |
| Membre | `Member` | A firefighter who joined the secteur |
| Rue | `Street` | A street in a commune, with its house numbers and its shape on the map |
| Numéro / maison | `House` | One address on a street (`12`, `12bis`), with its position when known |
| Logement | `Dwelling` | One unit inside a building (`Apt 3`, `B2`) |
| Statut | `VisitStatus` | `TO_DO` (à faire), `DONE` (fait), `REFUSED` (refusé, #63), `NOBODY_HOME` (personne), `COME_BACK` (repasser): exactly one per house or door |
| Repasser | `VisitStatus.comeBack` + `ComeBack` | A status: the resident asked to come back later, optionally on a day and at about an hour (« samedi vers 18 h », the `ComeBack` value, #81). A building, which has no status, may carry its own « repasser » |
| ~~Mes rues~~ | ~~assignees~~ | Removed (5.14, 2026-11-03): no street belongs to a member; the whole secteur covers every street |
| Tournée | `Round` | One outing of one member on the open secteur, from « Commencer une tournée » to « Valider la tournée » (#63). Holds its dons until it is validated, then only its totals remain |
| Don | `Donation` | Money received during a tournée: a payment method and an amount, or a calendar given for free (« Calendrier offert »). Never tied to a house or a time |
| Moyen de paiement | `PaymentMethod` | `cash` (Espèces), `cheque` (Chèque), `card` (Carte bancaire) |
| Collecte | `RoundSummary` (per campaign) | The validated tournées of a campaign and their totals, seen by the whole secteur, never split per member |
| Calendriers | `House.calendars` | How many calendars a house (or door) marked ✓ took: 1, or more after « + Ajouter un don ». No amount |
| ~~Libre~~ | — | Removed with the attribution (5.14) |

---

## 3. Decisions taken

| Topic | Decision |
|---|---|
| Platform | **Flutter** (Dart): Android first; iOS kept open (same code, built in the cloud once an Apple developer account exists — no Mac needed) |
| Architecture | **Strict DDD, hexagonal**: domain (entities, value objects, aggregates) → application (use cases + ports) → adapters (Firestore, HTTP, map, UI). Riverpod for state and dependency injection |
| Language | **French only.** Strings in `res/values/strings.xml`; no other locale |
| Map | **MapLibre** (`maplibre_gl`, official Flutter plugin, offline regions on Android and iOS) with **OpenFreeMap** vector tiles (OpenStreetMap data, free, no key) |
| Street picking | Tap a road → the IGN BD TOPO stretch under the finger gives the BAN street by its id (the side under the finger) → BAN gives its name, commune and numbers with positions → the BD TOPO stretches of that id give its line, stored once (§5.18, #166). Where BD TOPO has nothing: reverse geocoding (IGN Géoplateforme) and the OpenFreeMap vector tiles (OSM) by name, as before (#92, #134) |
| Manual edits | Missing streets and numbers can always be added by hand, offline too |
| Sharing | Live sync through **Firebase Firestore**; its offline cache *is* the local store (no Room) |
| Offline | Explicit "download the secteur" step: all street documents into an unlimited Firestore cache + map tiles of the secteur area into a MapLibre offline region |
| Identity | Firebase **anonymous auth** + display name + 6-character join code or QR |
| Secteur identity | Number + centre de secours + code. Number + CS is unique across the app; the code is the secret used to join |
| Years | A secteur has one campaign per year. A new campaign copies streets, numbers and buildings; statuses and *repasser* start at ○ (v1.1) |
| Apartments | Optional unit list per house; building status derived from units |
| Comments in code | Explain the *why* and non-obvious Dart/Flutter concepts; never restate the code |
| Tests | TDD, fast Dart tests in the dev loop; 100 % coverage gate on domain + application + presentation; no mutation-testing gate (no reliable Dart tool) |

---

## 4. User flows

```
first launch
   │
   ▼
 Bienvenue ── name ──┬── Créer un secteur ──▶ QR + code ──┐
                     └── Rejoindre (QR or code) ───────────┤
                                                           ▼
                               Accueil = map of the secteur + streets panel (5.14)
                               (the app downloads the secteur for offline use by
                                itself, unseen, whenever it is online — §7)
              ┌──────────────────┬──────────────┼──────────────────┬─────────────┐
              ▼                  ▼              ▼                  ▼             ▼
        Rue (2 sides)     Ajouter des rues   Rue à la main     Équipe        Paramètres
              │           (map mode: tap      (missing street)
              ▼            roads → tick them)
   Fiche maison / Immeuble
```

Next launches open the last secteur directly, on the map.

Where the app opens (T2.5, decided from the phone alone, so an offline cold start opens
where it should): a secteur open → it (Accueil); otherwise a request to join waits →
« Demande envoyée » for the latest one; otherwise the phone knows secteurs, none open → the
start screen with none open (« Aucun secteur ouvert », 5.0); otherwise → « Bienvenue ».
Streets only ever live in a secteur (#119): a phone with no secteur open holds none, and
offers to join one (or, for an admin, to create one). Nothing on the marking path ever waits for a
request.

Before the round (once):

1. Join the secteur with the QR code at the station. Nothing else to do for offline: while
   online, the app saves the streets and the map tiles by itself, unseen (§7).
2. Secteur (🗺) → « Ajouter des rues » → tap each road, or draw a « Zone » → « Ajouter N rues »
   (5.14; no attribution: the team covers the whole secteur).
3. A cul-de-sac missing from the map → "Rue absente ? Saisir à la main".

In the street (often offline):

1. Open the app → the map shows the secteur's streets coloured; the panel lists them. Leaving
   for an outing: « Commencer une tournée » (§5.13): houses are marked only during a tournée (5.14).
2. Tap *Rue des Lilas* → Street screen: odd side on the left, even side on the right.
3. Each door: **tap the tile** → its five statuses → one tap: ✓ Fait (during a tournée, then
   the don: « 10 € », or « Calendrier offert »), ⊘ Refusé, ✗ Personne, ↻ Repasser (then the
   day and hour), ○ À faire. Undo snackbar. A second calendar: tap the ✓ house → « + Ajouter
   un don ». (Decided 2026-11-02, #63; replaces the tap cycle, §5.6.)
4. Building at n°8: tap → unit grid → tap each door the same way.
5. "Repassez ce soir" → tap the tile → ↻ Repasser → « Aujourd'hui », « Vers 19 h » → « Valider ».
6. Back in range: queued changes sync; the team map updates.
7. Back at the station: « Terminer » → « Bilan de la tournée » → recount the money →
   « Valider la tournée »: the secteur sees its totals.

---

## 5. Screens

Agreed in the terminal on 2026-10-04 (ASCII variants), confirmed with visual mockups in
`docs/mockups/`. Phone portrait. Tap targets ≥ 48 dp; street tiles ≥ 56 dp high. Status is never
shown by colour alone: every status has a glyph too.

Glyphs: `○` à faire · `✓` fait · `⊘` refusé (#63, to build) · `✗` personne · `↻` repasser · `◐ 7/12` immeuble en partie.

**One gesture everywhere** (decided 2026-11-02, #63, §5.6 « Status picker »): **a tap on a
house or a door shows its five statuses; one tap on a status stores it**, and only ✓ (the
don) and ↻ (the day and hour) ask for more. Only during a tournée (5.14, #122): with none on,
the tap says to start one. No hold. A building tile opens its unit
grid on tap. *(Before: the tap cycled `○ → ✓ → ✗ → ↻ → ○` and a hold opened the details; the
code still does so until the picker is built.)*

**Text fields:** a value refused on the keyboard's « OK » (a street name, a number, numbers to
add, a door name) keeps the focus and the keyboard on its field, with the message under it; a
value taken behaves as with a button. **Typography:** French texts put a non-breaking space
(U+00A0) inside « » and before : ; ? !, so a line never wraps between a sign and its word
(checked on `app_fr.arb` by a test).

**Accessibility and dark mode (T5.1, #35):**
- **TalkBack:** every control has a French label (`app_fr.arb`); a tile is read as one sentence,
  number then status (« Numéro 7, personne »); glyphs, chevrons and arrows drawn next to words
  are decoration, left out of what TalkBack reads. Tap targets are 48 dp at least; the only
  exception is a door's ✕ in « Modifier les portes » (36 dp wide, 5.7). Widget tests check
  the labels and the 48 dp on each main screen with Flutter's accessibility guidelines.
- **Font size up to 200 %:** nothing overflows at `TextScaler.linear(2.0)` on a 411 dp wide
  phone (street screen, house and door sheets, Accueil, Paramètres, Équipe, Bienvenue,
  Rejoindre, Nouveau secteur; widget tests with the real fonts). Long lines wrap or end in
  « … »; a row with a fixed height grows with the text instead: Accueil's folded panel
  (`homePanelFoldedHeight`), the street's counts row (at least 44 dp, 48 dp with
  « Masquer faits ») and the « Appui : … » hints. Buttons keep a fixed padding (24 dp for the
  main ones, 16 dp otherwise) so a label wrapped on two lines stays inside its outline. Two
  rows change their layout when the text no longer fits, judged on the measured widths, not
  on a scale threshold (#35): the street's counts go on their own line above « Masquer
  faits », nothing hidden; « Gérer l'immeuble » and « Repasser », under a building's grid,
  stack full width, one above the other, when either label would no longer hold on one line
  in half the width. At normal size both stay as the mockups show.
- **Contrast (WCAG):** text ≥ 4.5:1, borders, glyphs and bars ≥ 3:1, in both palettes; a test
  (`test/ui/theme/app_colors_test.dart`) holds every pair. The dark palette keeps the light
  one's hues. Where no colour can both carry white text and read on the dark surface, the dark
  palette turns it over: its accent is a light red under dark text, and the done green is two
  tokens, `done` (dark, a tile under white text) and `doneInk` (light, a count, a mark or a
  progress bar). The greyed text of a secteur that cannot open offline (`unavailable`, 5.3)
  stays below 4.5:1 on purpose, as for a disabled control, with « Disponible avec réseau »
  saying it. The light palette's outlines (to-do tiles, fields) are under 3:1 as approved:
  their words identify them, so WCAG does not require it; the dark ones reach 3:1.
- **The map stays light in dark mode:** OpenFreeMap's « liberty » style has no dark variant
  here, so the street lines and the picked road keep the light palette's colours in both
  themes; the house dots take the theme's tile colours (each with its glyph).

### 5.0 Accueil with no secteur open

Agreed 2026-11-03 (#119, ASCII then `docs/mockups/NoSector.dc.html`). Streets only ever live
in a secteur: with none open, Accueil has nothing to list and says how to get one.

```
┌──────────────────────────────┐
│ Tournée des calendriers ▾ [⚙]│  ← opens « Mes secteurs »; no 👥
│ ░░░░░░░░░░░░░░░░░░░░░░░░ (◎) │  ← base map, no street, no legend; « Me localiser »
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
├──────────────────────────────┤
│            ━━━               │
│ Aucun secteur ouvert         │
│ Rejoignez le secteur de votre│
│ équipe avec le code qu'on    │
│ vous a donné.                │
│ [   Rejoindre un secteur   ] │  ← red
│ [    Créer un secteur      ] │  ← outlined, admins only (5.12)
└──────────────────────────────┘
```

- Shown at `/` whenever no secteur is open: a phone that knows secteurs (a request
  refused, a secteur left or lost, another forgotten) and has no request waiting (§4).
- **Map**: the OpenFreeMap background alone, on France (the map's default with no area),
  with « Me localiser » and the attribution clear of the panel; no street, no legend.
- **Top bar**: Accueil's (5.3), the app's name with ▾ opening « Mes secteurs » and ⚙
  Paramètres; no 👥. Debug builds show the gallery action.
- **Panel** (fixed, not draggable; its handle is decoration): « Aucun secteur ouvert », the
  line under it, then « Rejoindre un secteur » (red) and, for an admin only (`AdminStatus`,
  as on « Bienvenue »), « Créer un secteur » (outlined) under it. Each asks « Votre
  prénom » first when the phone has no name (as « Mes secteurs » does), then opens 5.2.
  It scrolls rather than overflow with very large text.
- **Removed in #119**: the phone-only street list of M1 (« Mes rues » with no secteur open),
  « Importer des rues » outside « Ajouter des rues », the « Les ajouter au secteur » card that
  moved the phone's streets into a secteur, and the phone street store used with no secteur
  open. The checklist lives on as the « Liste » tab of « Ajouter des rues » (5.4). Streets
  already kept on a phone are deleted at the next start (§6.3), never shown or offered.
- **Pending sync** (T2.9): while a secteur is open and changes made on the phone have not
  reached the server, a line sits at the bottom of Accueil's panel (5.3): a cloud glyph and
  « Modifications de 3 rues en attente d'envoi » (« … d'une rue … » for one), read out as
  such. It goes away once all is sent (§7).

### 5.1 Bienvenue (first launch only)

```
┌──────────────────────────────┐
│   Tournée des calendriers    │
│                              │
│   Votre prénom [ Manu      ] │
│                              │
│   [   Créer un secteur    ]  │
│   [   Rejoindre un secteur]  │
└──────────────────────────────┘
```

Both buttons stay disabled until the name is filled in.

Delivered in T2.5 (Welcome mockup): shown only where the app opens on a phone that holds
nothing (§4). The app's logo and name, « Notez chaque porte… », « Votre prénom » (« Visible
par votre équipe. » under it; « Prénom limité à 30 caractères. » when too long), then
« Créer un secteur » and « Rejoindre un secteur », disabled until the name is a valid
`MemberName`. Either keeps the name on the phone (`ChangeMemberName`, the one of Paramètres)
and opens its screen above « Bienvenue »; the field starts from the name kept.

From #75 (5.12): « Créer un secteur » shows only for an admin (so a fresh install, never yet
an admin, shows only « Rejoindre un secteur », in red), and the bottom of the screen shows
« Identifiant de l'appareil : … » with a copy button.

### 5.2 Créer / Rejoindre

```
  Créer                               Rejoindre
┌──────────────────────────────┐    ┌──────────────────────────────┐
│ ← Nouveau secteur            │    │ ← Rejoindre un secteur       │
│ Centre de secours            │    │ [   📷 Scanner le QR code   ] │
│ [ CS Villefranche       ▾ ]  │    │      ou saisir le code       │
│ N° de secteur   [ 49       ] │    │ [ K7P ] - [ 2QX ]            │
│ Année           [ 2026     ] │    │ ┌──────────────────────────┐ │
│ [          Créer         ]   │    │ │ Secteur 49               │ │
│ ──────────────────────────── │    │ │ CS Villefranche          │ │
│ Secteur 49 · CS Villefranche │    │ │ Campagne 2026            │ │
│        ▄▄▄▄ ▄ ▄▄▄▄           │    │ └──────────────────────────┘ │
│ Code K7P-2QX [⧉] [Partager]  │    │ [  Demander à rejoindre  ]   │
└──────────────────────────────┘    └──────────────────────────────┘

  Créer — the pair already exists
┌──────────────────────────────┐
│ Centre de secours            │
│ [ CS Villefranche       ▾ ]  │
│ N° de secteur   [ 49       ] │
│ ⚠ Le secteur 49 du CS        │
│   Villefranche existe déjà.  │
│   Demandez le code ou le QR  │
│   code à son créateur.       │
│ [ Rejoindre avec un code ]   │
└──────────────────────────────┘
```

- **A secteur is identified by its number, its centre de secours and its code.** Number + CS is
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
- **Rejoindre:** QR code (normal way) or the code alone; the app then shows *Secteur 49 · CS
  Villefranche · Campagne 2026* to confirm before joining. **Joining sends a request**: the
  newcomer waits on the screen below until an accepted member lets them in (§8). Scanning uses
  `mobile_scanner` (Android and iOS); the camera permission is asked only when *Scanner* is
  tapped. `qr_flutter` draws the QR.
- **QR payload** (fixed in T2.6): the code's six characters and nothing else, `K7P2QX`
  (`JoinCode.value`): no URL, no prefix. The scanner of « Rejoindre » reads it with
  `JoinCode.parse`, like a typed code, so any other QR code is refused as an invalid code. Drawn
  dark on white whatever the theme, so it scans.
- An admin can regenerate the code from Équipe (old code stops working; members stay).
- **Only admins create a secteur** (and so add a centre de secours), from #75 (5.12).
- **Communes** (#78, Create mockup): between « Centre de secours » and « N° de secteur »,
  « Communes », a chip per commune picked (« Villefranche-sur-Saône (69400) » and ✕, a 48 dp
  target) then the field « + Ajouter une commune… », which searches geo.api.gouv.fr as « Importer
  des rues » does (two characters, 300 ms pause, late answers ignored); a suggestion tapped
  becomes a chip and empties the field, one already picked is not added twice. « Créer » stays
  off until at least one commune is picked; at most 50 (`Sector.maxCommunes`). Each commune
  keeps the centre geo.api.gouv.fr gives (`centre`), so the map of 5.4 is centred offline.
  When geo.api.gouv.fr fails, the Géoplateforme answers instead (§9, #137). Under the field:
  « Pas de réseau : la recherche de communes en a besoin. Réessayez quand le téléphone
  capte. » when the phone has no way out (no route, the name not found, no answer in time),
  « Impossible de chercher les communes pour l'instant. Réessayez plus tard. » when it has a
  connection but both services refused it or answered an error.
- Delivered in T2.5 (Create, CreateTaken, Join mockups). Both screens first need the phone's
  account (§6.1): a line « Connexion au serveur… » while it signs in, « Hors ligne : créer ou
  rejoindre un secteur demande le réseau. » with « Réessayer » when it cannot; the server
  is asked nothing before.
  - **Nouveau secteur:** while « Centre de secours » has the focus and nothing is picked, a
    list under it: the known centres whose station key contains the typed one (all of them
    before a station is named), then « + Ajouter « villef » » unless a known centre is that
    same station; a pick fills the field, a new key typed forgets it. « Nom limité à 80
    caractères. » when too long. « N° de secteur » (« Un numéro de 1 à 9999. ») and
    « Année » (the phone's year, « Une année de 2000 à 2099. »). 300 ms after the centre or
    the number last changed, the server says whether the pair exists (a late answer to older
    input is ignored; no answer offline: « Créer » still asks, and the server refuses a
    duplicate): « ⚠ Le secteur 49 du CS Villefranche existe déjà. Demandez le code ou le QR
    code à la personne qui l'a créée. » in a red frame, the number framed red, « Créer »
    disabled, and « Rejoindre avec un code » (replaces this screen with « Rejoindre »).
    « Créer » keeps the secteur among the member's and opens it at once; offline « Pas de
    réseau. Réessayez une fois connecté. », a number taken meanwhile shows as taken. Then,
    the form frozen, a card « Secteur 49 · CS Villefranche est prêt. Montrez ce code à
    l'équipe. », the QR code (Équipe's, larger), « 234-567 » with its copy button (Équipe's)
    and « Partager » (Équipe's text); « Continuer » (and back) open the start screen on the new secteur.
  - **Rejoindre:** « Scanner le QR code » opens the camera full screen (permission asked
    then; refused: « L'appareil photo n'est pas disponible. Saisissez le code à la main. »),
    which closes on the first QR code read; one that is not a code: « Ce QR code n'est pas
    celui d'un secteur. ». Or « Code » in two boxes of three: upper-cased, dash and spaces
    dropped, a whole code typed or pasted in the first fills both, at most three characters
    each; the first box full and valid moves on to the second; a character outside the
    alphabet: « Un code n'a que des lettres et des chiffres, sans 0, O, 1, I ni L. ». A
    complete code is looked up at once: the card « 49 | Secteur 49 · CS Villefranche » over
    « Campagne 2026 » (**no member or street count**: `joinCodes` holds only the preview
    fields, §6.2 — the mockup's « 6 membres · 60 rues » is not shown), « Aucun secteur n'a
    ce code. Vérifiez-le… », or « Pas de réseau : le secteur ne peut pas être affiché. »
    with « Réessayer ». « Demander à rejoindre » (the mockup's label) sends the request and
    opens « Demande envoyée »; a secteur already in « Mes secteurs » sends nothing: « Cette
    secteur est déjà dans « Mes secteurs ». ».

```
  after "Rejoindre": waiting for approval
┌──────────────────────────────┐
│ Demande envoyée              │
│ Secteur 49 · CS Villefranche │
│                              │
│   ⏳                          │
│ Un membre du secteur doit    │
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
  attente » for screen readers), « Demande envoyée », « Secteur 49 · CS Villefranche », the
  text and « Cet écran s'ouvrira tout seul sur le secteur dès que vous serez accepté. »,
  « Annuler la demande » at the bottom. Accepted: the secteur is opened and the start
  screen shows it. Refused: « Demande refusée » (a message over the next screen) and back to
  where the app would open now (§4: « Bienvenue », or the start screen when the phone has
  streets or a secteur open). Cancelled: withdrawn (offline too) and the same way back,
  without the message. Offline nothing comes and the request stays, across restarts. It is
  where the app opens only when the phone has nothing else (§4); while it has a start screen
  a back arrow leads there, so marking never waits for a request.
- Everywhere else the app shows **Secteur 49 · 2026** as the title and the CS as subtitle.

### 5.3 Accueil — map + "Mes rues" panel

> **Changed by 5.14 (2026-11-03):** built in #120: no « Mes rues » / « Autres rues », one list
> of every street under « Rues · 31/50 » (each row opens its street), no « libre » (line,
> legend), no « Équipe : n % », street card « Ouvrir » only. Built in #121: no « + Ajouter
> des rues » row (it moved to Secteur), 🗺 Secteur instead of 👥. Built in #123: the « En
> tournée » band in the top bar's place during a tournée. Built in #135: the title opens
> Secteur and carries the request dot; no 🗺 button; « Mes secteurs » is « Changer de
> secteur », the first row of Secteur. Read 5.14 first; the text below is the earlier state.

```
┌──────────────────────────────┐
│ Secteur 49 · 2026 ▾  [👥•][⚙]│  ← title opens « Mes secteurs »; dot: a join request is waiting
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

- **« Ajouter des rues » is a row, not a button** (decided 2026-11-02, #63; mockups Home,
  HomeAdmin, RunStart, RunHome; delivered in #107): a muted « + Ajouter des rues » row after
  the last street of the list (after « Autres rues du secteur »), instead of the red button
  pinned at the bottom of the panel: it is used a few times a year, and « Commencer une
  tournée » is now the panel's main action. It scrolls with the list (a long list hides it
  until scrolled or dragged up); the pending-sync line stays at the bottom of the panel, under
  the list.
- **No download banner** (decided 2026-11-01, #32): the secteur downloads itself for offline
  use, unseen, whenever the app is online (§7); Accueil shows nothing of it — no button, no
  banner, no progress, no word about map versions.
- **City zoom:** each street of the secteur drawn over the map, coloured by progress:
  fait (all done), en partie, à faire, libre (in the secteur but nobody took it).
- **Street zoom (≥ 16):** one dot per house at its BAN position, coloured and glyphed by status
  (`●` fait, `✗` personne, `↻` repasser, `○` à faire). Houses entered by hand have no position
  and appear only in the lists.
- Tapping one of the secteur's streets on the map opens its street card (see 5.4) with *Ouvrir*.
- The rows of « Mes rues » open the Street screen; a row under « Autres rues du secteur »
  opens that street's card over the map, as a tap on its line does (#93). Dragging the panel
  up shows the full list; down leaves only the handle and the totals.
- A "locate me" button centres the map on the phone's position (location permission asked
  the first time it is tapped, never at launch).
- Delivered in T3.4 (`ui/map/SectorMap`, used by 5.3 and 5.4): OpenFreeMap « liberty »;
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
  start screen while a secteur is open (`/`; with none, « Aucun secteur ouvert », 5.0). Under
  the top bar and its banner (« Administrateur · pas membre »), the map fills the screen. **Legend** top left, clear of « Me localiser »: line
  samples « faite · en partie · à faire · libre » (« libre » dashed, as wide as the others,
  without the map's white casing), or, once the map is at zoom ≥ 16, house
  dots « fait · personne · repasser · à faire »; a tap folds it into a « Légende » chip, a tap
  on the chip unfolds it (said « Masquer / Afficher la légende »). **Panel**: handle and
  totals « Mes rues · 31/50 » (doors done of the member's streets; « Rues · 9/38 » over every
  street for a visiting admin) and « Équipe : 43 % »; then the member's streets, « Vous n'avez
  pas encore de rue. » when they cover none, and **« AUTRES RUES DU SECTEUR (n) »** with the
  others (free or someone else's), so no street of the secteur is out of reach before anyone
  takes one; « Aucune rue dans le secteur pour l'instant. » with none. Then the « + Ajouter des rues »
  row and, at the bottom, the pending-sync line (#107). It rests on half the room; dragging the handle up shows the
  whole list, down only the totals (a quick flick goes one step, a slow release to the nearest
  height); a tap on the handle shows the whole list, or from there brings it back to rest.
  The map keeps « Me localiser », the attribution and its fit clear of the panel at rest.
  **A street tapped on the map** replaces the panel by its street card (5.4, since #31; it
  replaced HomeZoom's « Ouvrir Rue des Lilas · 31/42 »): name, commune, « 31/42 faits » and who
  covers it, « Ouvrir » and « Me l'attribuer » / « La faire aussi » / « Ne plus la faire »,
  offline; its ✕ (48 dp, top right, level with the handle, « Fermer »), a tap elsewhere on the
  map, or the back gesture, brings the list back. The street
  whose card shows has its line lit up (the dark casing and white core of 5.4).
  **A row under « Autres rues du secteur »** (#93) shows the same card, so a street can be
  taken without finding its line (or when it has none), and moves the map to the street: its
  line, else its houses' positions, plus 60 m; the map stays there once the card is closed. A
  street with no place on the map (typed in by hand) leaves the map where it is. The rows of
  « Mes rues » (every row for a visiting admin) still open the Street screen. The map opens
  on the secteur's streets, else its communes, and stays where the member puts it when the
  team adds a street. No download banner (decided in #32, checked in #33).
- **Lines filled in the background** (#92, `presentation/home/missing_shapes.dart`; the road from
  IGN BD TOPO by BAN id since §5.18): each
  time Accueil reads the streets, those without a line on the map but with a house on it
  (`Street.needsShape`: imported from a list, or added before their road came) get their
  road from the map's tiles, one street at a time, each **once per session** whatever the
  answer; a failure (offline, service down) stops the run and the next waits 2 minutes,
  when the street that failed is asked again. Nothing is shown meanwhile: the line appears
  when it is stored. Streets typed in by hand (no position) keep no line. Nothing on the
  marking path waits for it.

**Mes secteurs (« Changer de secteur » in Secteur).** Until #135 the title "Secteur 49 · 2026
▾" opened it; now the title opens Secteur (5.14), whose first row « ⇄ Changer de secteur › »
opens this bottom sheet over Secteur. With no secteur open, the app's name in the title still
opens it (5.0):

```
┌──────────────────────────────┐
│ (map, dimmed)                │
├──────────────────────────────┤
│ Mes secteurs                 │
│ ● Secteur 49 · 2026        ✓ │  ← current
│   CS Villefranche · 41 %     │
│ ○ Secteur 12 · 2026      •   │  ← dot: a join request waits there
│   CS Gleizé · 8 %            │
│ ◌ Secteur 7 · 2026           │
│   CS Anse · demande en attente│ ← my own request, not accepted yet
│ ○ Secteur 23 · 2026          │  ← greyed: offline, not downloaded here
│   CS Limas · Disponible avec réseau
│ ──────────────────────────── │
│ [ + Créer un secteur ]       │
│ [   Rejoindre un secteur ]   │
└──────────────────────────────┘
```

- Tapping another secteur switches at once: map, panel and listeners follow it; the app reopens
  on it next time, and downloads it by itself if it is not yet (§7). Offline, a secteur never
  downloaded on this phone cannot work, so the sheet greys it (below, #33).
- *Créer* and *Rejoindre* open 5.2; the current secteur stays untouched until the new one is
  ready (or accepted).
- Paramètres → *Mes secteurs* opens the same sheet.
- Delivered in #135: a secteur tapped from Secteur becomes the open one, the sheet closes and
  Secteur shows the secteur tapped (its title, code, members…); back goes to its Accueil.
  *Créer*, *Rejoindre* and *Tous les secteurs* open over Secteur, and their own way back
  leads there.
- Delivered in T2.7: the rows keep the order the phone met the secteurs (opening one does not
  move them); the open one shows ● and ✓, another ○ (a tap opens it and closes the sheet),
  a request a dashed ○ in grey, « CS … · votre demande est en attente », and cannot be tapped.
  No secteur: « Aucun secteur pour l'instant. ». Still to come: the progress « · 41 % » (with
  the streets on Firestore).
- Delivered in T4.2 (#33, Switcher mockup): **only while the phone is offline**, another
  secteur of the member that is not downloaded on this phone (no record in
  `SectorDownloads`, §6.3) is greyed (title, line and ring paler than the muted text),
  cannot be tapped, and its second line reads « CS Limas · Disponible avec réseau » instead
  of the centre alone (no « demande en attente » nor dot, no « administrateur », while it
  cannot open); screen readers hear « Secteur 23 · 2026, CS Limas, disponible avec réseau »,
  announced as a disabled button. Online, every row is as before. The open secteur is never
  greyed, and a pending request keeps its own look. « Offline » is whether the open
  secteur's street listener answers from the phone's copy (Firestore's `isFromCache`, port
  `ServerConnection`, the same listener as the pending-sync line, §7): no connectivity
  plugin. Until it first answers the rows show as online; with no secteur open nothing tells
  it, so the rows show as online too.
- Delivered in T2.6c: another secteur (not the open one) where join requests wait shows
  « CS … · 1 demande en attente » (« 2 demandes… ») and a red dot at the end of its row, said
  by screen readers (« Secteur 12 · 2026, CS Villefranche, 1 demande en attente, ouvrir »);
  its team is followed from the phone's copy first, offline too. The open secteur's requests
  stay on 👥 only (on Accueil's title since #135).
- **A secteur lost** (T2.6c): when the server says the member was removed (« Retirer ») or
  the secteur deleted, the phone forgets it at once (its row leaves « Mes secteurs »; when it
  was the open one, the app goes back to the start screen with none open, whatever screen
  was shown) and says so over the next screen, as « Demande refusée »: « Vous avez été retiré
  du secteur 49. » or « Le secteur 49 a été supprimé. ». Only the server's answer counts:
  offline, or for a secteur never read on this phone, nothing is forgotten; leaving and
  deleting from this phone are not told (the member did it).
- Delivered in T2.5: « + Créer un secteur » (red) and « Rejoindre un secteur » under the
  rows close the sheet and open 5.2 above the screen; a phone without a name asks « Votre
  prénom » (Paramètres' sheet) first and opens nothing if it is closed without one. With no
  secteur open, the app's name in the title opens the sheet too.
- From #75 (5.12): « + Créer un secteur » only for admins; admins also get « Tous les
  secteurs › » under « Rejoindre », and a visited secteur shows « CS … · administrateur ».
- Delivered in T2.6: 👥 sits left of ⚙ while a secteur is open (none otherwise) and opens
  Équipe; a red dot on it while a request waits in the open secteur, said by screen readers
  (« Équipe, 1 demande en attente »). The team is followed as long as a secteur is open.

### 5.4 Ajouter des rues — map mode

> **Changed by 5.14 (2026-11-03):** built in #120: « Ajouter et me l'attribuer » / « Ajouter
> sans m'attribuer » and the state table's attribution actions are gone. Built in #121: opened
> from Secteur, not Accueil; ✕ goes back to Secteur (« N rues ajoutées » too until #134, which
> stays on the screen). Built in #124: a tap
> ticks a road instead of opening the street card, several at once, and the selection sheet
> adds them (« Ajouter N rues »); the street card, its table and « ✎ Saisir une rue à la main »
> under the search box are gone from this screen (5.14). Built in #125: « Zone ». The
> look-up, the search and « Liste » stay as below; what this section says of the card is
> history.

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
│ le secteur                   │
│ [    Ajouter au secteur     ]│  ← one button since #120 (5.14)
│ Rue absente ? Saisir à la main│
└──────────────────────────────┘
```

The street card adapts to the street's state:

| State | Card content | Actions |
|---|---|---|
| Not in the secteur | name, commune, number count | *Ajouter au secteur* |
| In the secteur | name, commune, progress | *Ouvrir* |

(Until #120 the card also said who covered the street and offered *Me l'attribuer*, *La faire
aussi*, *Ne plus la faire*, *Ajouter et me l'attribuer* / *sans m'attribuer*: gone with 5.14.)

- Tapping a road calls the reverse geocoder at that point (type `street`) to get the BAN street;
  then BAN gives the numbers and their positions, and the map's tiles give the road's shape. All three
  are needed only once per street, when it is added: **this screen needs the network**.
  Offline, the map still shows and existing streets can still be opened, but adding says
  "Connexion nécessaire pour ajouter une rue" and offers manual entry.
- The search box finds a street by name (BAN search, limited to the secteur's communes) and
  centres the map on it.
- A road with no BAN match (private road, new estate): the card says so and offers manual entry.
- **Carte | Liste** (#78, Pick and AddList mockups): under the title (✕ closes), two 48 dp
  tabs, the chosen one in ink. **Carte** is the map above, opened on the secteur's communes
  (their centres, 2 km around each, `communesArea`), on its streets when no commune has a
  centre (`sectorArea`), on France when neither; works offline. **Liste** is the checklist of
  the import of streets on the secteur's communes: no commune field, a chip per commune
  when there are several (the first chosen at once), « déjà dans le secteur » on a street the
  secteur has, « Ajouter N rues », « Ajout en cours… n/N », then back with « N rues ajoutées au
  secteur ». A secteur without commune (created before #78) searches its commune in a field
  (geo.api.gouv.fr as you type, from two characters, after a 300 ms pause, « name
  (postcode) »). A street in the Corbeille reads « dans la Corbeille » and comes back with
  its marks, without the network (« N rues restaurées »); some failed → the tab stays, says
  why and keeps them ticked. Delivered in #78: the tabs, the map opened on the communes and
  the list.
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
  not be found, Accueil fills it later (5.3). **A tap on a secteur
  street's line or dot** shows its card at once, offline, with its own road. The card (white
  sheet, handle, name in 28 dp titles over the commune, facts in grey chips, red then outline
  button): to add « 19 numéros · Pas encore dans le secteur », « Ajouter et me l'attribuer »,
  « Ajouter sans m'attribuer » (« Ajout en cours… » meanwhile), « Rue absente de la carte ?
  Saisir à la main »; once added it becomes the street's card. A secteur street « 31/42
  faits » and « Libre » / « Vous la faites (avec Manu) » / « Faite par Manu et Julie »
  (teammates named in the team's order; « Faite par un autre membre » when none can be
  named, the team not read yet), with the actions of the table; take and release need no network and have no
  « Annuler » (the other button undoes it). Failures: « Connexion nécessaire pour ajouter une
  rue » (offline), « Aucune rue connue ici » (no BAN match), « Impossible d'ajouter des
  rues pour l'instant. Réessayez plus tard. » (the service refused or failed while the phone
  has a connection, #137), each with a hint and « Saisir une rue à la main ». The card's own ✕ (48 dp,
  top right, level with the handle, « Fermer »; the name keeps clear of it) closes it, and so
  does the back gesture, first; the top bar's ✕ closes the screen. **The search** lists « name / commune » rows over the map
  (« Aucune rue trouvée. », « Connexion nécessaire pour chercher une rue. », « Impossible de
  chercher une rue pour l'instant. Réessayez plus tard. »); it searches the
  secteur's communes, or the communes of its streets for a secteur without commune; picking a
  row moves the map 200 m around the street and shows its card. A newer tap or search always
  wins over a late answer.

### 5.5 Keeping streets true to reality: manual street, edit mode

Three entry points, all of which work offline:

| To… | From |
|---|---|
| Add a street missing from the map | *Ajouter des rues* → « Rue absente de la carte ? Saisir à la main » (always at the bottom of the selection sheet, 5.14), or « Saisir à la main » on a look-up failure |
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
- ~~*Ne plus la faire* removes me from its assignees~~ (removed, 5.14); *Supprimer* deletes it for everyone
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
  street has numbers on one side only (decided as on the street screen); a building shows the
  building icon before its number, as on the street screen (« 8 · immeuble » until 2026-11-13,
  which the ✏ would cut). Each number is followed by a small grey ✏ (`Icons.edit_outlined`, 20 dp):
  number and ✏ are one button opening the number sheet, ✕ stays apart; the ✏ is only visual,
  TalkBack still says « Modifier le numéro 3 » (from the phone test of 2026-11-13: the tap on a
  number was hard to find; #165). « + numéros » closes each column (both open the same sheet); under
  them « Touchez ✏ pour renommer un numéro ou le transformer en immeuble. ».
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
  Accueil, where the street no longer shows. « Supprimer la rue » takes the whole width
  (« Ne plus la faire » went with 5.14).
- Not yet: the Corbeille screen (§5.11) comes in M2.

« Rue à la main » delivered in #31 (Manual mockup, `/ajouter-des-rues/a-la-main`,
`presentation/manual_street/`): « ← Rue à la main »; « Nom de la rue » (« Nom limité à 150
caractères. »; a blank name only disables the button); « Commune », a list of the secteur's
communes (else those of its streets), the first chosen; a secteur with neither searches its
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

**Status picker** (decided 2026-11-02 with #63, mockups Main, House, HouseNobody,
HouseComeBack, RunStreet, Building; delivered in #107 with four statuses, « Refusé » is #113,
the calendars #114, the don step #109 — it replaces the tap cycle, the hold and the sheet
that ↻ opened by itself, described further down as delivered in M1–M3, and no longer true
where they disagree with this block):

```
  before (tap cycles)                after (tap shows the statuses)
  ──────────────────────────────    ──────────────────────────────
  │ ← Rue des Lilas        [✏] │    │ ← Rue des Lilas        [✏] │
  │   31/42 · ✗3 · ↻1          │    │   31/42 · ⊘ 2 · ✗ 3 · ↻ 1  │
  │ [ 1   ○ ] │ [ 2   ✓ ]      │    │ [ 1   ○ ] │ [ 2   ✓ ]      │
  │ [ 5   ↻ ] │ [ 6   ○ ]      │    │ [ 5   ↻ ] │ [ 6   ○ ]      │
  │ [ 7   ○ ] │ [▦ 8 ◐7/12 ›]  │    │ [▶7   ○ ]◀│ [▦ 8 ◐7/12 ›]  │  ← tapped: outlined
  │ [ 9   ✓ ] │ [10   ○ ]      │    │ [ 9   ✓ ]②│ [10   ○ ]      │  ← ② 2 calendars
  ├────────────────────────────┤    ├────────────────────────────┤
  │ 7 → Personne   [Annuler]   │    │ N° 7  À faire            ✕ │
  └────────────────────────────┘    │ [ ✓ Fait   ][ ⊘ Refusé   ] │
                                    │ [ ✗ Personne][ ↻ Repasser ]│
                                    │ [ ○ À faire              ] │
                                    │ Modifié par Léa · 14:02    │
                                    └────────────────────────────┘
  then, only when needed:
  ✓ during a tournée (§5.13)         ↻ Repasser                         a ✓ house during a tournée
  ┌────────────────────────────┐    ┌────────────────────────────┐    ┌────────────────────────────┐
  │ Montant du don           ✕ │    │ N° 5 · quand repasser ?  ✕ │    │ N° 9  Fait               ✕ │
  │ (Espèces)(Chèque)(Carte)   │    │ (Aujourd'hui)(Demain)(Sam.)→│    │ [ ✓ Fait ][ ⊘ Refusé ] …   │
  │ [5 €]  [10 €]  [20 €]      │    │ Heure [ Vers 18 h      ▾ ] │    │ 2 calendriers          [−] │
  │ [Autre montant]            │    │ Le samedi 24 oct. vers 18 h│    │ [ + Ajouter un don       ] │
  │ [Calendrier offert]        │    │ [         Valider        ] │    └────────────────────────────┘
  └────────────────────────────┘    └────────────────────────────┘
```

- **Tap a house tile**: a light haptic tick, the tile gets a thick ink outline, and a sheet
  shows « N° 7 » and, in grey, its status (« À faire », « Fait »…), five 72 dp buttons in the
  status colours with their glyph — « ✓ Fait », « ⊘ Refusé », « ✗ Personne », « ↻ Repasser »
  two by two, « ○ À faire » across the last row — the current one ringed (a radio group
  « Statut »), then « Modifié par Léa · 14:02 » (§5.7, #89). ✕, a swipe down, a tap on the
  street or back closes it with nothing stored.
- **One tap on a status stores it** (stamped, offline) and closes the sheet, except:
  - **✓ while a tournée is on** (§5.13): the sheet becomes « Montant du don » — « Espèces |
    Chèque | Carte » (Espèces each time), « 5 € », « 10 € », « 20 € », « Autre montant » (title
    « Autre montant », field « Montant », hint « Par exemple 7,50 », « Valider », on the method
    already chosen) and « Calendrier offert ». A ✓ means a calendar was handed over, so it is
    paid or offered: the ✕ of this step puts the house back as it was (status, time, tries).
    The don goes to the tournée's totals only, never to the house.
  - **↻**: the sheet becomes « N° 5 · quand repasser ? » — the day chips, « Heure » (« Pas
    d'heure », « Vers 8 h » … « Vers 21 h »), the summary line of §5.7 (#81), « Valider »; each
    choice is stored at once.
  - The status the house already has: nothing is stored (no stamp), the sheet closes; ↻ still
    opens its day.
- **⊘ Refusé** (new status, `VisitStatus.refused`): the resident did not want a calendar. A
  dark grey tile (`#5A6068`, white text) with ⊘, a ⊘ dot on the map; it counts as **visited**:
  the street's « 31/42 » and the map's levels count ✓ and ⊘ together, so a street with
  refusals can be « faite »; the header adds « ⊘ 2 ». No tries (⊘ resets them, as ○) and no
  come-back. Contrast held by the theme test; told apart by its glyph and lightness.
  Delivered in #113: the dark palette keeps the tile, with a `#8A8F96` border; a building
  whose doors are all visited (✓ or ⊘) is ✓ on its tile and ● on the map, its `◐ n/m` and
  the grid's « 7/12 » count ⊘ too, and turned back into a house it is ⊘ when every door was,
  else ✓; « Masquer faits » hides ⊘ tiles with the ✓ ones; Accueil's « 43/62 » and « Équipe :
  41 % » count ⊘ with ✓; the map legend adds « refusé »; TalkBack hears the header as « 31 sur
  42 faits, 2 refusés, 3 personne, 1 à repasser », and the counts wrap to a second line
  rather than being cut at large text sizes.
- **Tries with nobody home** (#80): on a house ✗ or ↻ with a try or more, « ✗ Personne » reads
  « ✗ De nouveau personne » (two lines in a 174 dp button) and adds one try (it replaces
  « Repassé, toujours personne »); the sheet shows « ✗ 2 passages sans personne » on the pale
  yellow of §5.7 when a try is counted and the status is neither ○ nor ⊘. ○ and ⊘ reset the
  count; ✗ from ○ or ✓ makes it at least 1; ✓ and ↻ keep it. Tiles keep « ×N » from 2 tries.
- **Calendars per house** (`House.calendars`, a count, no amount): a ✓ starts at 1. On a ✓
  house the sheet shows « 1 calendrier » / « 2 calendriers » with « − » (« Un calendrier de
  moins », disabled at 1), always, so a mistake is fixed after the tournée too. While a
  tournée is on, it also shows **« + Ajouter un don »**: the « Montant du don » step again, for
  a second calendar, 5 seconds or 5 days later (its ✕ only closes); the don goes to the
  tournée on now and the house gets one more calendar. Leaving ✓ sets the count to 0. From 2,
  the tile carries a 24 dp round ink badge with the number at its top right (TalkBack:
  « Numéro 9, fait, 2 calendriers »). Doors the same. Delivered in #114: the row « 2 calendriers
  [−] » sits on the ground colour under the statuses, before « + Ajouter un don »; « − » keeps
  the sheet open and shows no snackbar; the badge's centre is 7 dp out of the tile's corner,
  ringed in the ground colour, the street list and the door grid starting 7 dp lower (and the
  grid 7 dp narrower) so no badge is cut; TalkBack puts the calendars after the tries
  (« Numéro 9, fait, 2 passages sans personne, 2 calendriers, changer le statut »); the
  « Annuler » of « + Ajouter un don » takes the don and the calendar back.
- **After the sheet closes**, the snackbar of 4 s says what was stored: « N° 7 : personne »,
  « N° 3bis : personne (3e passage) », « N° 9 : refusé », « N° 7 fait · 10 € en espèces »,
  « N° 7 fait · calendrier offert », « N° 9 · 5 € en chèque ajouté », each with « Annuler »,
  which puts the house back as it was (status, time, tries, calendars) **and takes the don
  back out of the tournée**. Closing with nothing stored shows nothing.
- **No hold any more.** « Transformer en immeuble… » lives in edit mode only (✏, a tap on the
  number, §5.5, already there). A building's own « Repasser » stays under its grid.
- **Doors** (Immeuble grid, §5.7): a tap on a door shows the same statuses titled « Porte 51 ·
  Fait », « Esc. A · 5e · 8 Rue des Lilas » (staircase only when several), with the same
  follow-ups and snackbar.
- The hint under the tiles reads « Appuyez sur une maison pour changer son statut » (« … une
  porte … » in the grid), during a tournée only (5.14, #122): with none on, a tap on a house
  or a door opens no picker. TalkBack: « Numéro 7, à faire, changer le statut »; after a choice
  « Numéro 7, personne, 3e passage » as before.
- Delivered in #107 (`ui/screens/street/status_picker_sheet.dart`, the steps in
  `presentation/house_sheet/picker_step.dart`), with « Refusé » since #113: the five
  statuses sit « ✓ Fait | ⊘ Refusé », « ✗ Personne | ↻ Repasser », « ○ À faire » (a status
  alone on the last row takes the whole width); a row grows whole when « De nouveau personne » takes two
  lines. The tile (or door) has a 3 dp ink outline inside its edge while its picker shows, and
  screen readers hear it « sélectionné ». The tries block shows once a try is counted; the
  last-change line only once the house was changed. The ↻ step is titled « N° 5 · quand
  repasser ? » (« Porte 51 · … » on a door), without the « Quand repasser ? » label; ✕, a
  swipe or a tap on the street close it like « Valider », the ↻ kept, and the snackbar « N° 5 :
  repasser » follows, whose « Annuler » puts the house back as before the ↻ (time and tries
  included). ↻ on a house already ↻ stores nothing and shows no snackbar. A finger held on a
  tile opens the picker when it lifts, like a tap. Door snackbars read « Porte 51 : fait ».
  The building's own « Repasser » sheet, under the grid, is unchanged.

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
  « repasser » plus the buildings with their own « repasser » (`Progress.toComeBack`); when
  the phone's font leaves no room for them beside « Masquer faits », they take their own line
  above it, whole (#35). « Masquer faits » hides the
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

*From the status picker (§5.6, decided 2026-11-02, delivered in #107): there is no hold and no Fiche
maison any more. Its parts move: the status control (five statuses) and the tries to the
picker, « Quand repasser ? » to the picker's ↻ step (« OK » becomes « Valider »), « Modifié
par » to the picker, « Transformer en immeuble… » to edit mode only. The door sheet becomes the picker on a door. The rules below
(stamping, day and hour, tries, last change) stay true; only where they show changes.*

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
│ (Aujourd'hui)(Demain)(📅)    │    │                              │
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
- **Day and hour** (#81, replacing the free hint of ≤ 20 characters; mockup HouseComeBack;
  day row changed 2026-11-13 from the user's phone test of #82): the block holds « Quand
  repasser ? », a row of **two day chips**, « Aujourd'hui » and « Demain » (from today on the
  phone's calendar and clock, `Clock` port), then a round **📅 button** (`Icons.calendar_today`,
  « Autre jour ») — 40 dp pills in a 48 dp tap target, the chosen one filled in the come-back
  blue; screen readers hear a radio group « Jour ». 📅 opens Android's date picker in French,
  from today to 60 days ahead, on the chosen day when it is in that range, else on the day
  after tomorrow; « OK » stores that day (today or tomorrow picked there select their chip),
  « Annuler » changes nothing. 📅 is filled blue whenever the day is neither today nor tomorrow
  (picked there, past, or set by a teammate), said « Autre jour, dimanche 15 novembre »; a tap
  on it opens the picker again. Then « Heure » and a list « Pas d'heure », « 8 h » … « 21 h »,
  greyed until a day is chosen. Then a summary line: « Pas de jour choisi », « Aujourd'hui »,
  « Demain vers 18 h », « Le samedi 24 oct. vers 18 h ». A day already gone shows as past:
  « C'était hier vers 18 h », « C'était le mercredi 14 oct. ».
  Each choice is stored at once (one `ComeBackSet` each, stamped); a new day keeps the hour
  chosen; tapping the chosen chip again leaves no time at all (the hour with it): « ↻ » without
  time stays valid. A building's own « Repasser » (ticked) shows the same block.
- **Last change**: « Modifié par Léa · 14:02 » today, « Modifié par Léa · 3 oct. à 14:02 »
  before, in the phone's time zone; « par vous » for the member on the phone; nothing when the
  house was never changed. The name is read from the open secteur's team (offline from the
  phone's copy); when the phone cannot name anyone (no secteur open, a member no longer in the
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
- **Under the grid** (T1.18): « Gérer l'immeuble ▾ » next to « Repasser » (48 dp each; T1.20);
  one above the other, full width, when a large phone font no longer lets each label hold
  on one line in half the width (#35).
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

### 5.8 Équipe (👥), now Secteur (🗺)

> **Changed by 5.14 (2026-11-03):** built in #120: no streets per member (#105's counts are
> gone). Built in #121: now « Secteur », opened by 🗺 (`Icons.map_outlined`); after
> « MEMBRES », a « RUES (n) » section with « + Ajouter des rues » and the Corbeille under it
> (not for a pending member), then « COMMUNES » and « COLLECTE ». Built in #135: opened by
> Accueil's title (no 🗺 button), with « ⇄ Changer de secteur › » as its first row. The rest
> stands.

```
┌──────────────────────────────┐
│ ← Secteur 49                 │
│   CS Villefranche · 2026     │
│ ⇄ Changer de secteur       › │  ← « Mes secteurs » (5.3), #135
│  ▄▄▄▄ ▄ ▄▄▄▄ Code K7P-2QX [⧉]│  ← ⧉ copies the code
│  █▄▄█ ▀ █▄▄█ [Partager]      │
│              [Nouveau code]  │  ← admins only (#75)
│ EN ATTENTE (1)               │  ← only when requests exist
│ Julie · il y a 2 min         │
│ [ Accepter ]  [ Refuser ]    │  ← any accepted member, any admin
│ MEMBRES (5)                  │
│ Manu (vous) · admin  5 rues ▸│  ← tap the count: unfold
│ Léa               3 rues ▾ [⋮]│  ← admins only: retirer
│     Rue de Thizy             │  ← her streets, unfolded
│     Rue Nationale            │
│     Place des Marais         │
│ Paul · admin      0 rue    [⋮]│
│ Corbeille · 2 éléments     › │  ← 5.11
├──────────────────────────────┤  ← all above scrolls (#105)
│ [ Démarrer une nouvelle campagne ] │  ← admins only, v1.1 (5.10)
│ [  Quitter le secteur  ]     │  ← every member, pinned
│ [  Supprimer le secteur ]    │  ← admins only, pinned
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
- Delivered in T2.6 (Team mockup): title « Secteur 49 » over « CS Villefranche · campagne
  2026 »; the code card (QR, « Code K7P-2QX » and its copy button ⧉ — puts the code as shown,
  `K7P-2QX`, on the clipboard and says « Code copié », TalkBack « Copier le code », 48 dp,
  offline too —, « Partager » — the phone's share sheet with « Secteur 49 · CS Villefranche »
  and the code —, « Nouveau code » for the creator, at once,
  no confirmation); « EN ATTENTE (n) » only with requests: name, « a demandé à rejoindre · il
  y a 2 min », « Accepter » (green) and « Refuser », no confirmation; « MEMBRES (n) »: every
  active member, one row each, oldest first (the creator first), « (vous) » and « · créateur »;
  ⋮ → « Retirer » on the others for the creator, asking « Retirer Léa ? » first; « Corbeille · n
  éléments › » (« · vide »). At the bottom one button: « Supprimer le secteur » for the creator
  (asks « Supprimer le secteur 49 ? »), « Quitter le secteur » for the others (asks too, since
  coming back needs the code and an approval); both then forget the secteur on the phone and go
  back to the start screen with none open. Answering, removing and leaving work offline; a
  new code and deleting need the network (« Pas de réseau. Réessayez une fois connecté. »). A
  command a teammate made pointless meanwhile says « L'équipe a changé entre-temps. ». A
  secteur that cannot be read (removed, deleted, or never read on this phone offline) shows
  « L'équipe ne peut pas être affichée : … ». Times: « à l'instant », « il y a 2 min », « il
  y a 3 h », « hier », then the day (« 3 oct. »). Still to come: « CAMPAGNE » / « Démarrer
  une nouvelle campagne » (v1.1).
- **Streets per member** (#105, Team mockup): each member row shows, right-aligned and muted,
  the number of streets of the secteur that member holds (« 0 rue », « 1 rue », « 5 rues »)
  followed by ▸. Tapping the count (48 dp; TalkBack « Léa, 3 rues, afficher les rues » /
  « masquer les rues ») unfolds the street names under the row, one per line, indented under
  the name, ▾ while open; tapping again folds them. Every row starts folded; several can be
  open at once. A member with no street shows « 0 rue » with nothing to unfold. Read from the
  phone's copy, so it works offline.
- **Pinned bottom buttons** (#105): « Quitter le secteur » / « Supprimer le secteur » (and
  later « Démarrer une nouvelle campagne ») sit in a footer fixed at the bottom, over a thin
  divider; everything between the title and that footer (code card, requests, members and their
  unfolded streets, Corbeille, communes) scrolls as one list.
- **Communes** (#78): after the Corbeille, « COMMUNES (n) », a row per commune of the secteur
  with ✕ (« Retirer Gleizé » for screen readers), never on the last one, then « + Ajouter une
  commune », which opens a sheet with the field of « Nouveau secteur » (5.2); a commune picked
  is added and the sheet closes. A secteur created before the communes shows only the button.
  Any active member or admin may change them, offline too (sent later); a pending member sees
  them without ✕ or button. « Cette commune est déjà dans le secteur. », « Un secteur a au
  plus 50 communes. », or « L'équipe a changé entre-temps. » when a teammate removed one
  meanwhile. Removing a commune keeps the streets added from it.
- From T2.6c a member removed, or a secteur deleted, is forgotten by the phone as soon as the
  server says so, with a message (« Vous avez été retiré du secteur 49. », 5.3), which
  closes Équipe; « L'équipe ne peut pas être affichée » stays for a secteur never read
  offline.
- **Changer de secteur** (#135, Team mockup): the first row of Secteur, above the code card,
  in the look of « + Ajouter des rues » (⇄ in a round badge, « Changer de secteur », ›; 56 dp,
  said « Changer de secteur »), for everyone, pending members and visiting admins included.
  It opens « Mes secteurs » (5.3) over Secteur; a secteur picked there is then the one
  Secteur shows. It also shows alone while the secteur is being read, and above « L'équipe ne
  peut pas être affichée », since Accueil's title now only leads here.

### 5.9 Paramètres (⚙)

```
┌──────────────────────────────┐
│ ← Paramètres                 │
│ VOUS                         │
│ Prénom        Manu         › │
│ Mes secteurs  49 · 2026    › │  ← same sheet as the title
│ L'application fonctionne sans│  ← muted line, no button
│ réseau ; les modifications … │
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
│   le secteur.                │
│ 1.0.0  16 oct. 2026          │
│ • Première version.          │
└──────────────────────────────┘
```

- **Prénom** opens a sheet « Votre prénom » + « Enregistrer » (the keyboard's « OK » too):
  `MemberName` rules; blank → « Écrivez votre prénom. », too long → « Prénom limité à 30
  caractères. », the sheet stays. Kept on the phone, then written to the member's own
  document in every secteur of « Mes secteurs » they are active in, so Équipe shows the new
  name to the team (T2.7b). Works offline (sent when the network is back); a pending request
  (which cannot rename itself, 8.2) and a secteur the phone cannot read offline are skipped,
  then caught up (T2.7c): whenever the server shows the member active in one of their
  secteurs under another name than the phone's, the phone sends its own.
- **Mes secteurs** shows the open one (« 49 · 2026 ») and opens the sheet of 5.3.
- **Thème** opens « Système | Clair | Sombre »: a tap redraws the app at once and closes the
  sheet. « Sombre » uses the dark palette reviewed in T5.1 (contrast rules in 5, intro).
- **Confidentialité** opens a page saying 8.3 in French: compte, données enregistrées,
  position, hébergement, suppression. Its five texts are those sections of `PRIVACY.md`, word
  for word (#79; a test compares them). Under a divider, a last row « Politique complète en
  ligne ↗ » opens the public policy, `PRIVACY.md` at the root of the repository (same text,
  #36), in the browser (decided 2026-11-02). When no browser opens, a snackbar gives the
  address: « Impossible d'ouvrir le navigateur. La politique est à l'adresse … ». The text
  works offline; only the link needs the network.
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
  Tracé des rues{N}: IGN (BD TOPO). Adresses{N}: Base Adresse Nationale. » (IGN since §5.18)
- **No HORS-LIGNE section**, no « Mettre à jour » or « Supprimer » (decided 2026-11-01, #32):
  the app downloads, updates and deletes the offline copy by itself (§7). Delivered in T4.2
  (#33, Settings mockup): one muted line right under « Mes secteurs », before APPLICATION:
  « L'application fonctionne sans réseau ; les modifications sont envoyées dès qu'il
  revient. » Neither the date nor the size kept per secteur (§6.3) is shown.

### 5.10 Nouvelle campagne (v1.1)

```
  creator (from Équipe)               every member, after the switch
┌──────────────────────────────┐    ┌──────────────────────────────┐
│ ← Nouvelle campagne          │    │ Secteur 49 · 2027     [👥][⚙]│
│ Secteur 49 · CS Villefranche │    │ ┌──────────────────────────┐ │
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

- Copied: streets (with shapes and edits), numbers, buildings and their floors. Reset: statuses, *repasser*, last-change info.
- ~~*Reprendre mes rues 2026* re-takes in one tap the streets the member covered last year~~
  (no attribution since 5.14: nothing to re-take; the sketch above still shows it).
- The house sheet and door sheet show last year's result in small type: *En 2026 : ✗ personne*.
  It helps ("nobody home last year either, try the evening") and is read-only.
- The previous campaign stays readable from Paramètres → Secteur → *Campagne 2026*. The one
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
  each time a secteur is opened, on the streets of the open secteur (none while none is
  open): each street deleted more than 30 days ago goes for good, and each number
  removed more than 30 days ago (counted from its own removal, the street deleted or not).
  At 30 days exactly it is still kept. Offline, the phone's copy changes at once and the
  deletes are sent later; the server refuses any that is not past 30 days by its own clock
  (a teammate restored it meanwhile), and the item comes back.

### 5.12 Administrateurs (#75)

```
  Tous les secteurs (admin)        Accueil, admin not a member
┌──────────────────────────────┐    ┌──────────────────────────────┐
│ ← Tous les secteurs          │    │ Secteur 12 · 2026    [👥][⚙]│
│   Administrateur · 4 secteurs│    │ CS Gleizé                    │
│ CS VILLEFRANCHE              │    │ ┌──────────────────────────┐ │
│ Secteur 49 · 2026          › │    │ │🛡 Administrateur · pas    │ │
│   5 membres · vous en êtes … │    │ │  membre       [Rejoindre]│ │
│ CS GLEIZÉ                    │    │ └──────────────────────────┘ │
│ Secteur 12 · 2026        • › │    │ (map)                        │
│   3 membres · 1 demande …    │    ├──────────────────────────────┤
│ CS ANSE                      │    │ Rues · 9/38                  │
│ Secteur 7 · 2025           › │    │ Rue de la Gare        9/30   │
│   Aucun membre               │    │ [   + Ajouter des rues   ]   │
└──────────────────────────────┘    └──────────────────────────────┘
```

Decided with the user (2026-10-12 and 2026-10-16, issue #75; mockups AllTournees, HomeAdmin,
TeamMember, and Welcome, Switcher, Team, Settings updated):

- **Who is an admin.** An `admins/{uid}` document (no fields) added by hand in the Firebase
  console; the rules check it, the app follows it (`AdminStatus`, cached by Firestore, so it is
  known offline once read). Admins are **global**: an admin manages, joins and reads / adds /
  removes streets in **every** secteur, member or not. Granting and revoking from the app: out
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
- **Non-admins** never see « Créer un secteur » (Bienvenue, « Mes secteurs »), with no hint
  in its place; only « Rejoindre un secteur ». Adding a centre de secours happens only in
  « Nouveau secteur », so it is admin-only too.
- **Équipe** (5.8): « Nouveau code », ⋮ → « Retirer » and « Supprimer le secteur » for admins
  only (member or not); the creator has no power of their own any more. Admins remove any
  other active member, admins included. Accepter / Refuser: any active member and any admin.
  « Quitter le secteur »: every member, admins included, even the last one (no guard: an empty
  secteur stays and admins manage it from « Tous les secteurs »). A member row shows « ·
  admin » for an admin (any signed-in user may `get` `admins/{uid}`); « · créateur » is gone.
  Existing secteurs are kept as they are.
- **« Tous les secteurs »** (admins only): « Tous les secteurs › » under Créer and
  Rejoindre in the « Mes secteurs » sheet. Every secteur of the app, grouped under its centre
  (« CS GLEIZÉ », centres by name, secteurs by number then campaign), each row « Secteur 12 ·
  2026 » over « 3 membres » (« 1 membre », « Aucun membre » in red), « · vous en êtes membre »
  when the admin is an active member, « · 1 demande en attente » with a red dot (said by
  TalkBack); « Administrateur · n secteurs » under the title. It needs the network: « Pas de
  réseau : la liste ne peut pas être affichée. » with « Réessayer ». A tap opens the secteur.
- **Opening a secteur as an admin** who is not a member: it is remembered in « Mes secteurs »
  as **visited** (a third `MemberStatus`, `visiting`: row « CS Gleizé · administrateur », a
  shield instead of the ring) and opened on the normal screens: map, streets panel (« Rues ·
  9/38 » instead of « Mes rues »), streets, houses, marks, Corbeille and Équipe, all as a
  member, plus the admin's powers; houses are marked only during a tournée, which a visitor
  never runs (5.14, #122). A banner under the title on Accueil: shield, « Administrateur
  · pas membre » over « Vous n'êtes pas dans l'équipe de ce secteur. » and « Rejoindre »
  (come-back blue, `#D6E6F5` / `#1D4E7A`). A visitor is not listed in MEMBRES. Their marks are
  stamped with their uid; where a name is shown for a uid that is not a member: « un
  administrateur ».
  - **« Rejoindre »** makes the admin an active member at once (their own document, `active`,
    accepted by themself, no code, no approval); the banner goes and the row becomes a normal
    one. Offline: « Pas de réseau. Réessayez une fois connecté. ».
  - At the bottom of Équipe a visitor has « Retirer de Mes secteurs » (forgets it on the
    phone, writes nothing) instead of « Quitter », and « Supprimer le secteur ».
  - A visited secteur deleted, or the phone no longer an admin, is forgotten as in 5.3 « A
    secteur lost », with « Le secteur 12 a été supprimé. » or « Vous n'êtes plus
    administrateur : le secteur 12 est retiré de Mes secteurs. ».
- **A revoked admin** (#87): the phone may still believe it is an admin's for a moment after
  `admins/{uid}` is removed (« Créer » or « Nouveau code » still on screen). The server refuses
  the admin's command and the screen says « Vous n'êtes plus administrateur. » where it says
  « Pas de réseau » for the same command: under « Créer » in « Nouveau secteur » (« Créer »
  then stays off), in place of the list in « Tous les secteurs » (no « Réessayer »), in the
  snackbar of Équipe (« Nouveau code », « Retirer », « Supprimer le secteur ») and of the banner
  (« Rejoindre »). The same message when the phone already knows it (the secteur refuses the
  command itself). « Retirer », « Accepter » and « Refuser » are sent in the background (they
  work offline): a refusal by the server only takes the change back on the screen, as for any
  queued write (PLAN §7). The listeners of a visited secteur that may no longer be read never
  show an error: Équipe reads « unavailable », the streets show none, and the revocation is told
  by the `admins/{uid}` listener as above.
- Delivered in #75 (`lib/presentation/admin/`, `all_sectors/`, `account/device_id_state.dart`,
  `lib/ui/screens/all_sectors/`, `start/admin_visit_banner.dart`):
  - « Tous les secteurs » is read once each time it opens (and on « Réessayer »), not
    followed live. Centres are ordered by their station key (the name without « CS » / « CIS »,
    French order), so « CS Villefranche » comes before « CIS Villefranche Est »; a centre is
    named as its first secteur names it. A tap opens the secteur and goes back to Accueil.
    « Tous les secteurs › » goes through « Votre prénom » first when the phone has no
    name, like « Créer » and « Rejoindre » (joining as an admin needs one); so does
    « Rejoindre » of the banner. Under the list, the mockup's line « Ouvrez un secteur pour
    le gérer… »; « Aucun secteur pour l'instant. » when there is none.
  - The banner sits at the top of the start screen (the map comes in M3); its header reads
    « Rues · 38 » instead of « Mes rues · 38 ». In « Mes secteurs » a visited secteur has a
    shield (green when open, grey otherwise) and ✓ when open.
  - Équipe: an admin's bottom row holds « Quitter le secteur » (or « Retirer de Mes
    secteurs » for a visitor, no confirmation: nothing is written) and « Supprimer le
    secteur » side by side; a non-admin has « Quitter » alone (« Retirer de Mes secteurs »
    alone for a visitor no longer an admin). The dark avatar marks « (vous) » (both
    mockups), no longer the creator. An admin may « Retirer » any other member.
  - Corbeille: someone not in the team is « un administrateur » when `admins/{uid}` says so
    (asked once per uid while the Corbeille shows), « un membre » otherwise.
  - Paramètres: « Connexion au serveur… » while the screen signs in. Bienvenue keeps the
    room of its line while it signs in, so the buttons do not move.
  - Not done: the instrumented suite has no admin flow (it would need a real `admins/{uid}`
    document for the emulator's uid); widget tests cover the flows.

### 5.13 Tournées et collecte (#63)

> **Changed by 5.14 (2026-11-03):** houses are marked only during a tournée (built in #122);
> the tournée card in Accueil's list and the street's line became the « En tournée » band on
> top (built in #123); the sketches below still show « Mes rues », 👥 and the card.

Agreed 2026-11-02 (ASCII, then mockups RunStart, RunHome, RunStreet, RunDons, RunDon,
RunRecap, RunTeam, Cash; every text reviewed one by one with the user). « Tournée » is one
outing; the team's area is the **secteur** (§2).

```
  Accueil, no tournée               Accueil, tournée on               Dons de la tournée
┌────────────────────────────┐    ┌────────────────────────────┐    ┌────────────────────────────┐
│ Secteur 49 · 2026 ▾ [👥][⚙]│    │ Secteur 49 · 2026 ▾ [👥][⚙]│    │ ← Dons de la tournée       │
│ Mes rues · 31/50 Équipe 43%│    │ Mes rues · 31/50 Équipe 43%│    │   19 dons · 280 €          │
│ [ ▶ Commencer une tournée ]│    │ ● En tournée depuis 1 h 20 │    │ 10 € · Espèces           › │
│ Rue des Lilas ▓▓▓░ 31/42 › │    │   19 dons · 280 € Voir les dons ›│ Calendrier offert        › │
│ + Ajouter des rues         │    │ [        ■ Terminer       ]│    │ 20 € · Chèque            › │
└────────────────────────────┘    │ Rue des Lilas ▓▓▓░ 31/42 › │    │ [    Ajouter un don    ]   │
                                  └────────────────────────────┘    └────────────────────────────┘
  Bilan de la tournée               Équipe                            Collecte 2026
┌────────────────────────────┐    ┌────────────────────────────┐    ┌────────────────────────────┐
│ ← Bilan de la tournée      │    │ MEMBRES (5)                │    │ ← Collecte 2026            │
│ Samedi 24 octobre, de 14 h │    │ Manu (vous) · admin 5 rues▸│    │   Secteur 49 · tournées validées
│ 05 à 18 h 20               │    │ Léa              12 rues ▸ │    │ TOTAL DES 4 TOURNÉES       │
│ [23 maisons][19 dons][2 cal.]│  │ Corbeille · 2 éléments   › │    │ Espèces  32 dons   440 €   │
│ ARGENT RÉCOLTÉ             │    │ COLLECTE 2026              │    │ Chèques   7 dons   140 €   │
│ Espèces   15 dons   210 €  │    │ € 600 € récoltés         › │    │ Carte b.  2 dons    20 €   │
│ Chèques    3 dons    60 €  │    │   41 dons en 4 tournées    │    │ Calendriers offerts   3    │
│ Carte b.   1 don     10 €  │    └────────────────────────────┘    │ Total    41 dons   600 €   │
│ Total     19 dons   280 €  │                                      │ TOURNÉES                   │
│ Voir les dons            › │                                      │ Samedi 24 oct. · 14:05 →   │
│ [  Valider la tournée  ]   │                                      │ 18:20 · 23 maisons, 19 dons│
│ [ Continuer la tournée ]   │                                      │                    280 € ▾ │
│    Abandonner la tournée   │                                      └────────────────────────────┘
└────────────────────────────┘
```

- **Start**: « Commencer une tournée » (outlined, a red ▶) under the totals of Accueil's panel,
  for an active member of the open secteur (not a visiting admin). One tournée at a time on a
  phone; it belongs to the secteur it started in, and its card shows only there. A tournée of a
  secteur the phone no longer has (left, deleted, removed) can never be ended: « Commencer »
  forgets it, its dons with it, and starts the new one (#162). Offline too.
- **While it runs**: on Accueil the card « ● En tournée depuis 1 h 20 », « 19 dons · 280 € »
  (« 1 don · 10 € », « 0 don · 0 € »), « Voir les dons › » and « ■ Terminer » (TalkBack
  « Terminer la tournée »); on the street screen a one-line card « ● En tournée · 19 dons ·
  280 € · Voir les dons › » under the progress bar. The status picker asks for the don after
  ✓ and offers « + Ajouter un don » on a ✓ house (§5.6). A tournée survives a kill (§6.3).
- **Dons de la tournée** (« 19 dons · 280 € » under the title): newest first, « 10 € · Espèces › »,
  « Calendrier offert › »; a tap opens « Modifier le don » (« Espèces | Chèque | Carte »,
  « Montant », « Annuler » and « Valider », « Supprimer ce don »); « Ajouter un don » opens
  « Nouveau don », empty, on Espèces: the way for money from someone with no house (stopped in
  the street). This is also how a mistake is fixed after the snackbar has gone. Changing a don
  here never changes a house's calendars (dons know no house): « − » in the house's sheet does.
- **Amounts**: in euros, cents allowed (« 7,50 », a comma or a dot), 0,01 € to 1 000 € a don;
  shown « 7,50 € », whole euros without cents (« 10 € »). Quick amounts 5 / 10 / 20 €.
  Refusals under « Montant », keyboard kept: « Écrivez un montant. », « Entrez un montant
  valide. » (not a number, or 0), « Deux chiffres après la virgule au plus. », « 1 000 € au
  plus par don. ».
- **Terminer** opens « Bilan de la tournée »: « Samedi 24 octobre, de 14 h 05 à 18 h 20 », three
  figures — « 23 maisons visitées » (the houses and doors this member made ✓ or ⊘ during the
  tournée; one undone does not count), « 19 dons », « 2 calendriers offerts » —, « ARGENT
  RÉCOLTÉ » with count and amount per method (« Espèces », « Chèques », « Carte bancaire ») and
  « Total », « Voir les dons › », then « Valider la tournée » (red), « Continuer la tournée »
  (the tournée goes on) and « Abandonner la tournée » (red text, #136). « Valider » asks « Valider la tournée ? — Vous ne pourrez plus la
  modifier. [Annuler] [Valider] », then sends the summary (queued offline), forgets the dons
  and goes back to Accueil without a tournée. **A validated tournée is never changed or
  deleted** (only with its secteur, or its campaign, §5.10).
- **Abandonner** (#136, for a tournée started by mistake) asks « Abandonner la tournée ? —
  Ses dons seront perdus. Les maisons marquées restent marquées. [Annuler] [Abandonner] »
  (« Abandonner » in red), then the phone forgets the tournée and its dons (`open_round.json`,
  `AbandonRound`): nothing is sent, so « Collecte » never counts it; the houses marked during it
  stay marked. Works offline. Back to Accueil with its usual top bar, « Commencer une
  tournée » offered again.
- **Équipe**: **no money per member**, by decision. After the members and the Corbeille,
  « COLLECTE 2026 » with « 600 € récoltés » and « 41 dons en 4 tournées » under it, ›, which opens
  **Collecte 2026** (« Secteur 49 · tournées validées »): « TOTAL DES 4 TOURNÉES », the count and
  amount per method, « Calendriers offerts » and « Total »; then « TOURNÉES », each validated
  tournée newest first without its member (« Samedi 24 oct. · 14:05 → 18:20 », « 23 maisons,
  19 dons », its total; a tap unfolds its methods); and « Une tournée validée ne peut plus être
  modifiée. Les dons ne sont jamais associés à une adresse. ». Read from the phone's copy, so
  it works offline. Every member sees it.
- Plurals: « 0 don », « 1 don », « 2 dons »; « 1 calendrier offert », « 2 calendriers offerts ».
- Delivered in #109 (`presentation/round/`, `ui/screens/round/`, the don steps in
  `ui/screens/street/status_picker_sheet.dart`): « Commencer une tournée » is the first row of
  Accueil's list (it scrolls with it), the card in its place while one is on; « depuis » reads
  « moins d'une minute », « 20 min », « 1 h 20 », « 2 h », kept up every 30 s; tapped in a
  secteur while a tournée started in another is on, « Une tournée est déjà en cours dans un
  autre secteur. ». The street's line sits between the progress bar and « Côté impair | Côté
  pair », a tap opens « Dons de la tournée » (the snackbar goes first). « Montant du don »
  after a « Fait » is closed without a don by ✕, a swipe, a tap beside it or back alike: each
  puts the house back (`UndoLastChange`, so « maisons visitées » counts it no more) and shows
  no snackbar; its ✕ reads « Annuler : la maison reprend son statut » (« la porte » on a door).
  « Autre montant » has a ← back to « Montant du don »; « OK » on the keyboard validates.
  Snackbars: « N° 7 fait · 10 € en espèces », « N° 7 fait · calendrier offert », « N° 9 · 5 €
  en chèque ajouté », « Porte 51 : fait · 10 € en espèces », « Porte 51 · 5 € en chèque
  ajouté »; « Annuler » removes the don by its place in the tournée. « + Ajouter un don » here
  only gives the don (the calendar comes with #114). « Dons de la tournée » before the first
  don: « Aucun don pour l'instant. »; « Modifier le don » on a « Calendrier offert » opens on
  Espèces, empty (« Valider » makes it a don of money); « Supprimer ce don » asks nothing. The
  « Bilan » takes its end time from the clock when it opens; « Valider » goes back to Accueil
  once the summary is kept. No ✎ correction per method in the « Bilan » (in RunRecap's script
  only, not in this section).
- Delivered in #111 (`WatchCollecte`, `presentation/collecte/`, `ui/screens/round/collecte_screen.dart`,
  the shared `ui/components/money_lines.dart`): « COLLECTE 2026 » sits between the Corbeille and
  « Communes » in Équipe, shown once the tournées are read (none yet: « 0 € récoltés », « 0 don en
  0 tournée »), hidden when they cannot be; an admin visiting the secteur sees it too (§5.12, the
  rules let admins read `rounds/`). A tournée reads « Sam. 24 oct. · 14:05 → 18:20 » (the mockup's
  short day); every row starts folded and each unfolds on its own. « TOTAL DE LA TOURNÉE » for one,
  « TOTAL DES TOURNÉES » for none. Unreadable: « La collecte ne peut pas être affichée. ».
- **Changed by 5.16 (#143, #155):** « Valider » no longer hands the summary to Firestore's queue
  and forgets it: the tournée is kept on the phone as « validated, not yet sent » until the server
  has its summary, and Collecte lists those apart, out of the totals.

### 5.14 Préparer le secteur, partir en tournée (built #120–#125)

Agreed 2026-11-03 (ASCII in the terminal, then mockups RunStart, RunHome, RunStreet,
StreetIdle, RunTeam, Team, TeamMember, Pick, PickZone). The app has **two moments that never
share a screen**: *preparing the secteur* (a few times a year: members, communes, streets) and
*being out on a tournée* (in the street, often offline). Preparation lives in the **Secteur**
screen; Accueil is for the street work, and a tournée turns it into the tournée screen. This
section overrides 4, 5.3, 5.4, 5.5, 5.6, 5.8 and 5.13 wherever they disagree; the parts it
removes are marked « (removed, 5.14) » there.

```
  Accueil, no tournée              Accueil, en tournée              Rue, no tournée
┌────────────────────────────┐   ┌────────────────────────────┐   ┌────────────────────────────┐
│ Secteur 49 · 2026 ▾•    [⚙]│   │▓● En tournée · 1 h 20     ▓│   │ ← Rue des Lilas 31/42  [✎] │
│ ░░ map ░░░░░░░░░░░░░░░░░░░ │   │▓19 dons · 280 € ›         ▓│   │ Impair      │  Pair        │
│ [faite][en partie][à faire]│   │▓            [■ Terminer]  ▓│   │ [1 ✓][3 ○]  │ [2 ✗][4 ○]   │
├────────────────────────────┤   │ ░░ map ░░░░░░░░░░░░░░░░░░░ │   │ [5 ↻][7 ○]👆│ [6 ○][8 ◐]   │
│ Rues · 31/50               │   ├────────────────────────────┤   ├────────────────────────────┤
│ [ ▶ Commencer une tournée ]│   │ Rues · 31/50               │   │ Commencez une tournée pour │
│ Rue des Lilas ▓▓▓░ 31/42 › │   │ Rue des Lilas ▓▓▓░ 31/42 › │   │ marquer les maisons.       │
│ Allée des Pins ░░░░  0/8 › │   │ Allée des Pins ░░░░  0/8 › │   │                [Commencer] │
└────────────────────────────┘   └────────────────────────────┘   └────────────────────────────┘
  Secteur (the title)              Ajouter des rues · Carte         Ajouter des rues · Zone
┌────────────────────────────┐   ┌────────────────────────────┐   ┌────────────────────────────┐
│ ← Secteur 49               │   │ ✕  Ajouter des rues        │   │ ✕  Ajouter des rues        │
│ ⇄ Changer de secteur     › │   │ [ Carte ]   Liste          │   │ [ Carte ]   Liste          │
│ ▄▄ Code K7P-2QX [⧉]        │   │ [🔍 Rechercher…  ] [⬚ Zone]│   │ [🔍 Rechercher…  ] [■ Zone]│
│ EN ATTENTE (1) …           │   │ ░▓▓▓▓▓✓▓▓▓░░░░░░░░░░░░░░░ │   │ ░░┌┄┄┄┄┄┄┄┄┄┄┄┄┄┄┐░░░░░░░ │
│ MEMBRES (5)                │   │ ░░░░║░░░░▓▓▓✓▓▓▓░░░░░░░░░ │   │ ░░┆▓▓✓▓▓░░▓▓✓▓▓┆░░░░░░░ │
│ Manu (vous) · admin, Léa … │   ├────────────────────────────┤   │ ░░└┄┄┄┄┄┄┄┄┄┄┄┄┄┄○░░░░░░░ │
│ RUES (38)                  │   │ 2 rues sélectionnées       │   ├────────────────────────────┤
│ + Ajouter des rues       › │   │       Tout décocher        │   │ 4 rues dans la zone        │
│ Corbeille · 2 éléments   › │   │ Rue Pierre Morin · 19 n° ✕ │   │ ☑ Rue Pierre Morin · 19 n° │
│ COMMUNES (2) …             │   │ Impasse des Tilleuls … ✕   │   │ ☑ Rue du Moulin · 23 n°    │
│ COLLECTE 2026            › │   │ [     Ajouter 2 rues     ] │   │ ☐ Rue Pasteur · déjà dans… │
├────────────────────────────┤   │ Rue absente ? Saisir à la …│   │ [     Ajouter 3 rues     ] │
│ [ Quitter le secteur ]     │   └────────────────────────────┘   └────────────────────────────┘
└────────────────────────────┘
```

- **No attribution** (built in #120). A member of the secteur covers every street of it; the admin decides who
  is in the secteur (5.12). Gone everywhere: « Mes rues » / « Autres rues du secteur »,
  « libre » (line, legend, card), « Me l'attribuer », « La faire aussi », « Ne plus la faire »
  (street card and edit mode), « Ajouter et me l'attribuer » / « Ajouter sans m'attribuer »,
  « Vous la faites (avec Manu) » / « Faite par … », the streets per member in Équipe (#105) and
  « Équipe : 43 % » (it would repeat the totals). Data: `Street.assignees`, `MyStreets`,
  `TeamRoster`'s use for streets, `TakeStreet` / `ReleaseStreet` and the Firestore field
  `assignees` go, and the rules stop checking it (§6, §8.2). Breaking change, no migration
  (one user, §3): documents keep a stale `assignees` field that nobody reads, or the test
  secteurs are created again.
- **Accueil, no tournée** (RunStart): top bar « Secteur 49 · 2026 ▾ » (opens Secteur since
  #135, see below) and ⚙. The map shows every street of the secteur, coloured « faite · en
  partie · à faire » (three samples in the legend). The panel shows « Rues · 31/50 » (doors done
  over every street of the secteur, as the admin visit already counted), « ▶ Commencer une
  tournée » for an active member (5.13), then every street of the secteur in one list, with no
  section header and no « + Ajouter des rues » row. A tap on a street's line on the map
  opens its street card: name, commune, « 31/42 faits », « Ouvrir ». A row opens the Street
  screen directly, as « Mes rues » did (no card, the map does not move: #93's « Autres rues »
  card is gone with them). The pending-sync line stays at the bottom.
- **The title opens Secteur** (#135, from the user's phone test of 0.11.0: the 🗺 button
  confused, and the title was tapped for the secteur's details). Built in #121 as a Secteur
  button (`Icons.map_outlined`) replacing 👥; #135 removes it. Accueil's title « Secteur 49 ·
  2026 ▾ » now opens Secteur, and the red dot of a waiting join request sits after its ▾,
  said by screen readers in the title's name (« Secteur 49 · 2026, CS Villefranche, 1
  demande en attente »; without one « Secteur 49 · 2026, CS Villefranche »). « Mes
  secteurs » is reached from **« ⇄ Changer de secteur › »**, the first row of Secteur (5.8),
  or Paramètres; with no secteur open the app's name still opens it (5.0). During a tournée
  the band replaces the top bar, title included, as before. Secteur is the screen 5.8 called
  Équipe (title « Secteur 49 » as before). Changes there:
  member rows have no street count; after « MEMBRES », **« RUES (38) »** with the row « + Ajouter
  des rues › » (« Sur la carte ou depuis la liste des communes » under it), which opens 5.4,
  and the Corbeille row moved under it; then « COMMUNES », « COLLECTE 2026 » and the pinned
  footer, unchanged. The rows show to active members and admins, not to a pending member.
  « RUES (38) » counts the streets Accueil lists (outside the Corbeille), from the phone's
  copy; it reads « RUES » until they are read.
- **En tournée** (RunHome, RunStreet, built in #123): while this phone's tournée runs in the open secteur,
  a band **replaces Accueil's top bar**: Surface background with a 6 dp Accent edge on its left,
  ink text and an Accent dot, a 1 dp divider under it (dark mode: the dark Surface and Accent);
  the full red was too loud for something on screen for hours (chosen 2026-11-03). It sits **above the street screen's top bar** (and the building grid's). Its left part,
  one 48 dp target, reads « ● En tournée · 1 h 20 » (« depuis » rules of 5.13) over « 19 dons ·
  280 € › » in 24 dp titles, and opens « Dons de la tournée » (TalkBack « En tournée depuis 1 h
  20, 19 dons, 280 €. Voir les dons »). Its right part is « ■ Terminer », a 48 dp ink pill with Surface text
  (the theme's inverse pair; « Terminer la tournée »), which opens the « Bilan ». While
  the band shows, Accueil has no title (so no Secteur, nor secteur switch) and no ⚙: preparation waits
  until the tournée ends. The tournée card of 5.13 (Accueil's list, the street's line under the
  progress bar) goes. At 200 % text the band wraps its lines and « Terminer » stays whole.
  Delivered in #123 (`ui/screens/round/round_band.dart`; « Commencer une tournée » alone in
  `round_start_button.dart`): the band paints under the status bar, its icons dark on the light
  Surface and light on the dark one; « 1 h 20 » follows « depuis » (« moins d'une minute »,
  « 20 min », « 2 h »), kept up every 30 s. On the street screen the top bar sits under it
  (laid out in the screen, not as the `Scaffold`'s app bar, so the band's height may grow with
  the font); in the building grid it spans the sheet under its grabber, above « ✕ 8 Rue des
  Lilas ». « Dons de la tournée » and « Terminer » drop the street's or the grid's snackbar first
  (its « Annuler » names a don by its place). The debug gallery button of Accueil's top bar goes
  with it during a tournée.
- **Marking only in a tournée** (StreetIdle, built in #122): with no tournée running, the street screen shows
  every status but a tap on a house or a door opens nothing. Instead a snackbar says
  « Commencez une tournée pour marquer les maisons. » with « Commencer », which starts the
  tournée (as Accueil's button, offline too) and stays on the street, where the band appears.
  The next tap opens the picker. A building tile still opens its grid, read-only in the same way. « Modifier la rue » (✎) and everything in it
  (numbers, buildings, doors, the name) stay available without a tournée: that is preparation.
  The « Appuyez sur une maison… » pill is not shown. A visiting admin (never in a tournée) gets
  « Seuls les membres en tournée marquent les maisons. » with no action. ✓ therefore always asks
  for the don (5.13); « N° 7 : fait » without a don no longer exists. The tournée is phone-only
  (§6.3), so this is an app rule, not a security rule.
  Delivered in #122 (`presentation/round/marking_access.dart`,
  `ui/screens/round/marks_only_in_round.dart`): the snackbar lasts 4 s like the others; the
  building's own « Repasser » under the grid is a mark too, so it answers the same way, and the
  grid's « Appuyez sur une porte… » shows during a tournée only; while the phone's tournée is
  still being read (a moment at start), a tap does nothing. « Commencer » tapped while a
  tournée of another secteur is on says « Une tournée est déjà en cours dans un autre
  secteur. » (5.13).
- **Ajouter des rues** (Pick, PickZone), opened from Secteur only; its ✕ and the back gesture go
  back to Secteur. Still needs the network (5.4); « Liste » unchanged.
  - **Tap to tick**: a tap on a road ticks it (5.4's look-up: point → BAN street → its road from
    the map's tiles; the dark casing with a white core, and a ✓ disc on it). A tap on a ticked
    road unticks it. A tap on a street already in the secteur ticks nothing and says
    « Rue des Lilas est déjà dans le secteur. ». « Aucune rue connue ici » and the other look-up
    failures of 5.4 come as a snackbar with « Saisir à la main ». The single-street card is gone.
  - **Selection sheet** (bottom, over the map): with nothing ticked, « Touchez les rues à ajouter
    ou tracez une zone. » and « Rue absente de la carte ? Saisir à la main ». With some, « 2 rues
    sélectionnées » (« 1 rue sélectionnée ») and « Tout décocher », one row each (name, « commune ·
    19 numéros », ✕ « Retirer rue Pierre Morin »), « Ajouter 2 rues » (red) and the manual link.
    The rows scroll past four; dragging the handle down leaves only the title.
  - **Zone**: a 48 dp « ⬚ Zone » pill next to the search (said « Sélectionner une zone »). On, it
    turns ink (« Zone en cours, annuler ») and a drag on the map draws a rectangle instead of
    panning (dimmed outside, dashed edge, a round handle at a corner to resize it). On release,
    the streets inside are listed: the named roads of the map's tiles in the rectangle (as #92
    reads shapes), each matched to its BAN street by name in the secteur's communes. The list
    reads « 4 rues dans la zone » with a checkbox per street, all ticked; those already in the
    secteur are greyed, unticked, « Déjà dans le secteur »; a road with no BAN street « Aucune
    adresse connue », greyed. A zone is drawn at any zoom (#134; its roads are always read at
    street level, where small roads exist) and keeps 50 streets at most (« Zone trop grande :
    50 rues au plus. », also for a zone too large to read). One finger draws; two fingers move
    and zoom the map, « Zone » staying on (#134). Streets ticked by taps and by the zone add
    up; « Zone » again leaves the mode and keeps the ticks. The map moves to keep the zone
    drawn, and else the latest ✓, clear of the sheet (#132).
  - **Adding**: « Ajout en cours… 2/3 », then « 3 rues ajoutées au secteur » **on this
    screen, which stays open** (#134): the streets added leave the selection and show as the
    secteur's on the map, and the user goes on adding; ✕ or back leaves. Streets that failed
    stay ticked, with the reason above the button. A street in the Corbeille comes back with
    its marks, as in Liste (whose « Ajouter N rues » still goes back to Secteur).
  - Delivered in #124 (`presentation/add_streets/`, `ui/screens/add_streets/add_streets_screen.dart`,
    `domain/map/picked_road.dart`): the search box above the map, « Zone » on its right (#125). **A tap on a road** marks the point (dark dot in a faint halo) and the sheet
    says « Recherche de la rue… » while the BAN is asked; the street found is ticked, its ✓ disc
    at the point tapped (on the road under the finger since #132; at the BAN's point for a street picked in the search; a dark circle
    under the ✓ picture, so the disc shows even where symbols do not render), its road drawn
    when the map's tiles give it (`LookUpStreetShape`, asked once per tick); several taps may be
    on their way at once, each answer ticks its street. **The street of a tap is the road under
    the finger** (#134, `LookUpStreet`; IGN BD TOPO's road and its BAN id first since §5.18, what follows
    is the fallback): the geocoder answers the street whose one point (about
    its middle) is nearest, often a side street near a crossing or along a long road, which put
    a ✓ on the road tapped for another street, drawn elsewhere or not at all. So the map's
    tiles are read around the tap too (`StreetShapes.roadsIn`, 30 m around): the nearest named
    road within 30 m is the one tapped; when the geocoder's street does not bear its name, the
    BAN street of that name is searched in the geocoder's street's commune (« Aucune rue connue
    ici. » when none has it). The map may misspell a name (« Rue de le Paix » for the BAN's
    « Rue de la Paix », #134): among the search's streets and the geocoder's own, the one named
    exactly is taken, else the closest name within a misspelling (`StreetName.typosFrom`: the
    small words « de », « la », « du »… may differ or be missing, the other words must be the
    same bar one letter of one word of 7 letters or more, so « Rue de la Mare » never becomes
    « Rue de la Gare »); two streets as close give « Aucune rue connue ici. ». With no named road within 30 m, or the tiles unreadable, the
    geocoder's street stands. The ✓ disc is a dark circle (drawn by every renderer, even the emulator's, which draws no symbol layer) under the ✓ picture. A tap on a ticked road or its ✓, or a tap
    whose answer is a street already ticked, unticks it; a street picked in the search stays
    ticked and the map moves 200 m around it. « Tout décocher » also drops the answers still on
    their way. A street of the secteur (its line, its dots, or the BAN's answer) says « Rue des
    Lilas est déjà dans le secteur. » (4 s); the look-up failures say « Connexion nécessaire
    pour ajouter une rue. », « Aucune rue connue ici. », « Impossible d'ajouter des rues pour
    l'instant. Réessayez plus tard. » with « Saisir à la main ». With nothing ticked the sheet reads « Touchez les rues à
    ajouter ou tracez une zone. » (#125). Each row: name, « Villefranche-sur-
    Saône · 19 numéros », ✕ (« Retirer Rue Pierre Morin »); rows are 52 dp, four show, then
    they scroll (never over 35 % of the map's height). The handle and title fold the sheet
    (drag down or tap; TalkBack « Réduire la sélection » / « Afficher la sélection »); the
    map keeps clear of the sheet. **Adding** stores the streets one after the other in the
    order ticked (`AddStreetFromMap`), each with its road when known, never waiting for one
    (Accueil fills a missing road later, 5.3); a street a teammate added meanwhile counts as
    added. While adding, ticks, taps, ✕ and the way back wait; once started it goes on even
    if the app leaves the screen. A failure (the BAN gave a number twice) reads « 1 rue n'a pas
    pu être ajoutée : la Base Adresse Nationale donne des numéros incohérents. Saisissez-la à
    la main. »; it goes once the ticks change. The ticks stay while « Liste » shows, until the
    screen closes. The snackbar counts every street now in the secteur (« 3 rues ajoutées au
    secteur »), those brought back from the Corbeille included.
  - Delivered in #125 (`application/use_cases/find_zone_streets.dart`, `domain/map/street_zone.dart`,
    `ui/map/zone_drawing.dart`): « ⬚ Zone » is a 48 dp pill right of the search box (white,
    ink while on). On, the map does not pan under one finger: one finger draws the rectangle
    (painted by the app while the finger moves, then drawn by the map itself, so it follows a
    zoom: the rest dimmed at 18 %, a dashed edge, a white handle at the south-east corner); a
    drag starting within 24 dp of the handle resizes the zone from its opposite corner; two
    fingers move and zoom the map and drop the drawing, « Zone » staying on (#134: the map is
    free to pan from the second finger down until the last is up, `ZoneDrawing`); a drag
    under 16 dp is no zone; a tap still ticks a road. On
    release the sheet becomes the zone's: « Recherche des rues de la zone… », then « 4 rues
    dans la zone » (« Aucune rue dans la zone ») with a row per street (checkbox, name, « 19
    numéros », or greyed « Déjà dans le secteur » / « Aucune adresse connue »), to add first,
    then those of the secteur, then the roads without address, each in French order, and
    « Ajouter N rues » counting every street ticked, by taps and zones (disabled at 0). The
    roads are those of the zoom-14 tiles under the zone (since §5.18 the IGN BD TOPO stretches,
    grouped by BAN id, no name matching nor commune limit; what follows is #125's; `StreetShapes.roadsIn`; the most
    detailed OpenFreeMap has, the map's street zoom showing them enlarged), whatever the map's
    zoom (#134), at most 16 tiles, one per name, drawn whole as far as the tiles go; a road is matched by name
    (`StreetName.matches`, then, for a road still unmatched once the communes are read, the
    closest name within a misspelling as for a tap, #134) in the secteur's communes nearest first (the zone's middle against
    each commune's centre; without communes, those of its streets), at most 3 communes read,
    a name in two communes taken in the nearest; two roads naming one BAN street make one row.
    More than 50 named roads, or a zone over more than 16 tiles (none read,
    `StreetShapesFailure.tooLarge`): nothing listed, « Zone trop grande : 50 rues au plus. »
    (« Zoomez pour tracer une zone. » and zoom ≥ 15 went with #134); offline or a failing
    service: the snackbars
    of a tap. Each ✓ sits half-way along the road's first piece inside the zone. A zone's
    street brings no numbers until added: « Ajouter » reads them (`LookUpStreet`) one street
    after the other; offline, that street and the next ones stay ticked, « 1 rue n'a pas pu
    être ajoutée : connexion nécessaire. »; a service error, « Impossible d'ajouter 1 rue pour
    l'instant. Réessayez plus tard. » (#137). Its road is not stored (it may be cut where the tiles
    end): Accueil fills it from its houses (5.3). Since §5.18 its whole line is looked up by its
    BAN id when it is ticked and stored with it. A new zone replaces the one shown, its
    ticks staying; « Zone » off drops the zone, keeps the ticks and the selection sheet comes
    back, which with « Zone » on and nothing ticked reads « Faites glisser le doigt sur la
    carte pour tracer une zone. ».
  - Delivered in #134: « Ajouter N rues » stays on the screen (« 3 rues ajoutées au
    secteur » there; the streets added leave the selection and their ✓, and are drawn as the
    secteur's); once every street is added the zone shown goes too, « Zone » staying on for
    the next one; when some failed the zone stays, its streets added now « Déjà dans le
    secteur ». ✕ and the back gesture still leave (not while adding).
  - Delivered in #132 (camera moves and the ✓'s place only; nothing new on screen): **the
    zone drawn and the latest ✓ stay clear of the sheet.** The map keeps one thing in view
    (`AddStreetsMapState.keepInView`): the zone shown, else the ✓ of the street last ticked by
    a tap or the search while it is ticked (none once a zone was drawn, « Zone » turned off,
    the streets added, or that street unticked: the map never goes back to an older ✓). When
    it changes, and each time the sheet grows (a row ticked, the zone's « Recherche… » becoming
    its list) until a finger touches the map or « Me localiser » moves it, the map slides just
    far enough to show it 40 dp (the handle's 24 dp reach and a 16 dp gutter) inside the part
    the sheet and the edges leave; a zone too large for that part makes the map zoom out to fit
    it, never in (`cameraReveal` in `ui/map/map_camera.dart`). The zone's handle is so always
    within reach above the sheet; with no zoom limit on zones (#134), zooming out risks
    nothing. A street picked in the search moves the map 200 m around it first; the ✓ is then
    kept in view once that move ends. **The ✓ sits on the road tapped**: at the point of the
    road under the finger nearest to it (`LookUpStreet` reads that road from the tiles, 30 m
    around, `StreetShape.nearestPointTo`), so it no longer floats beside the road; where the
    map names no road within 30 m it stays where the finger was, and a street picked in the
    search keeps the BAN's point.

### 5.15 Partie de la rue: a street split between secteurs (#133, #138–#142 built)

Agreed 2026-11-11 (ASCII in the terminal, then mockups StreetPart, Pick, Edit). A street is
not always covered whole by one secteur: it may be cut in the middle, by side (odd / even), or
both (« impairs 1–57 + pairs 2–30 »), shared by 2, 3 or more secteurs, and parts of it may
belong to no secteur at all (a valid state, not an error). This section overrides 5.3, 5.4,
5.5 and 5.14 wherever they disagree.

```
  Partie de la rue (StreetPart)     selection sheet (Pick)            edit mode (Edit)
┌────────────────────────────┐   ┌────────────────────────────┐   ┌────────────────────────────┐
│ ✕ Partie de la rue         │   │ 2 rues sélectionnées       │   │ ✕ Modifier la rue     [OK] │
│   Rue Nationale · n° 1 à 41│   │ Rue Pierre Morin         ✕ │   │ Nom [ Rue des Lilas      ] │
│ (Les deux)[Impairs](Pairs) │   │ Villefranche · 19 numéros  │   │ ┌────────────────────────┐ │
│ ░░ entre 5 et 7  entre 21… │   │ Toute la rue ›             │   │ │Partie de la rue        │ │
│ ░○ ○ ○ ●┃● ● ● ● ●┃▒▒▒▒▒ ░ │   │ Impasse des Tilleuls     ✕ │   │ │Impairs 1–57 · pairs 2–30›│
│ ░━━━━━━◆━━━━━━━━━━◆━━━━━ ░ │   │ Villefranche · 5 n° sur 8  │   │ └────────────────────────┘ │
│ ░· · · · · · · · · · ·  ░ │   │ Pairs 2–8 ›                │   │ CÔTÉ IMPAIR │ CÔTÉ PAIR    │
├────────────────────────────┤   │ [     Ajouter 2 rues     ] │   │ [ 1   ✕]    │ [ 2   ✕]     │
│ Impairs 7–21 · pairs 2–30  │   └────────────────────────────┘   └────────────────────────────┘
│ 23 numéros gardés sur 41   │
│ [Tous les impairs][Aucun…] │
│ ⚠ Le 19 et le 21 sont aussi│
│   dans le secteur 12 (CS …)│
│ [         Valider        ] │
└────────────────────────────┘
```

- **What a part is** (`StreetPart`, domain): for each side, odd and even, either every number,
  none, or a range « du n° a au n° b » (bounds on the numeric part, so 3bis goes with 3). The
  part is stored on the street and is the one thing every screen, the index and the add
  flows read. The numbers outside it are **never stored** (not added, not kept in the
  Corbeille once the part is chosen at adding), so « Rues · n/m », the street's « 31/42 » and
  every progress figure count only the numbers held, with no change. « Toute la rue » is the
  part with both sides whole, and the default.
- **« Partie de la rue »** (StreetPart, full screen, needs the network: the numbers and their
  positions come from the BAN, the other secteurs' parts from the index): « ✕ Partie de la
  rue » over « Rue Nationale · n° 1 à 41 »; « Les deux | Impairs | Pairs » (radio group
  « Côté », 48 dp); the map on the street, its road grey with the kept stretch drawn as the
  selected road (ink casing, white core), the dots of the side shown (kept: ink; left out:
  hollow), the other side greyed. **Two marks** (round 32 dp handles on a stem, a dark label
  « entre 5 et 7 ») slide along the road and **snap between two consecutive dots of the side
  shown**, so a finger is always exact. On « Les deux » the two marks cut both sides at once;
  on « Impairs » or « Pairs » that side has its own two marks. The sheet under the map gives
  the result, « Impairs 7–21 · pairs 2–30 » over « 23 numéros gardés sur 41 », two quick
  buttons for the side shown (« Tous les impairs », « Aucun impair »; « Toute la rue » and
  « Rien » on « Les deux »), then « Valider » (red). ✕ and back leave with nothing changed.
  Numbers without a position (typed by hand) are kept or left out by their number. A street
  with no position at all (a manual street) opens the same sheet without the map: the side
  switch and « Du n° / Au n° » fields per side.
- **Other secteurs** (shared index, §6.2 `streetParts/{banId}`): the stretches other secteurs
  hold show hatched on the side they hold, labelled « Secteur 12 ». Numbers both in this part
  and in another secteur's are amber dots, and an amber block above « Valider » names them:
  « Le 19 et le 21 sont aussi dans le secteur 12 (CS Villefranche). » (« Le 19 est aussi… »;
  more than five: « 8 numéros sont aussi dans le secteur 12 »). **A warning only**: « Valider »
  still works (the index may be stale, and a centre may want two secteurs on the same
  numbers). The centre's name is said only when it is not this secteur's. Offline or the index
  unreadable: no hatching, no warning, nothing else changes.
- **When the part is chosen:**
  - **When adding** (Pick, PickZone, Liste): each row of the selection sheet, of the zone's
    list and of « Liste » shows its part as a red link, « Toute la rue › » by default, which
    opens « Partie de la rue » before the street is added; once chosen the link names the part
    (« Pairs 2–8 › ») and the row's count follows (« 5 numéros sur 8 »). « Ajouter N rues »
    then stores only the numbers of each part. A street another secteur already holds in part
    says so on its row (« Secteur 12 : impairs 19–41 ») so the part can be chosen before adding.
  - **Afterwards, in edit mode** (Edit): a « Partie de la rue » row under the name (52 dp,
    the part in bold, ›) opens the same screen. Shrinking the part sends the numbers left out
    to the Corbeille (5.11), asking first when some have marks (« 3 numéros ont des marques.
    Ils partent avec elles à la Corbeille. »); widening it brings numbers back from the
    Corbeille with their marks, and reads the others from the BAN.
  - « + numéros » in edit mode may add a number outside the part (the user knows the street):
    it is added, and the part is not changed.
- **Delivered in #138** (domain, storage, rules; no screen): `StreetPart` (`odd` / `even`, each
  `SidePart.all`, `.none` or a `NumberRange`, bounds of their side), `Street.part`,
  `Street.changePart` and `ChangeStreetPart`. Only the numbers whose place changes move: a
  number « + numéros » added outside the old part, or one removed with ✕ inside it, is left
  alone. `ChangeStreetPart` first answers `MarkedNumbersLeaving` (changing nothing) when numbers
  with marks would leave; the screen asks, then calls again with `marksConfirmed: true`. A
  widening reads the BAN (offline: `NumbersUnreadable`, nothing changed); a street typed by hand
  only gets numbers back from the Corbeille. The words (« Impairs 7–21 · pairs 2–30 »,
  « Tous les impairs », « Impair 7 », « Aucun numéro ») are `streetPartText` in
  `ui/components/street_part_words.dart`.
- **Delivered in #139** (screen, edit mode): `StreetPartChoice` (domain) holds the street's
  numbers with their positions, the road, the side shown and the part; the marks stand at
  places along the road (`LineTrack`: the road's pieces joined end to end, or the straight
  line between the two dots farthest apart when the road is not known), before the first dot
  of the side shown, between each two consecutive dots (3 and 3bis are one), after the last;
  on « Les deux » the dots of both sides in road order. The part is worked out from the dots
  between the marks, side by side: none kept is « aucun », both end dots kept is « tous »,
  otherwise from the lowest kept number to the highest, a mark at an end taking the numbers
  without position beyond it. A mark at an end reads « avant le 1 » / « après le 41 »; two
  marks together part again towards where the finger goes; TalkBack moves a mark one place
  with a swipe up or down. The map does not move (it opens fitted to the dots), so a drag
  only moves a mark. No position at all, or a single place: « Du n° / Au n° » for the side
  shown (both sides on « Les deux »), bounds brought onto the side, blank meaning the side's
  first or last number. The screen takes a `StreetPartRequest` (street name + choice) and
  returns the part (`showStreetPart`); in edit mode `ReadStreetPartChoice` reads the BAN's
  numbers (merged with the street's own, shown or in the Corbeille, their positions first;
  a street typed by hand or unknown to the BAN uses its own, offline), the row shows a
  spinner meanwhile, offline says « Connexion nécessaire pour lire les numéros de la rue. »
  (« Impossible de lire les numéros de la rue pour l'instant. Réessayez plus tard. »), and
  « Valider » runs `ChangeStreetPart`, asking « Changer la partie de la rue ? — 3 numéros ont
  des marques. Ils partent avec elles à la Corbeille. [Annuler] [Changer] » first. The sheet
  sits under the map rather than over it.
- **Delivered in #140** (when adding): under each street ticked, in the selection sheet, the
  zone's list (ticked rows) and « Liste » (ticked rows), the red link `PartLink` (« Toute la
  rue › », 48 dp high where the mockup draws 32) opens « Partie de la rue »; a street ticked by a
  tap or the search has its numbers already, one of a zone or of « Liste » has them read first
  (`LookUpStreet`, `ReadStreetNumbers`; the link spins meanwhile, offline « Connexion nécessaire
  pour lire les numéros de la rue. »), then kept for adding. The road given is the one the map
  found (none for « Liste »: the line between the farthest dots). The row then names the part
  and says « 5 numéros sur 8 » (« 5 n° sur 8 » in « Liste »); the zone's list keeps the count it
  listed until a part is chosen. The part goes with the tick: unticked (✕, « Tout décocher », a
  second tap) it is the whole street again; a street that failed to be added keeps it.
  « Ajouter N rues » stores only the numbers of each part, with the part (`AddStreetFromMap`,
  `ImportReferenceArea(parts:)`, `StreetNumbers.heldBy`), in the same ordered writes. A street
  of the Corbeille has no link: it comes back as it went, its own part included
  (`StreetToAdd.fromCorbeille`, `ZoneStreetToAdd.fromCorbeille`); its part is changed afterwards
  in edit mode.
- **Delivered in #141** (the shared index): `streetParts/{banId}` holds an entry per secteur,
  written by `IndexedStreetRepository` (application), which wraps the open secteur's streets:
  a street from the BAN added, its part changed or restored from the Corbeille holds its part;
  sent to the Corbeille or purged, its entry goes (a street typed by hand has none). Every use
  case writes through it, the undo of « Supprimer la rue » included; a street added before #141
  gets its entry at its next such write (single user, nothing migrated). The writes are a `set`
  merging the secteur's own entry, not awaited, queued offline like the street writes; the
  decorator is the one place reacting to street changes, and hands each index write to the
  background-write reporter, so a refused one is logged and never fails the street's (#158).
  Deleting the secteur removes its entry from the index of each of its streets first and waits
  for it: one that fails fails the deletion (« Pas de réseau » or not an admin) while its streets
  are still there to retry; the contents and the members are then listed again for what a
  teammate wrote meanwhile, a bounded number of times (#150). Port `StreetPartIndex`, adapter `FirestoreStreetPartIndex`. The reads
  (`ReadOtherSectorParts`, by secteur number) run in the background and never delay anything:
  « Partie de la rue » reads them for a street with a BAN id (`StreetPartRequest.banId`), then
  draws each other secteur's stretch of each side it holds, from its first dot to its last
  (3 m beyond), beside the road on the side most of its houses stand (`LineTrack.hasOnLeft`), as
  a pale band crossed by dark diagonal bars (a picture repeated along it, `line-pattern`, set
  beside the road with `line-offset`) labelled
  « Secteur 12 » above the road; the dots kept that another secteur holds are amber
  (`PartDotLook.shared`), and an amber block above « Valider » has one line per secteur
  (`StreetPartChoice.overlaps`). The rows of the selection sheet, of the zone's list (every
  street to add, ticked or not) and of « Liste » (once ticked) ask once per street and show
  one line per other secteur, « Secteur 12 : impairs 19–41 », the centre named, as in the
  warning, only when it is not this secteur's (« Secteur 3 (CS Arnas) : toute la rue »).
  Offline, refused or unreadable: nothing shown.
- **The BAN's later additions**: the app never reads a street's numbers again once added
  (5.4), so nothing arrives by itself; a widening in edit mode is the only new read.
- **Map** (Accueil, 5.3, and « Ajouter des rues »): a street held in part draws only **the
  stretch between its first and last held number** (their positions brought onto the road,
  `StreetShape.nearestPointTo`); the rest of the road is not drawn. A part by side alone draws
  the whole stretch (one line cannot show a side). The house dots show only the numbers held,
  as today. « Ajouter des rues » draws another secteur's street as the map does, unticked: a
  tap on a street this secteur holds in part still says « … est déjà dans le secteur ».
- **Delivered in #142** (the map): `heldStretchOf(street)` (domain/map) gives what `MapLayers`
  draws and Accueil lights up when the street is tapped: the whole road when no side is a range
  or a side is held whole (« Toute la rue », « Impairs », « impairs + pairs 2–30 »), otherwise
  `StreetShape.stretchOver` the positions of the numbers the part holds, 3 m beyond the first
  and the last (a single house still has a line to tap). The numbers « + numéros » added
  outside the part and those without a position do not stretch it; with no number held placed,
  the whole road is drawn. `stretchOver` measures the road's pieces as one (`LineTrack`) and
  leaves out the gaps the track crosses between pieces that do not meet. The layers are worked
  out when the streets change, not when a street is tapped or another street ticked.

---

### 5.16 Audit follow-ups: unsent tournées, names per secteur, unreadable streets (M11, to build)

Agreed 2026-11-11 (ASCII in the terminal, then mockups CashUnsent, TeamRemove, JoinNameTaken,
SettingsNameTaken, StreetUnreadable, StreetUnreadableSheet). Overrides 5.2, 5.8, 5.9, 5.13 and
5.14 where they disagree.

```
  Collecte 2026 (#143)              Retirer Léa ? (#148)             Rejoindre, nom pris (#148)
┌────────────────────────────┐    ┌────────────────────────────┐   ┌────────────────────────────┐
│ ← Collecte 2026            │    │ Retirer Léa ?              │   │ ← Rejoindre un secteur     │
│ TOTAL DES 4 TOURNÉES  …    │    │ Léa n'aura plus accès au   │   │ [49] Secteur 49 · CS Ville…│
│ Sans les tournées pas      │    │ secteur. Ses marques       │   │ ⚠ « Léa » est déjà pris    │
│ encore envoyées.           │    │ restent dans les rues.     │   │ dans ce secteur. Choisissez│
│ PAS ENCORE ENVOYÉES (2)    │    │ ☑ Changer aussi le code    │   │ le nom que l'équipe verra… │
│ Lun. 26 oct. … 160 € ▸     │    │   Léa connaît le code      │   │ Votre nom dans ce secteur  │
│ ⏳ En attente d'envoi       │    │   actuel.                  │   │ [ Léa B.               ]   │
│ Dim. 25 oct. …  70 € ▸     │    │        [Annuler][Retirer]  │   │ Vos autres secteurs gardent│
│ ⚠ Refusée par le serveur   │    └────────────────────────────┘   │ « Léa ».                   │
│ [Réessayer]  Effacer       │                                     │ [ Demander à rejoindre ]   │
│ TOURNÉES …                 │                                     └────────────────────────────┘
└────────────────────────────┘
  Paramètres › Prénom (#148)        Accueil, rue illisible (#149)    Its sheet (#149)
┌────────────────────────────┐    ┌────────────────────────────┐   ┌────────────────────────────┐
│ VOUS  Prénom       Paul ›  │    │ Rues · 31/50               │   │ Rue Pasteur                │
│ VOS NOMS PAR SECTEUR       │    │ [ ▶ Commencer une tournée ]│   │ ⚠ Cette rue ne peut pas    │
│ Secteur 49 · CS V.  Paul D.│    │ Rue des Lilas ▓▓▓░ 31/42 › │   │ être lue : ses données sont│
│ Secteur 12 · CS G.  Paul   │    │ ⚠ Rue Pasteur              │   │ abîmées. Elle n'apparaît ni│
│ ┌ Votre prénom ──────────┐ │    │   Illisible              › │   │ sur la carte ni dans les   │
│ │ [ Paul ]               │ │    │ Allée des Pins ░░░░  0/8 › │   │ totaux.                    │
│ │ ⚠ « Paul » est déjà pris│ │    └────────────────────────────┘   │ Un administrateur peut la  │
│ │ dans le secteur 49 : vous│ │                                     │ supprimer, puis l'ajouter… │
│ │ y gardez « Paul D. ».   │ │                                     │ [ Supprimer la rue ]       │
│ │ Votre nom dans le s. 49 │ │                                     │   Administrateurs seulement│
│ │ [ Paul D. ] [Enregistrer]│ │                                     └────────────────────────────┘
└────────────────────────────┘
```

- **Unsent tournées, in Collecte only** (#143, #155). « Valider la tournée » keeps the summary on
  the phone, as a round « validated, not yet sent » (domain state), until the server confirms its
  create. Collecte lists them under « PAS ENCORE ENVOYÉES (n) », between the totals and
  « TOURNÉES », with « ⏳ En attente d'envoi » (queued, offline or not yet confirmed) or « ⚠ Refusée
  par le serveur » with « Réessayer » and « Effacer » (red text; asks first, the figures are lost).
  The totals leave them out (« Sans les tournées pas encore envoyées. », shown only when some are
  waiting). Nothing on Accueil. Accepted limit: a member removed from the secteur no longer reaches
  Collecte. An unreadable `open_round.json` is told rather than dropped silently.
  - Delivered in #143 + #155 (`UnsentRound`, `SendUnsentRounds`, `RetryUnsentRound`,
    `EraseUnsentRound`, `presentation/round/unsent_rounds_sender.dart`, the Collecte screen): « ⏳ En
    attente d'envoi » sits in the come-back blue, « ⚠ Refusée par le serveur » in red with a red
    outline, both as a badge under « 18 maisons, 12 dons »; « Réessayer » (outlined pill) and
    « Effacer » (red text) sit on a line of their own under the refused tournée's row, which still
    unfolds its methods like the others. A tournée waiting is sent by itself (no button) as soon as
    the server can answer, the app running. « Effacer » asks « Effacer la tournée ? — Ses chiffres
    seront perdus : la collecte ne la comptera jamais. [Annuler] [Effacer] » (« Effacer » red), and is
    offered on a refused tournée only (one waiting may be on its way). An unreadable
    `open_round.json` shows once, over the first screen, « Les tournées gardées sur ce téléphone
    n'ont pas pu être relues : leurs dons sont perdus. ». A don given through « + Ajouter un don »
    whose house took no calendar (changed meanwhile, #155) says « N° 9 · 5 € en chèque ajouté,
    calendrier non compté » (« Porte 51 · … » on a door); « Annuler » takes the don back.
- **Retirer** (#148): the confirmation gets « Changer aussi le code » (« Léa connaît le code
  actuel. » under it), ticked by default; « Retirer » then also does « Nouveau code ».
- **A name per secteur, unique in it** (#148). The phone's prénom (5.1, 5.9) is the default name;
  each secteur may hold another one for the member. Names are unique within a secteur, case and
  accents ignored, checked by the server (an index `sectors/{id}/names/{normalized}`, create-only,
  freed on refuse, leave and remove). At the join, a taken name shows « ⚠ « Léa » est déjà pris
  dans ce secteur. Choisissez le nom que l'équipe verra ici. », the field « Votre nom dans ce
  secteur » and « Vos autres secteurs gardent « Léa ». ». Paramètres lists « VOS NOMS PAR
  SECTEUR » when one differs; a rename in « Votre prénom » applies where the name is free and keeps
  the old one elsewhere, saying so (« « Paul » est déjà pris dans le secteur 49 : vous y gardez
  « Paul D. ». Il est enregistré partout ailleurs. »), with a field for that secteur's name.
- Delivered in #148 (TeamRemove, JoinNameTaken, SettingsNameTaken mockups):
  - « Retirer Léa ? » is its own dialog (`team_screen.dart`, `_RemoveDialog`): the box
    « Changer aussi le code » with « Léa connaît le code actuel. » under it, ticked; the whole
    row toggles it. Ticked, `RemoveMember(…, renewCode: true)` first asks the secteur whether
    the removal holds, then does « Nouveau code » (needs the network) and only then removes:
    offline, or refused, nobody is removed and the snackbar says why.
  - The name's key is `MemberName.key` (`nameKey` of `french_text.dart`): the French accents
    of `searchKey` in both cases, œ / æ spelled out, dashes, apostrophes, dots, underscores
    and slashes as spaces, A–Z lowered, single spaces, trimmed (« LÉA » = « lea » = `lea`,
    « Léa B. » = `lea b`). Only A–Z are lowered because the rules' `lower()` lowers nothing
    else (measured in the emulator): « Ø » and « ø » stay two names. A name made only of
    separators (« - », « ... ») is refused as blank: its key would be empty.
  - Joining, renaming and an admin's « Rejoindre » need the network now (a transaction that
    reads the name's entry); offline they say « Pas de réseau. Réessayez une fois connecté. »
    as the other network-only commands. Accepting, refusing, removing and leaving still work
    offline, the name freed in the same batch.
  - The join screen, on a taken name, keeps the secteur's card (subtitle « Code K7P-2QX »)
    and replaces the scan and the code boxes with the alert, « Votre nom dans ce secteur »
    (filled with the name refused) and « Vos autres secteurs gardent « Léa ». »; a name typed
    that is taken too updates the alert. A code that stopped working meanwhile says « Aucun
    secteur n'a ce code… ».
  - Paramètres: « VOS NOMS PAR SECTEUR » under the offline line, before « Application », one
    row per secteur of the phone (requests included, admins' visits left out), not tappable,
    shown only when one name differs from the prénom. « Votre prénom »: the prénom is kept
    whenever one secteur took it or the member is in none; where it was taken, one alert for
    all such secteurs (one sentence each, then « Il est enregistré partout ailleurs. ») and
    one field « Votre nom dans le secteur 49 » each, filled with the name kept; « Enregistrer »
    then gives each changed field to its secteur alone (`ChangeSectorName`), or the prénom
    again if it was changed. Offline with the member active somewhere, nothing changes and
    the sheet says « Pas de réseau. Réessayez une fois connecté. ».
  - An admin's « Rejoindre » under a name a member holds: snackbar « Ce prénom est déjà pris
    dans ce secteur. Changez-le dans Paramètres pour rejoindre. ».
  - The members of before #148 hold no entry (no migration, single user): they are not
    protected until they rename, and the test secteurs are best created again.
- **Unreadable street** (#149): a street whose document cannot be read is a row of Accueil's list,
  « ⚠ Rue Pasteur » over « Illisible » (red; « Rue illisible » when the name cannot be read either),
  not on the map nor in the totals. A tap opens a sheet: the name, « Cette rue ne peut pas être
  lue : ses données sont abîmées. Elle n'apparaît ni sur la carte ni dans les totaux. », « Un
  administrateur peut la supprimer, puis l'ajouter de nouveau. » and, for admins, « Supprimer la
  rue » (outlined red).
  **Delivered (#149):** the Firestore listener keeps a document `streetFromDocument` refuses
  apart as an `UnreadableStreet` (domain value: its id, and its name when the `name` field alone
  is a `StreetName`), behind the `UnreadableStreets` port (`watchUnreadable`, `delete`) that the
  street adapter implements from the same listener, so it shows offline too.
  `ObserveUnreadableStreets` / `DeleteUnreadableStreet`; Accueil's rows are a sealed `HomeRow`
  (`StreetRow` | `UnreadableStreetRow`) in French order by name, nameless ones last. Never in
  `StreetRepository`, so not on the map, nor in « Rues · n/m », nor in Secteur's « RUES (n) ».
  Without a name the row is only « Rue illisible » (no « Illisible » under it). « Supprimer la
  rue » deletes the document at once, without a confirmation (the sheet is that step), memory
  first and queued offline; the existing rule `allow delete: if isAdmin()` on a street lets an
  admin do it, no rules change. « Administrateurs seulement » shows under the button, to admins
  only, as the mockup draws it. The streets download still leaves such a street out of the
  map's area; its document lands in the cache all the same, so the listener lists it.

### 5.17 À repasser: the list and the reminders (#82, built)

Agreed 2026-11-12 (ASCII in the terminal, then mockups HomeComeBack, ComeBackList,
ComeBackNotify, StreetRing, SettingsReminders). Reads the structured come-back of #81 (a day,
maybe an hour, §5.7).

```
  Accueil                          À repasser                       Rue (from a row or a reminder)
┌────────────────────────────┐   ┌────────────────────────────┐   ┌────────────────────────────┐
│ Secteur 49 · 2026 ▾     [⚙]│   │ ← À repasser (5)           │   │ ← Rue Nationale        [✎] │
│ ░░ map ░░░░░░░░░░░░░░░░░░░ │   │ 🔔 vous recevrez un rappel │   │ [9  ✓][11 ○] │ [10 ✗]      │
├────────────────────────────┤   │ AUJOURD'HUI                │   │              │╔═════════╗  │
│ Rues · 31/50               │   │ [19 h] 12 Rue Nationale 🔔›│   │ [13 ✗][15 ○] │║ 12    ↻ ║  │ ← ring ~2 s
│ [ ▶ Commencer une tournée ]│   │        par vous            │   │              │╚═════════╝  │
│ [↻] À repasser (5)       › │   │ [ ↻ ] 12 Rue des Lilas  🔔›│   │ [17 ○]       │ [14 ○]      │
│     Prochain : aujourd'hui │   │       par vous · pas d'heure   │ N° 12 · repasser aujourd'hui│
│     vers 19 h              │   │ DEMAIN                     │   │ vers 19 h                  │
│ Rue des Lilas ▓▓▓░ 31/42 › │   │ [18 h] 3 Allée des Pins 🔔›│   └────────────────────────────┘
└────────────────────────────┘   │ À TOUT MOMENT              │
                                 │ [ ↻ ] 5 Rue Pasteur      › │     Notifications (Android)
  Paramètres                     │  C'était hier vers 18 h ·  │   ┌────────────────────────────┐
┌────────────────────────────┐   │  par Léa                   │   │ ↻ Tournée Calendriers 18:45│
│ RAPPELS                    │   │ [ ↻ ] Porte 51 · 8 Rue     │   │ Repasser vers 19 h         │
│ Rappels pour repasser [● ] │   │       Pasteur · par Léa  › │   │ 12 Rue Nationale           │
│ 15 min avant l'heure ; à 9 │   └────────────────────────────┘   ├────────────────────────────┤
│ h quand il n'y a pas       │                                    │ ↻ Tournée Calendriers 09:00│
│ d'heure. Seulement les     │                                    │ 1 maison à repasser        │
│ vôtres.                    │                                    │ aujourd'hui                │
│ (blocked: Bloqués par      │                                    │ 12 Rue des Lilas           │
│  Android     [Réglages])   │                                    └────────────────────────────┘
└────────────────────────────┘
```

- **The list** is every ↻ of the open secteur: houses, doors and buildings with their own
  « Repasser », whoever set it, read from the phone's copy (offline too). Accueil shows the
  row « ↻ À repasser (5) › » under « Commencer une tournée » (during a tournée too, first in
  the panel under the band) only when there is at least one, with « Prochain : aujourd'hui vers
  19 h » under it (the earliest ↻ with a day from today on; nothing when none has one).
- **« À repasser (n) »** groups by day: « AUJOURD'HUI », « DEMAIN », then each later day
  (« SAMEDI 24 OCT. »), and **« À TOUT MOMENT »** last for a ↻ with no day *and* a ↻ whose
  day is gone (it reads « C'était hier vers 18 h », as on the sheet, §5.7). Within a day, the
  hours first in order, then those without an hour; ties by street and number. A row: a
  come-back-blue square with « 19 h » (or ↻ without an hour), the address (« 12 Rue
  Nationale », « Porte 51 · 8 Rue Pasteur », a building's own ↻ as its address), then « par
  vous » / « par Léa » (from the house's last change, the same naming as « Modifié par »,
  §5.7), « · pas d'heure » for a day without an hour; a 🔔 when this phone will ring for it
  (said « rappel prévu »). A tap opens the street at that house; a door opens its building's
  grid at that door.
- **At the house**: the street scrolls so the tile sits mid-screen and gets a pulsing ring in
  the come-back blue (`#1D4E7A`) for about 2 s; nothing opens; the hint pill reads « N° 12 ·
  repasser aujourd'hui vers 19 h » until the first tap. Marking still needs a tournée (5.14).
- **Reminders** are local notifications scheduled on the phone (`flutter_local_notifications`,
  no push, no server, offline). Only **the ↻ this member set** (the house's last change is
  theirs) in **the open secteur** ring this phone; a teammate's shows in the list only.
  - With an hour: one notification 15 min before (« Repasser vers 19 h », « 12 Rue
    Nationale »); a tap opens the street at the house.
  - A day without an hour: one notification at 9 h that day for all of them (« 1 maison à
    repasser aujourd'hui » / « 3 maisons … », the addresses); a tap opens « À repasser », or
    the street at the house when there is only one.
  - A time already gone, or a ↻ with no day, never rings.
  - Inexact alarms (Android may deliver them a few minutes late): no exact-alarm permission,
    which Play restricts. Rescheduled after a restart of the phone.
  - The schedule is worked out again from the streets whenever they change: a teammate who
    marks the house, changes its time or clears it cancels the reminder; switching secteur
    replaces them; leaving a secteur or the switch off cancels them all.
- **Permission**: Android 13+'s notification permission is asked the first time this member
  gives a ↻ a day (never at launch). Paramètres gets **« RAPPELS »** with the switch
  « Rappels pour repasser » (on by default) and « 15 min avant l'heure ; à 9 h quand il n'y a
  pas d'heure. Seulement les vôtres. »; refused by Android, the line reads « Bloqués par
  Android » (red) with « Réglages », which opens the app's notification settings.
- **Privacy** (§8.3): nothing leaves the phone; a notification shows an address and an hour,
  never a person.
- **Delivered (#82).** Domain (`lib/domain/come_back/`): `ComeBackEntry.allOf(streets)` reads
  every ↻ (house, door, building's own) with its `ComeBackPlace` and its setter (`setBy`, the
  last change); `ComeBackAgenda` groups and orders them; `ReminderPlan.of(entries, member:,
  now:)` is the schedule (`HourReminder` at the hour − 15 min, `DayReminder` at 9 h, each with
  its `ReminderTarget`: `OpenComeBackPlace` or `OpenComeBackList`); `DwellingKey.parse` reads a
  door back from its id. Application (`use_cases/reminders.dart`): `ObserveComeBacks`,
  `PlanReminders`, `ScheduleReminders`, `SwitchReminders`, `AskForRemindersOnce`,
  `ReadRemindersOn`, `ReadRemindersAllowed`, `OpenReminderSettings`, `FollowReminderTaps`;
  ports `ReminderScheduler` (adapter `LocalNotificationsScheduler` on
  `flutter_local_notifications`, `inexactAllowWhileIdle`, the plugin's boot receiver, the
  payload in `notifications/mappers/reminder_payload.dart`; « Réglages » through a method channel
  of `MainActivity`) and `ReminderPreferences` (`reminders.json`, §6.3). Presentation:
  `comeBacksProvider` (the list and the Accueil row), `remindersProvider` (« RAPPELS »),
  `reminderSyncProvider` (replaces the schedule at each change of the streets, the open secteur
  or the switch, one replacement at a time, kept alive by the app's root) and
  `reminderTapProvider` (the tapped reminder until the app opened it). The street opens with
  `/rue?id=…&numero=12` (`&porte=A5-51` for a door). Choices made while building: the 🔔 of a
  row follows the switch, not Android's permission (« Bloqués par Android » says that one in
  Paramètres); « vous recevrez un rappel » shows only when some row has a 🔔; a door opened from
  the list rings in its grid (staircase chosen, door scrolled into view) with no hint pill; a
  reminder whose time passes while the schedule is written is skipped; the list shows « Plus
  aucune maison à repasser. » when the last ↻ goes while it is open.

### 5.18 Street lines from IGN BD TOPO (#166, built)

Agreed 2026-11-13 from a phone test on a rural secteur. Overrides 5.3 (« Lines filled in the
background »), 5.4, 5.14 (a tap, « Zone ») and §6.1 (`StreetShapes`) where they disagree. No
screen changes, only the credits line and the privacy text.

**Why.** A street's line comes from the OpenFreeMap tiles (OpenStreetMap) **matched by name**
(#92, #125, #134), and OSM may be wrong where the BAN is right. Three cases seen, given here
with Villefranche names:
- **The name on the wrong way**: OSM names a footpath « Chemin des Vignes » while the BAN's three
  numbers sit at the end of a short track; the line is drawn across the gardens.
- **A misspelt name**: OSM says « Rue de le Paix », the exact shape lookup finds nothing, the
  street has no line (the tap tolerated it since #134, the shape did not).
- **Two BAN streets on one road name**: the BAN has « Rue de Gleteins » and « Gleteins » (a
  hamlet road). A tap on the hamlet road asks the geocoder, which answers the nearest numbered
  street, « Rue de Gleteins », so « Déjà dans le secteur » and « Gleteins » cannot be picked.

**IGN BD TOPO** (Géoplateforme WFS, free, no key, Licence Ouverte Etalab 2.0) has each road
segment (`BDTOPO_V3:troncon_de_route`) with **the BAN id of the street on each side**
(`identifiant_voie_ban_gauche` / `_droite`, the same `idVoie` as ours, e.g. `69264_1270`), its
BAN name (`nom_voie_ban_*`) and its commune (`insee_commune_*`). A street's line is then found
**by its BAN id, never by its name**. Checked 2026-11-13: a 60 m box answers in 0.15 s, a
500 m zone in 0.2 s (249 segments, 75 BAN ids, 47 segments without one: paths, unnamed tracks).

**What changes:**
- **A street's line** (`StreetShapes.shapeOf`): the BD TOPO segments carrying the street's BAN
  id on either side, joined where their ends meet (`joinLines`), not simplified (the caller
  simplifies, as today). Searched within the street's houses plus 2 km (built: a filter on the id
  alone takes 16–20 s on the WFS, no index; within a box 0.1–0.35 s, even 20 km across). **When BD TOPO has none** (a new estate
  IGN has not mapped yet, a road only named in the BAN), the OpenFreeMap tiles are asked by name
  as today (#92), around the houses; neither → no line, the house dots alone. Used everywhere a
  line is looked up: a tick on « Ajouter des rues » (`LookUpStreetShape`), the background fill of
  Accueil (`FillStreetShape`, 5.3), « Liste » and the zone's streets once added.
- **A tap on « Ajouter des rues »** (`LookUpStreet(StreetAtPoint)`): the BD TOPO segments within
  30 m of the finger are read; the nearest one carrying a BAN id gives the street (on a segment
  whose two sides differ, the side under the finger). Its name, commune and point come from the
  BAN lookup of that id, which also gives the numbers. No geocoder, no name search. With no such
  segment within 30 m, or BD TOPO unreadable, today's path stands (the geocoder, then the tiles'
  road names and `StreetName.typosFrom`, #134). The ✓ sits on that segment under the finger.
- **« Zone »** (`FindZoneStreets`): the BD TOPO segments in the rectangle, grouped by BAN id
  (one row per street, its BAN name and commune; no commune matching, no 3-commune limit). A
  named segment without a BAN id (`nom_collaboratif_*`) is a greyed « Aucune adresse connue »
  row as today. More than 50 streets, or more than 1000 segments in the rectangle (the WFS's
  `numberMatched`): « Zone trop grande : 50 rues au plus. » as today. Each ✓ sits half-way
  along the street's first segment inside the zone. Its line is looked up by id when ticked,
  like a tap, so a zone's street is stored with its whole line (no longer filled later).
- **The map itself** stays OpenFreeMap (style, offline region, weekly refresh): its labels may
  still show OSM's names; only our lines and dots change.
- **Credits** (5.9): « Carte © contributeurs OpenStreetMap, OpenFreeMap. Tracé des rues : IGN
  (BD TOPO). Adresses : Base Adresse Nationale. » (the licence asks for the source).
- **Privacy** (`privacyHostingBody`, `PRIVACY.md`): « Les cartes viennent d'OpenFreeMap et de
  l'IGN, les adresses de la Base Adresse Nationale : … » (the phone now asks the IGN for roads;
  it already asked the Géoplateforme for the geocoder).
- **No migration, no rules change.** Lines stored before stay as they are (a line is filled
  only while empty, §8.2). The user deletes the live secteur once this ships and creates it
  again (single user, decided 2026-11-13).
- **Offline unchanged**: lines are looked up only while adding a street or filling one,
  online; stored on the street, then drawn from the cache.

**Adapter.** `IgnStreetShapes` (`lib/infrastructure/geopf/`) behind the existing
`StreetShapes` port, with `OpenFreeMapStreetShapes` kept for the name fallback. The port takes
the BAN id (`shapeOf(banId:, name:, area:)`; the name and area serve the fallback only), and
`roadsIn(area)` answers `BanRoad`s (BAN id or none, name, INSEE code, shape) from BD TOPO. The
same failures (`noNetwork`, `serviceError`, `tooLarge`) and the 15 s timeout of the BAN adapter.
Requests (§9): `GetFeature`, `TYPENAMES=BDTOPO_V3:troncon_de_route`, `OUTPUTFORMAT=application/json`,
`SRSNAME=EPSG:4326`, `PROPERTYNAME` limited to the ids, names, INSEE codes and `geometrie`; by
id `CQL_FILTER=identifiant_voie_ban_gauche='…' OR identifiant_voie_ban_droite='…'`; by area
`BBOX=minLat,minLon,maxLat,maxLon,urn:ogc:def:crs:EPSG::4326` (latitude first) with `COUNT=1000`.
Fixtures captured on Villefranche-sur-Saône only.

**Delivered in #166** (`lib/infrastructure/geopf/ign_street_shapes.dart`,
`mappers/bdtopo_roads_mapper.dart`, fixtures in `test/fixtures/bdtopo/`):
- **The port** `StreetShapes`: `shapeOf(banId:, name:, area:)` (`banId` null for a street without
  one: by name only), `roadsIn(area)` → `BanRoad`s (BAN id or none, name, INSEE code or none,
  shape, `side`: `RoadSide.left | right` walking the line, null for both), and
  `namedRoadsIn(area)` → the map's `NamedRoad`s, kept for the tap's fallback (#134).
  `IgnStreetShapes` implements it; `OpenFreeMapStreetShapes` is now an infrastructure
  `RoadsByName` it falls back on. A BD TOPO failure is a failure (no OSM line stored for good
  while IGN is down); only an empty answer falls back.
- **Reading a stretch**: the same street on both sides → one `BanRoad` (`side` null); two
  streets → one per side; a BAN street on one side only → that side alone (the other is a
  verge, not a « Aucune adresse connue » row); no BAN id → one `BanRoad` by its own name
  (`nom_collaboratif_*`, left first), none when unnamed. The joined line: `joinLines` within
  1 m. `numberMatched` over 1000 → `tooLarge`.
- **A tap**: the stretches 30 m around; the nearest with a BAN id within 30 m, two as near (the
  two sides of one stretch) settled by `StreetShape.sideOf` (the side of the nearest segment).
  The secteur's street of that id gives its name and commune (no request); otherwise the BAN's
  numbers do. A BAN id the BAN no longer has (`notFound`) falls back to the geocoder path.
- **A zone**: the BAN streets are read in their communes' lists (`streetsOf`, one per INSEE
  code of the zone's stretches, by id) for the BAN's name, the commune's name and « 19
  numéros »; a BAN id the list lacks (or of a commune the BAN does not know, or without INSEE
  code) is a greyed « Aucune adresse connue » row under BD TOPO's name. Only BAN streets count
  towards the 50. A zone's street ticked asks its whole line by id (`LookUpStreetShape(match)`,
  around its ✓); the map draws its stretches in the zone until then, and they stay drawn if no
  line comes; « Ajouter » stores the whole line when it has come, none otherwise (Accueil fills
  it, 5.3).

## 6. Data model

### 6.1 Domain model (pure Dart: no Flutter, no Firebase, no MapLibre)

Strict DDD. Two aggregates match the two things people change independently; everything
inside an aggregate changes only through its root, which enforces the invariants.

| Aggregate (root) | Contains | Invariants it guards |
|---|---|---|
| `Sector` | `Member`s, `JoinCode`, `RescueCentre`, current campaign year, `SectorCommune`s (#78) | one creator; members are pending or active; only active members accept others; only the creator removes members, regenerates the code, starts a campaign; communes unique by INSEE code, 1–50 from creation, never the last one removed; no two members share a name, case and accents ignored (`MemberName.key`, #148: `rename` and `joinAsAdmin` refuse with `nameTaken`, the server checks the members the phone has not seen) |
| `Street` (one per campaign) | `House` entities, each with an optional `Building` → `Staircase` → `Floor` → `Dwelling` | numbers unique in the street; a building's status is derived, never set; deleting is soft (Corbeille) |

Value objects (immutable, validated at construction, equal by value): `JoinCode` (6 chars from
the alphabet), `RescueCentreKey` (normalised name), `SectorNumber`, `MemberName`,
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
- **À repasser and the reminders** (#82, `lib/domain/come_back/`, §5.17): read models worked
  out from the streets, never stored. **`ComeBackPlace`** (a street, a house number, maybe a
  `DwellingKey`) is where a ↻ is and where a tap leads. **`ComeBackEntry`** (place, street
  name, `ComeBack`, `setBy`: the `ChangeStamp` of the house, door or building) with
  `allOf(streets)`, `isSetBy(member)` and `byAddress` (street name the French way, number, the
  building before its doors). **`ComeBackAgenda.of(entries, today:)`**: `days` from today in
  date order (hours first, by hour, then without; ties by address), `anyTime` (no day, or a
  day gone), `count`, `next`. **`ReminderPlan.of(entries, member:, now:)`**: only the member's
  ↻; `HourReminder` at the day's hour − 15 min (`ahead`), one `DayReminder` per day without hour
  at 9 h (`dayHour`), none for a time already gone or without a day, in time order; `rings(place)`;
  `none` while the switch is off. Each `Reminder` has its `at` (the phone's local time), its
  `entries` and its `ReminderTarget` (`OpenComeBackPlace`, or `OpenComeBackList` for a day of
  several). `DwellingKey.parse(id)` reads `A5-51` back (null when it is not one).
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
`lib/domain/street/street_repository.dart`, `lib/infrastructure/local_storage/`; the phone
storage of streets was removed in #119, streets only living in a secteur since, §5.0, §6.3):

- **`House.position`** (`GeoPoint?`): where the entrance is, from the BAN; null for a number typed
  by hand or one the BAN gives no position. Every command keeps it (a renumbered house too).
- **Undo** (`Street.undo(change, by, at)`): puts back exactly what the change replaced and
  returns the change the undo makes, itself undoable. A house change (mark, « repasser », layout,
  door added / removed / renamed, back to a single house, renumbering) puts the **whole house**
  back, last change included → `HouseReverted(replaced, house, stamp)` (storage writes the whole
  house entry, deleting the old key when it renumbers back). A door change puts that door back →
  `DwellingReverted(…, stamp)`. The `stamp` is who undoes and when (`by`, `at`, from
  `UndoLastChange`'s `IdentityProvider` and `Clock`). `NumberRemoved` → restore; `NumberRestored` → removed again with its old
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
  with the M1 phone id. Creating or joining a secteur cannot stand in like that (the rules let
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
  (`infrastructure/geo_api/`, 10 s timeout), and since #137 `FallbackCommuneSearch`: it asks
  `GeopfCommuneSearch` (the Géoplateforme, one postcode per commune) only when
  `GeoCommuneSearch` fails, and fails with `noNetwork` only when both did. An entry without a valid `Commune` or a postcode
  that is not five digits is left out. Use cases `SearchCommunes` (nothing asked under two
  characters) and `FindImportedStreets` (BAN ids already on the phone, each `active` or `inCorbeille`).

Secteur rules fixed in T2.2 (`lib/domain/sector/`):

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
  `sectorKeys` id (§6.2).
- **`SectorNumber`** 1–9999 and **`CampaignYear`** 2000–2099: `create(int)` or `parse(text)`
  (digits only, spaces around and leading zeros ignored; `notANumber`, `outOfRange`).
  **`MemberName`**: trimmed, spaces joined, 1–30 code points (`blank`, `tooLong`).
  **`SectorId`** is opaque like the other ids.
- **`Member`** (entity): id (the uid), `MemberName`, `requestedAt` and `acceptance` (a
  `ChangeStamp`: `acceptedBy` / `acceptedAt`). Its status is derived: pending while
  `acceptance` is null, active otherwise; the creator accepted themself at creation.
- **`Sector`**: `Sector.createdBy(…)` makes a new one whose only member is its creator,
  active; `Sector.create(…)` rebuilds a stored one and fails with `duplicateMember` or
  `creatorNotActive` (the creator missing or pending). Members are sorted by request time, then
  id; `pendingMembers`, `activeMembers`, `memberOf`, `isCreator`.
- **Commands** return `(Sector, change)` or a `SectorCommandFailure`. The one acting must be
  in the secteur (`notAMember`) and active (`requestPending`), except to leave:

  | Command | Who | Refused when |
  |---|---|---|
  | `accept(member, by, at)` | any active member | `unknownMember`, `alreadyActive` |
  | `refuse(member, by)` | any active member | `unknownMember`, `alreadyActive` |
  | `remove(member, by)` | the creator (`notCreator`) | `unknownMember`, `creatorStays`, `memberPending` (refuse it instead) |
  | `leave(by)` | any member but the creator; a pending one cancels their request | `creatorStays` |
  | `regenerateCode(by, random)` | the creator | — (draws again if it gets the old code) |
  | `delete(by)` | the creator | — |
  | `rename(name, by)` | any active member, for themself only (no member parameter) | — |

  **The creator can neither leave nor be removed** (the secteur would have nobody to run it):
  they delete the secteur instead.

  **From #75 (5.12) the commands take who acts as an `Actor`** (the member id and whether they
  are an admin) instead of checking the creator: `accept` / `refuse` by an active member or an
  admin; `remove(member, by)` by an admin (`notAdmin`) on any other active member, admins
  included; `leave(by)` by any member, the creator too (`creatorStays` and `notCreator` go);
  `regenerateCode` and `delete` by an admin (`notAdmin`), member or not; a new
  `joinAsAdmin(member, at)` adds an admin who is not in it as active at once, accepted by
  themself (`notAdmin`, `alreadyMember`) → `AdminJoined`; `rename` unchanged. `notAMember` /
  `requestPending` stay for a non-admin. `Sector.create` no longer requires the creator
  among the active members (they may have left); `createdBy` stays as information only.
  `MemberStatus` gains `visiting` for a `SectorSummary` (an admin who opened a secteur they
  are not in); `Member` itself stays pending / active. `SectorLoss` gains `adminRevoked`.
  Ports: **`AdminStatus`** (application) `watchIsAdmin()` (false until read; any signed-in
  uid) and `isAdmin(uid)` for the « · admin » labels; `MemberAccount` exposes the uid for
  « Identifiant de l'appareil »; `SectorDirectory.watchAllSectors()` gives the rows of
  « Tous les secteurs » (id, number, centre, campaign, active-member count, pending count,
  whether the caller is active), `noNetwork` when the server cannot answer.

  Delivered in #75: **`Actor(member, isAdmin)`** (`lib/domain/sector/actor.dart`) is taken by
  `accept`, `refuse`, `remove`, `regenerateCode`, `delete` and `joinAsAdmin(by, name, at)`;
  `leave(by)` and `rename(name, by)` keep a `MemberId` (being an admin changes nothing for
  them). A non-admin hears first what keeps them from acting at all (`notAMember`,
  `requestPending`), then `notAdmin`; `joinAsAdmin` checks `notAdmin` before
  `alreadyMember`. An admin may `remove` themself (it is a leave; no failure was specified).
  `NewSectorFailure` keeps only `duplicateMember`; `Sector.creator` and `isCreator` are
  gone. `AdminJoined` is a `MemberChange`; storage first asks the server for the secteur
  (offline: `SectorWriteFailure.noNetwork`), then sends the member document like the other
  member writes. **`AdminStatus`** (application port): `watchIsAdmin()` and `Future<bool>
  isAdmin(uid)` (false when it cannot tell); the use cases read the phone's flag with
  `watchIsAdmin().first` (false until known). `MemberAccount` needed no change: its
  `signedInMember` is the uid. The directory method is **`allSectors(caller)`**, one read
  of the server (a `Future`, not a stream: the screen reads it when it opens). For a
  `visiting` summary, `watchMembership` follows the secteur document (gone on the server →
  `deleted`) and the phone's own `admins/{uid}` (gone on the server → `adminRevoked`) instead
  of the member document. Use cases (`lib/application/use_cases/admins.dart`, `team.dart`):
  `ObserveAdminStatus`, `IsMemberAdmin`, `ListAllSectors` (signs in first), `OpenAsAdmin`
  (kept active when the admin is in it, `visiting` otherwise, then opened), `JoinAsAdmin`
  (the phone's name; none → `TeamProblem.noName`; then the summary accepted), `ForgetVisitedSector`.
  Presentation: `adminProvider` (kept alive, false until known or on error), `deviceIdProvider`
  (on `accountProvider`, so the screen showing it signs in), `allSectorsProvider`;
  `TeamShown` has `iAmAdmin`, `iAmIn` and `MemberRow.isAdmin` (each other member asked
  once), `TeamActionFailure.noName`.
- **Changes** (`SectorChange`, sealed): `MemberAccepted` (the member as accepted),
  `MemberRefused`, `MemberRemoved`, `MemberLeft` (the member as they were), `MemberRenamed`
  (the member with the new name; storage writes `displayName` only),
  `JoinCodeRegenerated(before, code)`. `delete` returns a `SectorDeleted` holding the whole
  secteur (storage needs its code, centre and number to free them); it is not a
  `SectorChange`.
- **Port `SectorRepository`** (domain): `find(id)`, `watch(id)` (null when there is no such
  secteur or this member may no longer read it), `add(sector)` → `AddSectorFailure`
  (`alreadyExists`, `noNetwork`), `save(sector, change)`, `delete(SectorDeleted)` (from T2.6 both return
  `SectorWriteFailure.noNetwork` for what needs the server, see below). A pending
  newcomer cannot read the secteur (§8.2), so the join (code lookup, request) goes through the
  `SectorDirectory` port (Q20), not this one.

« Mes secteurs » fixed in T2.7 (`lib/domain/sector/`, `lib/application/`):

- **`SectorSummary`** (value): what the phone keeps of one of the member's secteurs — id,
  number, centre, campaign, `MemberStatus` (pending while the request waits; for a request,
  what the join preview showed, since a pending newcomer cannot read the secteur).
  `accepted()` gives it active. Since #148 it keeps `memberName`, the name the member goes
  by there (the prénom unless it was taken; null for a summary kept before, or an admin's
  visit, read as the prénom), changed with `withMemberName`. `ChangeMemberName` gives the
  prénom to every active secteur where it is free and returns where the old name is kept
  (`NameChanged.kept`); `ChangeSectorName` renames in one secteur; `CatchUpMemberName` sends
  the summary's name (or the prénom) and, where it turns out taken, keeps the server's.
- **`MySectors`** (value): the summaries in the order the phone met them, each id once, and
  `currentId`, the open one, always an active one of the list. `none`; `remember(summary)`
  adds at the end or replaces in place, never opens (the open one stays while « Créer » /
  « Rejoindre » run), and closes the open one should it come back pending; `open(id)` →
  `OpenSectorFailure` (`unknownSector`, `requestPending`); `forget(id)` drops it, leaving
  none open when it was the open one (which to open next is the member's choice).
- **Port `MySectorsStore`** (application): `mySectors` (sync, loaded at start-up),
  `changes` (each list saved), `save`. Use cases `ReadMySectors`, `ObserveMySectors`,
  `OpenSector` (writes nothing when already open), `WatchJoinRequest` (`SectorDirectory.
  watchRequest` as `MemberAccount.signedInMember`; nothing before the first sign-in) and
  `SettleJoinRequest` (active → the summary accepted, not opened; null → forgotten; pending or
  not a request → nothing). `MySectorsNotifier` (kept alive) follows each pending request
  while the app runs (a failing listener leaves it pending); `currentSectorProvider` is the
  open secteur the screens of a secteur follow. From T2.6c it also follows the team
  (`ObserveTeam`) of each active secteur not open: `SectorRow.waitingRequests` (0 when it
  cannot be read).
- **A secteur lost** (T2.6c): **`SectorLoss`** (domain enum) `removed` | `deleted`.
  `SectorDirectory.watchMembership(summary, member)` emits once the server says the member is
  no longer in it, never from the phone's copy nor for a deletion made on this phone.
  `WatchMembership` (as `MemberAccount.signedInMember`, nothing before the first sign-in);
  `ForgetLostSector(id, loss)` → `LostSector(summary, loss, wasOpen)` after `forget`, or
  null (unknown any more, or still a request: nothing saved). `SectorLossNotifier` (kept
  alive, listened to by `TourneeApp`) follows each active secteur of « Mes secteurs » (a
  failing listener keeps it; on a phone that never signed in, it starts again on the secteurs
  kept then once `ObserveSignIn` tells a sign-in, T2.6e) and gives a
  `SectorLossNotice(sector, number, loss, wasOpen)`;
  the app shows the message on its `ScaffoldMessenger` and goes to the start screen when it
  was the open one.
- **A name to catch up** (T2.7c): `SectorDirectory.watchOwnName(sector, member)` emits the
  name the server holds on the member's own document while it is active (never from the
  phone's copy, a pending request, or a snapshot with `hasPendingWrites`). `WatchOwnName` (as
  `MemberAccount.signedInMember`, nothing before the first sign-in; `distinct`, so a rename
  the server refused is not sent in a loop) and `CatchUpMemberName(sector, heard)`: when the
  phone's `MemberName` differs from the one heard, the same `Sector.rename` as « Prénom »;
  equal cleaned names, no name on the phone, an unreadable secteur or a refused rename send
  nothing. `SectorLossNotifier` listens to it for each secteur it follows, so a rename made
  while the request waited reaches the team once accepted, with no rules change.
- **Port `PhoneSettings`** (application): `memberName` (null until given), `theme`
  (`ThemeChoice` system / light / dark), setters. Use cases `ReadPhoneSettings`,
  `ChangeMemberName` (`MemberName.create`, nothing kept when refused), `ChooseTheme`.

Onboarding fixed in T2.5 (`lib/application/use_cases/choose_start_point.dart`,
`create_sector.dart`, `join_sector.dart`, `lib/presentation/`):

- **`ChooseStartPoint`** (`MySectorsStore`, the phone's `StreetRepository`): `StartOnStreets`
  | `StartOnWelcome` | `StartOnRequest(summary)`, in the order of §4. It takes the first value
  of `watchAll` / `watchDeleted` without waiting for the stream to be let go. Also where the
  app goes once a request is refused or cancelled. `launchPlaceProvider` (a `FutureProvider`
  read once) gives the router its first location; `TourneeApp` shows the bare ground until
  then.
- **Créer:** `ListRescueCentres`, `CheckSectorTaken` (the directory, `noNetwork`) and
  `CreateSector(centre, number, campaign, creatorName)`: `signInIfNeeded` (its `noNetwork`
  → `CreateSectorFailure.noNetwork`), `Sector.createdBy` with an `IdGenerator` id, a
  `JoinCode.generate` from the bound `Random` and the `Clock`, `SectorRepository.add`
  (`alreadyExists` | `noNetwork`), then the summary remembered **and opened**; returns the
  secteur as stored (its code possibly replaced).
- **Rejoindre:** `PreviewJoin` (the directory), `RequestToJoin(preview, name)`: a secteur
  already in « Mes secteurs » → `alreadyJoined` (asking again would turn an active member
  back into a request); else `signInIfNeeded` (→ `noNetwork`), the pending `Member` stamped
  with the `Clock` sent with `requestToJoin`, and the preview remembered as a pending
  summary. `CancelJoinRequest(sector)`: `cancelRequest` as the signed-in member (none: only
  forgotten), then `forget`.
- **Following a request:** « Mes secteurs » (`MySectorsNotifier`, T2.7) already follows and
  settles each pending request; `JoinRequestNotifier` (family by secteur) watches it:
  `RequestWaiting(number, centre, canLeave)` | `RequestAccepted` (after `OpenSector`) |
  `RequestClosed(refused, next)` | `RequestUnknown`. A request gone while shown is refused
  unless « Annuler » was pressed; one gone before the screen opened is not called refused.
  `FirestoreSectorDirectory.watchRequest` tells nothing for a snapshot of the phone's copy
  without the document (`metadata.isFromCache`, `requestStatusesIn`): only the server can say
  a request is gone, so an offline start never drops it.
- **Presentation:** `WelcomeNotifier`, `NewSectorNotifier` (duplicate check after
  `duplicateCheckDelayProvider`, 300 ms; answers about older input dropped) and
  `JoinSectorNotifier` (late previews dropped) each wait for `AccountSignedIn` before asking
  the server, so after an offline first start « Réessayer » is enough, no restart.

Équipe and Corbeille fixed in T2.6 (`lib/application/use_cases/team.dart`,
`observe_corbeille.dart`, `lib/domain/street/corbeille.dart`, `lib/presentation/`):

- **Use cases** of Équipe, each acting as `IdentityProvider.currentMember` (the secteur's root
  checks they may): `ObserveTeam` (`SectorRepository.watch`), `ReadCurrentMember`,
  `AcceptMember` (stamped with the `Clock`), `RefuseMember`, `RemoveMember`, `LeaveSector`
  and `DeleteSector` (both then `forget` the secteur in « Mes secteurs »),
  `RegenerateJoinCode` (draws from the injected `Random`, `Random.secure()` in the app;
  returns the code as stored). Refusals are `TeamFailure` = a `TeamProblem` (`sectorGone`: cannot be
  read, `offline`, `noName`, `notAdmin`) | `TeamCommandRefused(SectorCommandFailure)`.
- **`SectorRepository.save`** returns the secteur as stored and **`delete`** the deletion,
  or `SectorWriteFailure.noNetwork` for what needs the server: a new code (the transaction)
  and deleting (which first reads the secteur from the server, so offline it fails before
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
- **Presentation:** `teamProvider` (kept alive, follows `currentSectorProvider`):
  `NoTeam` | `TeamLoading` | `TeamUnavailable` | `TeamShown` (number, centre, campaign, code,
  `qrData`, `iAmCreator`, `RequestRow`s, `MemberRow`s with `isMe`, `isCreator`, `canRemove`;
  `waitingRequests` for the dot); commands answer `TeamActionFailure` `teamChanged` |
  `offline`. `corbeilleProvider` (auto-disposed) names `by` through the team. `RecentTime`
  (`JustNow`, `MinutesAgo`, `HoursAgo`, `Yesterday`, `OnDay`) on the phone's calendar.
- **Firestore settings** (PLAN §7) are applied in one place, `bootstrap/firebase.dart`
  (`offlineFirestore`: persistence on, `CACHE_SIZE_UNLIMITED`), before the database's first
  use and once per process; `bindAdapters` asks for the database once, lazily, for every
  Firestore adapter.

Streets on Firestore fixed in T2.8 (`lib/bootstrap/bindings.dart`, `lib/presentation/`):

- **Binding.** `streetRepositoryProvider` follows `currentSectorProvider` (its id and
  campaign only): a `FirestoreStreetRepository` of the open secteur's current campaign,
  closed (`onDispose`) when another secteur or none is opened; while none is open, a
  stand-in with no street whose writes fail (#119: streets only live in a secteur). Every use
  case watches it, so it is built again with the new storage. A Riverpod 3 notifier is
  **kept** when it builds again (only its `ref` is new): notifiers reset what they read in
  `build` (`FollowsStreet`, Accueil), the kept undo change remembers the `ref` it was
  made under and is dropped once that `ref` is no longer `mounted`, and the Corbeille waits
  while its stream reloads (`isLoading`) rather than showing the old secteur's items. A
  stream that fails (the member may no longer read the secteur) shows no street, or the
  street as gone.
- **Pending sync** (T2.9): `pendingSyncProvider` follows the same rule through one private
  provider of `bindAdapters` (the open secteur's `FirestoreStreetRepository`, or null): the
  very adapter bound as the street repository, so one listener serves both; while no
  secteur is open, a stand-in that always says 0. `ObservePendingSync` hands the count to
  `PendingSyncNotifier` (`AllSent` / `ChangesWaiting(streets)`; a failed stream shows
  nothing).
- **Size.** One `set` per street with its first houses, then the others 2 per update (#70,
  8.2 « Houses written in bulk »): a street of 300 numbers is ≈ 150 writes. Each house is
  checked by the rules, its stamps the caller's; the doors of a
  building are only counted. The 1 MB document limit is far off (a street of 1 500 numbers
  and a 500-door building ≈ 300 kB).

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
- **`ProgressLevel.of(progress)`**: `done` when every door is done or refused and nothing is
  left to come back to (no building « repasser »); otherwise `toDo` when every door is to do,
  `partial` when any door was visited (« personne » and « repasser » count as visited, not
  done). A street without any door is never done. (`free`, « libre », went with 5.14.)
- **`MapLayers.of(streets)`**: a `StreetLine` (street id, shape, level) per street with a
  shape and a `HouseDot` (street id, number, position, `HouseDotStatus`) per house with a
  position, streets in the Corbeille left out. A single house's dot shows its status; a
  building's shows `comeBack` when it has its own « repasser », otherwise `toDo` / `partial` /
  `done` from its doors. Dots show from zoom 16 (`MapLayers.houseDotsMinZoom`).
- **`PickedRoad(street, road, mark)`** (#124): a street ticked on « Ajouter des rues » as the
  map draws it, its BAN id, its road (`StreetShape.none` until the map's tiles give it) and
  where its ✓ disc sits (for a tap, the point of the road under the finger nearest to it,
  #132). A tap on the road or the ✓ names the BAN id.
- **`sectorArea(streets)`**: the `GeoBounds` (south, west, north, east; never across the
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
  `notFound` only when it answers nothing (or nothing readable). Since #134 `LookUpStreet` does
  not trust it alone for a tap: see 5.14 (« the road under the finger »).
- **`AddressDirectory.searchStreets(text, commune:)`** → the `StreetMatch`es of one commune, best
  first, at most 10 (one call per commune of the secteur). The text is trimmed and cut before its
  first letter or digit; under 3 or over 200 characters (counted as code points) it finds nothing
  without a request (the service refuses it with HTTP 400). Same failures as the BAN lookup
  (`noNetwork`, `notFound` on 404, `serviceError`); an unreadable feature is left out. One
  adapter, `BanAddressDirectory`, serves the four calls (same timeout, 15 s).
- **Since §5.18 (#166) a tap asks IGN BD TOPO first** (`StreetShapes.roadsIn`): the geocoder
  and the search by the map's road name are only its fallback.
- **Port `StreetShapes.shapeOf(banId:, name:, area:)`** (#92, by BAN id since §5.18) →
  `StreetShape`, **not simplified** (the caller calls `simplified()` before storing),
  `StreetShape.none` when no road matches; `StreetShapesFailure.noNetwork` (no answer in time,
  no way out) | `serviceError` (a refused or cut connection, any status but 200, an unreadable
  answer). **`IgnStreetShapes`** (`lib/infrastructure/geopf/`, 15 s, 8 MB) asks the BD TOPO
  stretches carrying `banId` on either side within the **area** plus 2 km
  (`idSearchMarginMetres`), joined within 1 m; none (or no `banId`) → the map's roads by name
  (`RoadsByName`, `OpenFreeMapStreetShapes` below) in the **area**: `shapeSearchArea(positions)`,
  the street's house positions (and, for a street to add, the BAN's point of the street) plus
  150 m, so a road of the same name in the next commune is left out. The **name** matches by
  `StreetName.matches`: the same `searchKey` (case, accents, `œ`, apostrophes and hyphens read
  as spaces), whole name only.
- **Port `StreetShapes.roadsIn(area)`** (§5.18) → the `BanRoad`s of the BD TOPO stretches in
  the area (`BBOX`, `COUNT=1000`; `tooLarge` past 1000 matched), see 5.18 « Delivered ».
- **The adapter `OpenFreeMapStreetShapes`** (a `RoadsByName` behind `IgnStreetShapes` since
  §5.18; 10 s per request) reads the TileJSON
  `https://tiles.openfreemap.org/planet` once for the tile address (its first `tiles`
  entry, with the weekly version of the map in it; forgotten after a tile is refused), then
  the **zoom-14** tiles covering the area (at most 16, else no shape), one after the other,
  and keeps the named lines of the last 64 tiles in memory. Each tile is a Mapbox Vector Tile
  (protobuf, read by a small hand-written decoder: `mappers/protobuf_reader.dart`,
  `vector_tile.dart`; a gzipped body is uncompressed); the **`transportation_name`** layer
  gives the named roads (`name`). The lines of the name are cut to their tile (each tile
  repeats a strip of its neighbours), cut to the area (`clipLine`), and joined where their
  ends meet within 1 m (`joinLines`), across tiles too. A 204 is an empty tile.
- **Port `StreetShapes.namedRoadsIn(area)`** (#125's `roadsIn`, renamed in §5.18; now only a
  tap's fallback) → the `NamedRoad`s (the map's name, the shape) running through the area, one
  per name in the order the tiles give them, each cut to its tiles but not to the area
  (`namedRoadsFromTiles`); a blank name is left out. The same tiles, memory and failures as
  `shapeOf`; more than 16 tiles gives `tooLarge`.
Street picking fixed in T3.3 (`lib/domain/street/street.dart`, `lib/application/use_cases/`):

- **No attribution** (5.14, #120): a street belongs to no member; every member of the secteur
  covers all of its streets. `Street.assignees`, `take` / `release`, `StreetTaken` /
  `StreetReleased`, `AssignmentFailure`, `TeamRoster` (#91), `TakeStreet` / `ReleaseStreet`,
  `MyStreets` / `ObserveMyStreets` and `StreetsByMember` / `ObserveStreetsByMember` (#105) are
  gone.
- **`LookUpStreet(StreetLookup)`** — `StreetAtPoint(GeoPoint)` (a tap: BD TOPO by BAN id, else the geocoder, §5.18) or
  `FoundStreet(StreetMatch)` (a search result) — tells what a street tapped or picked on
  « Ajouter des rues » is (5.14):
  `StreetOfTheSector(match, street)` when the secteur has its BAN id out of the Corbeille (its
  numbers are not asked), otherwise `StreetToAdd(match, numbers)` with the BAN's numbers and
  positions (`numberCount`). Failures are the `AddressDirectoryFailure`s: `notFound` (no BAN
  match), `noNetwork` (offline), `serviceError`. Changes nothing.
- **`AddStreetFromMap(numbers, shape:)`** stores a `StreetToAdd`'s street (« Ajouter N
  rues » calls it once per street ticked, #124) with the road found for its tick
  (`LookUpStreetShape`, simplified), or without shape while it has none: since #92 it **never asks the map nor waits for it**. A street of the Corbeille with
  that BAN id comes back with its marks instead. `AddStreetFailure.alreadyInSector` and `serviceError` (the BAN gave a number
  twice).
- **`LookUpStreetShape(match, numbers:)`** (#92; a `StreetMatch` since §5.18, so a zone's
  street asks too): the line of its BAN id, else the road named so around the street's numbers
  (none yet for a zone's) and its point, simplified. **`FillStreetShape(streetId, road:)`** (#92):
  a street that needs a shape gets the road given, or else the line of its BAN id, else the
  one the map draws around its houses, simplified, through `Street.fillShape` (read again after the map answered: a teammate's
  phone may have filled it); `ShapeFillOutcome.filled | noRoad | notNeeded`, or the
  `StreetShapesFailure`.
- **`AddManualStreet(name, commune, numbers)`** (« Rue à la main »): `Street.manual`, offline.
- **`SearchStreet(text, communes:)`**: `AddressDirectory.searchStreets` for each commune in turn
  (the secteur's communes, which #78 stores; #31 passes them in), results in commune order, a
  BAN id listed once; the first failure fails the search; no commune → nothing, no request.

Communes of a secteur fixed in #78 (`lib/domain/sector/`, `lib/application/use_cases/team.dart`):

- **`SectorCommune`**: a `Commune` (INSEE code + name) and an optional `GeoPoint` centre, the
  one geo.api.gouv.fr gives at pick time (`CommuneMatch.centre`, from its `centre` field,
  `[longitude, latitude]`), equal by value. `Sector.communes` keeps them in the order added,
  read-only.
- `Sector.createdBy(…, communes:)` takes one to `maxCommunes` (50) communes of different codes
  (anything else throws an `ArgumentError`: « Nouveau secteur » never sends it).
  `Sector.create` (storage) takes none to 50 (`duplicateCommune`, `tooManyCommunes`), so a
  secteur created before #78 reads with none.
- **Commands** (any active member or admin, like answering a request): `addCommune(commune,
  by:)` → `CommuneAdded` (refused `communeAlreadyIn` by INSEE code, `tooManyCommunes`);
  `removeCommune(code, by:)` → `CommuneRemoved` with the commune as stored (refused
  `unknownCommune`, `lastCommune`). Use cases `AddCommune`, `RemoveCommune` (offline, queued)
  and `ObserveSectorCommunes(id)` (the communes now and on each change of them, not of the
  team; none while the secteur cannot be read). `CreateSector(…, communes:)`.
- **Map area**: `communesArea(communes)` = the centres plus 2 km (`communeMarginMetres`), null
  without centre; `addStreetsArea(communes, streets)` = that, else `sectorArea(streets)`.

Accueil fixed in T3.5 (#30, `lib/presentation/home/`), one list since 5.14 (#120):

- **`ObserveStreets()`** gives every street of the secteur in French order, Corbeille left
  out, now and on each change, offline. Accueil's rows (`StreetRow`: name, doors visited of
  doors) and its « Rues · 31/50 » add up every street; a visiting admin sees the same.
- **`homeArea(communes, streets)`**: `sectorArea(streets)`, else `communesArea(communes)`.
  Accueil decides it once, when the streets are first read, so a street added meanwhile
  never moves the map. `MapLayers.showsHouseDots(zoom)`: zoom ≥ 16, when the legend explains
  the dots.

Firestore adapters fixed in T2.3 (`lib/infrastructure/firestore/`, `lib/application/ports/`):

- **Port `SectorDirectory`** (application, Q20): what someone outside a secteur asks of the
  server. `preview(JoinCode)` → `JoinPreview` (code, secteur id, number, centre, campaign: what
  « Rejoindre » shows) or `JoinFailure` (`unknownCode`, `noNetwork`); `requestToJoin(preview,
  member)` stores the newcomer's pending member document; `watchRequest(sector, member)` →
  pending, active, or null once refused or cancelled; `cancelRequest`; `watchMembership(summary,
  member)` (T2.6c: the member's own document, which the rules always let them read; once the
  server has it no more — not `isFromCache`, not `hasPendingWrites` — the secteur
  `sectors/{id}` read from the server tells why (#147, `lossFromSectorRead`): refused (it is
  there, without them) or there (an admin) is `removed`, not there is `deleted`; a
  `permission-denied` on the member's own document is passed on as an error, never taken as
  a loss; until #147 the reservation `sectorKeys/{key}` told it, which only admins read now);
  `watchOwnName(sector, member)` (T2.7c, the same document); `isTaken(centre,
  number)` and `rescueCentres()` (sorted by name) for « Créer », failing with
  `DirectoryFailure.noNetwork` (`isTaken` also with `notAdmin` once refused, #147). The code, the number and the centres are asked of the server,
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
- **`FirestoreSectorRepository`**: creating a secteur and a new code run in a **transaction**
  (needs the server, fails at once offline with `noNetwork`, sees a number or code taken at the
  same second). A join code another secteur already holds is replaced by a new one drawn from
  the injected `Random` (up to 10 draws, then a `StateError`): `add` returns the secteur as
  stored. Accepting, refusing, removing and leaving are queued like street writes. Deleting
  reads the campaigns, streets and members from the server and deletes the campaigns and
  streets in batches of 500, then the members (the creator's last) with the secteur, its code
  and its reservation in one batch, so a member's phone sees its membership and the
  reservation go together and says « supprimée », not « retiré » (T2.6c).
- **Undo is stamped with who undoes, now** (`HouseReverted`, `DwellingReverted`): the adapter
  writes the change's `stamp` (decided by `UndoLastChange`) as `by` / `at`, not the old stamp,
  since the rules accept only the caller's uid (§8.2). The domain's undo still puts the exact
  house back; the stored one carries the new stamp, which the listener then shows.
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
  final StreetPart part;                   // #133: what this secteur holds, per side;
                                           //   StreetPart.whole by default
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
  // part (#138): housesLeftOutBy(part), changePart(part, fromDirectory:) → StreetPartChanged
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
                               NumberRenamed, StreetRenamed, StreetPartChanged (#138),
                               HouseReverted, DwellingReverted (undo, T1.6) */ }
```

Domain services (pure functions, the bulk of the unit tests): house-number parsing and
ordering, odd/even split, manual range expansion (`1..57`, odd, extras, `21-25`), building
layout generation (staircases × floors × doors, `51` / `5A` styles), join-code generation and
normalisation, rescue-centre name normalisation, campaign roll-over (copy / reset rules),
**map layers as plain data** (street lines with a level, house dots with a status), secteur
bounding box for the offline download, shape simplification (Douglas–Peucker).

Repository **ports** live in the domain (`SectorRepository`, `StreetRepository`); they take
and return aggregates and `StreetChange`s, never Firestore types.

**Tournées (#63; domain and phone storage built in #108)** — `lib/domain/round/`:

- **`PaymentMethod`**: `cash`, `cheque`, `card`.
- **`Amount`**: whole euro cents, 1 to 100 000 (0,01 € to 1 000 €); `parse(text)` takes « 7,50 »,
  « 7.5 », « 7 » (refusals: empty, not a number or 0, more than two decimals, too large).
- **`Donation`** (sealed value): `Donation.paid(method, amount)` (`PaidDonation`) or
  `Donation.free()` (`FreeCalendar`, « Calendrier offert »). **No house, no time** on purpose
  (§8.3).
- **`MethodTotal`** (value): a count and a sum of cents. **`DonationTotals`**: the three
  `MethodTotal`s and the free count; `count` and `cents` are the paid dons only (« 19 dons ·
  280 € »), a free calendar counts in `free` alone.
- **`Round`** (aggregate, the open tournée on the phone): id, secteur, campaign, `startedAt`,
  `housesVisited` and the list of `Donation`s in the order added; **no member field**: it lives
  on the member's own phone, one at a time (`open_round.json` names none either). `add`,
  `replace(index)`, `remove(index)` (`NoSuchDonation` for an index past the list), `visited()` /
  `unvisited()` (never below 0), `totals`, `validate(at)` → `UnsentRound` (its `RoundSummary`
  ending at least one second after the start: the rules want `startedAt < endedAt`, whatever the
  phone's clock did).
- **`UnsentRound`** (value, #143, #155): a tournée « validated, not yet sent »: secteur, campaign,
  `RoundSummary` and an `UnsentState` (`waiting`: offline or not yet answered; `refused`: the
  server's rules refused it); `refused()` and `retried()`. Kept on the phone until the server has
  the summary; several may wait, and a new tournée may start meanwhile.
- **`RoundVisit.of(change)`** (domain service): what a `StreetChange` does to « maisons
  visitées »: a house or door going from not visited to ✓ / ⊘ is `visited`, the other way
  `unvisited`, anything else `none` (✓ → ⊘ stays counted once); `undone` turns it around.
- **`RoundSummary`** (value): its round's id (the document id, so a second send makes no
  second tournée), start, end, houses visited and the `DonationTotals`; **no member**, nothing
  else leaves the phone. `Collecte.of(summaries, {unsent})`: the tournées newest first and their
  totals summed per method for the secteur (never per member); this phone's `UnsentRound`s apart,
  newest first, out of the totals, and a summary whose tournée still waits left out of the sent
  ones (the phone's copy of the server may show it before the server confirms it).
- **`VisitStatus.refused`** (⊘): counts as visited in `Progress` and `ProgressLevel` (with done),
  resets the tries, never has a `ComeBack`.
- **`House.calendars`** / **`Dwelling.calendars`** (`0..99`): 1 when a house becomes ✓, 0 on any
  other status; `+1` through « + Ajouter un don », `−1` (not below 1) through « − ». No amount.
  Built in #114: the value object `Calendars` (`lib/domain/street/calendars.dart`, `keptBy(status,
  calendars)` run by the `House` and `Dwelling` factories, `more` / `fewer`); a building itself
  has none. `Street.addCalendar(number, {door})` and `Street.removeCalendar(number, {door})`
  return a `HouseCalendarsCounted` or `DwellingCalendarsCounted` (stamped, undone like any house
  or door change, `RoundVisit.none`), refused with a `CalendarChangeFailure` (`notDone`,
  `lastCalendar` at 1, `tooMany` at 99, or the house / door not found). `AddDonation(donation,
  {calendarFor})` adds the don first, then the calendar to the `CalendarPlace` (street, number,
  door?), and returns an `AddedDonation` (the tournée and the calendar's change; when the house
  took none, `calendarRefused` says why, a `CommandFailure<CalendarChangeFailure>`, #155: the money
  stays); `RemoveCalendar(place)` never touches a don.
- Use cases: `StartRound` (an active member of the open secteur, not a visiting admin, no
  tournée already on), `WatchOpenRound(openSector)` (the tournée on, only when it belongs to the
  secteur shown), `AddDonation` (with or without a house: with one, `calendars + 1` too, #114),
  `ChangeDonation`, `RemoveDonation`, `ValidateRound` (the `OpenRoundStore` port moves the tournée
  on to its `UnsentRound`s in one write, #143), `SendUnsentRounds` (started with the app: sends each
  waiting `UnsentRound` through the `RoundLedger` port, once at a time per tournée; the server
  keeps it → forgotten, refuses it → kept as refused; the port's `record` answers `LedgerAnswer.kept`
  or `refused` once the server has spoken, waiting offline; its `watch(sector, campaign)` gives the
  validated summaries, #110), `RetryUnsentRound` and `EraseUnsentRound` (a refused one only),
  `RoundsUnreadableAtStart`, `WatchCollecte` (#111; the ledger's summaries and the phone's unsent
  ones of that secteur and campaign), `RemoveCalendar` (#114). The status use cases
  (`SetHouseDetails`, `MarkDwelling`) tell the open tournée about each change through
  `RoundVisits` (`RoundVisit.of(change)`), and `UndoLastChange` tells it the reverse of the
  change undone, so the count is right whatever screen marked it; only on the secteur the
  tournée started in.

### 6.2 Firestore layout

Until #116 the secteurs lived in `tournees/{id}`, their keys in `tourneeKeys/{key}` and the
field naming them was `tourneeId`. Nothing was migrated: with a single user (2026-11-03) the old
`tournees`, `tourneeKeys` and `joinCodes` were deleted and the test secteurs created again; the
rules know only the new names.

```
admins/{uid}                                      ← no fields; added by hand in the console (#75)
rescueCentres/{centreKey}                         ← "villefranche"; the CS picker lists these
    name: "CS Villefranche"
sectorKeys/{centreKey}_{number}                   ← "villefranche_49": guarantees number + CS is unique;
    sectorId                                         read by admins only (#147)
openSectors/{uid}                                 ← #147: the secteur this account's phone has open,
    sectorId                                         written by that account alone, read by no one
                                                    but the rules (who may read `streetParts`)
joinCodes/{code}                                  ← "K7P2QX": readable only by exact code (get, not list)
    sectorId, number, centreName, campaign       ← what the join preview shows; nothing else

streetParts/{banId}                               ← #133 (5.15): who holds which part of a BAN
    sector: "<sectorId>",                            street; readable only by exact id (get,
    parts: { "<sectorId>": { number: 12,             not list); each secteur writes only its own
               centreName: "CS Villefranche",      entry; none for a street typed by hand.
               odd: "all" | "none" | [19, 41],     `sector` names the entry the last write
               even: … } }                          changed (the rules need it, #141); `parts`
                                                    may be missing (an entry removed from a
                                                    street no secteur held)

sectors/{sectorId}
    number: 49, centreKey, centreName, joinCode, createdBy, createdAt,
    currentCampaign: 2026,
    communes: [ { code: "69264", name: "Villefranche-sur-Saône",
                  lat: 45.9837 | null, lon: 4.726 | null }, … ]
                                                  ← #78: in the order added; absent on a
                                                    secteur created before (reads as none);
                                                    an unreadable entry, or a second one of a
                                                    code, is skipped when read, at most 50 kept
  campaigns/{year}/rounds/{roundId}               ← #63: one per validated tournée, create-only,
    startedAt, endedAt, housesVisited, free,          no member on purpose
    cash: { count, cents }, cheque: { count, cents }, card: { count, cents }
  members/{uid}
    displayName: "Manu", status: "pending" | "active", requestedAt, acceptedBy, acceptedAt,
    joinCode                                      ← only on a newcomer's request: the code used
  names/{key}                                     ← #148: "lea", the name's `MemberName.key`;
    member: uid                                      create-only, written with the member
                                                    document that holds the name (request,
                                                    creator, admin joining, rename); deleted
                                                    with it (refuse, cancel, remove, leave,
                                                    rename, the secteur); a free name or one's
                                                    own may be asked by anyone signed in
  campaigns/{year}                                ← one per year: 2026, 2027…
      startedAt, previousYear: null | 2026
    streets/{streetId}
      name, communeName, communeCode, banId,
      shape: ["<encoded polyline>", …],           ← one per OSM road, simplified, ≈ 1 KB a street;
                                                    [] for none; written once, with the street
                                                    or later while still [] (#92), never replaced
      deletedAt, deletedBy                        ← set = in the Corbeille (5.11); null otherwise
      part: { odd: "all" | "none" | [1, 57],      ← #133 (5.15): the numbers this secteur holds,
              even: "all" | "none" | [2, 30] }      per side, bounds on the numeric part; absent
                                                    = the whole street
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
                 calendars: 2,            ← calendars a ✓ took (#114), 1–99, only while
                                            DONE (removed on any other status); absent
                                            = 1 on a ✓, 0 otherwise
                 deletedAt: null, deletedBy: null },   ← set = number in the Corbeille
        "8":   { n: 8, …, status: "TO_DO",        ← a building is always TO_DO itself
                 labelStyle: "FLOOR_AND_NUMBER",  ← FLOOR_AND_NUMBER | FLOOR_AND_LETTER | FREE
                 layout: [ { esc: "A", floor: 5, doors: ["51", "52"] },
                           { esc: "A", floor: 4, doors: [] }, … ],
                                          ← staircases A→Z, floors top first (floor null for
                                            the « Logements » row), doors left to right; it
                                            keeps the doors' order and the emptied floors
                 dwellings: { "A5-51": { status, comeBack, by, at, tries?, calendars? }, … } }
                                          ← the marks of each door; key = letter + level +
                                            "-" + label ("A0-Gauche"; "A-Gauche" when the
                                            floors are unknown). A single house has none of
                                            labelStyle, layout, dwellings
      }
```

The street document fixed in T2.3 (`infrastructure/firestore/mappers/`): field names above,
statuses and label styles under fixed names. `prev` (last campaign's status) comes with the new
campaign (v1.1). `shape` came with the map (T3.3): a document written before has none and
reads as no shape. `assignees` (who covered the street, T3.3) went with 5.14 (#120): it is no
longer written, a document that still has it is read as if it had not, and the rules let no
write add or change it. `tries` (#80) is written only from the
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
| mark, « Repassé, toujours personne », « repasser » of a house | `status`, `comeBack`, `tries` (the count, or deleted when 0), `calendars` (1 or the count kept on a ✓, deleted otherwise, #114), `by`, `at` (« repasser » day or hour: `comeBack`, `by`, `at`) |
| mark, « Repassé, toujours personne », « repasser » of a door | `dwellings.<key>.status`, `.comeBack`, `.tries`, `.calendars`, `.by`, `.at` (day or hour: no `status`, no `tries`) |
| one calendar more (« + Ajouter un don ») or less (« − ») of a house or door done (`HouseCalendarsCounted`, `DwellingCalendarsCounted`, #114) | `calendars`, `by`, `at` (a door: `dwellings.<key>.calendars`, `.by`, `.at`) |
| layout (describe, add / remove / rename a door) | `status`, `comeBack`, `tries` and `calendars` (deleted), `by`, `at`, `labelStyle`, `layout`, then each door `dwellings.<key>` whole; each door dropped is deleted |
| back to a single house | `status`, `comeBack`, `tries` (deleted), `calendars` (1 when done, else deleted), `by`, `at`; `labelStyle`, `layout`, `dwellings` deleted |
| street added (import, typed in, moved from the phone) | the document `set` with its first 2 houses, then each next `houses.<n>` whole, 2 per update, each sent once the phone's copy shows the one before (#70: the rules check each house a write adds, and only 2 fit in one request; §8.2 « Houses written in bulk »); a street of more than 2 houses is kept on the phone until they are all sent, and finished at the next start if the app was killed in the middle (#104) |
| numbers added | each new `houses.<n>` whole, 2 per update (#70); each one restored: `deletedAt`, `deletedBy` = null, in an update of its own (the rules check one by one only a write changing one house, T2.4) |
| number removed / restored | `deletedAt`, `deletedBy` (set / null) |
| number renamed | `houses.<old>` deleted, `houses.<new>` whole |
| street renamed, deleted, restored | `name`; `deletedAt`, `deletedBy` (top level) |
| part changed (`StreetPartChanged`, #138) | `part` (top level) alone, the map, or deleted for « Toute la rue »; then each number left out as a removal, each brought back from the Corbeille as a restore, each new one whole, 2 per update (as « numbers added ») |
| shape found later (`StreetShapeFilled`, #92) | `shape` (top level), the whole list, only while the stored one is absent or `[]` |
| undo of a house (`HouseReverted`) | as a layout change, or `houses.<old>` deleted and `houses.<n>` whole when it renumbers back; `by` / `at` = who undoes, now |
| undo of a door (`DwellingReverted`) | `dwellings.<key>` whole, `by` / `at` = who undoes, now |
| 30-day purge of numbers (`NumbersPurged`, T2.6b) | each `houses.<n>` deleted, in an update of its own |
| 30-day purge of a street (`StreetRepository.purge`, T2.6b) | the street document deleted |
| commune added / removed (#78, on `sectors/{id}`) | `communes`: `arrayUnion([entry])` / `arrayRemove([entry])`, never the whole list, so two members adding at once both stay |

A building is never written as one map that would replace the doors: two writes crossing (a
door marked while a teammate lays the building out again) leave at most a door entry the
layout does not list, or a house entry without `n` (a mark landing just after a renumbering);
reading skips both.

Creating a secteur writes `sectorKeys`, `joinCodes`, `sectors` and its first campaign in one
batch; the security rules refuse the batch if `sectorKeys/{key}` already exists, which is what
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

- **The phone storage folder** (`infrastructure/local_storage/`, the app support folder:
  private, kept across updates) holds the small files below. Every file is written to
  `<name>.tmp` and renamed over the old one (a kill mid-write leaves the old file), writes
  queued one after the other; an unreadable file means none / defaults. No network, ever:
  works after an offline cold start. The phone's own member id is kept in `member_id` (it
  only stands in until the first Firebase sign-in, §6.1). A secteur's streets are in
  Firestore's cache, not here.
- **Retired** (#119): the streets of a phone with no secteur open (M1 to 0.10.0, one JSON
  file per street in `streets/`) and `moved_streets.json` (the secteurs they were moved
  into) are no longer read; `deleteRetiredFiles` deletes them at start-up, before anything
  else is read (a file the system refuses to delete is left for the next start). Their JSON
  form (`mappers/street_json_mapper.dart`, schema `version: 3`, still reading versions 1
  and 2) stays as the form of the unfinished streets below.
- `street_view.json` in the same folder (port `StreetViewPreferences`, T1.7): « Masquer faits »
  per street, `{ version: 1, hideDone: [streetId…] }`, read once at start-up; an unreadable file
  means nothing hidden.
- `my_tournees.json` in the same folder (port `MySectorsStore`, T2.7): « Mes secteurs » and
  the open one, `{ version: 1, open: id | null, tournees: [{ id, number, centre, campaign,
  status: "active" | "pending" | "visiting", name? }] }` (`name`, #148: the member's name in
  that secteur, absent when unknown; `visiting` from #75; an older app reads
  such a file as unreadable, so as none), read once at start-up, so the last secteur reopens after
  an offline cold start. `settings.json` (port `PhoneSettings`): `{ version: 1, name: "Manu" |
  null, theme: "system" | "light" | "dark" }`. Same writing as the streets (`.tmp` then
  rename, queued); an unreadable file means none / defaults and is left until the next save.
  Files of the storage folder rather than `shared_preferences`: no plugin, plain Dart tests.
- `tournee_downloads.json` (port `SectorDownloads`, #32): the secteurs downloaded on this
  phone, `{ version: 1, downloads: [{ tournee, at, mapBytes, area: [south, west, north, east]
  | null }] }` (sorted by secteur; `at` ISO 8601 UTC; `area` the bounds of the map kept, null
  when no street had a place on the map). Written only once a download is complete, so it
  says whether a secteur works offline (read at start-up, an offline cold start included);
  same writing as the others; an unreadable file means none (the open secteur is then
  downloaded again).
- `unfinished_streets/<sector>/<year>/<streetId>.json` (port `UnfinishedStreets` of the
  Firestore adapter, #104): each new street of more houses than one write holds, whole, in
  the JSON form of `street_json_mapper.dart`, from just before its first write until all its
  writes are in Firestore's hands (a second or two); read when the secteur's streets are
  first listened to, to finish a street cut off by a kill (§8.2 « Killed in the middle »).
  Ids percent-encoded; same writing as the streets; an unreadable file is skipped.
- `open_round.json` (port `OpenRoundStore`, #63, #143): the tournée on and the validated
  tournées not yet sent, `{ version: 2, round: { id, sector, campaign, startedAt, housesVisited,
  donations: [{ method, cents } | { free: true }] } | null, unsent: [{ sector, campaign, refused,
  summary: { id, startedAt, endedAt, housesVisited, free, cash: { count, cents }, cheque, card }
  }] }`, written at each change (same writing as the others), so a tournée survives a kill; the
  dons carry no house and no time. Version 1 (no `unsent`) is still read. `ValidateRound` moves
  the tournée on to `unsent` in that one write, so a kill leaves it on or validated, never both
  nor neither; it leaves `unsent` once the server has its summary, or on « Effacer ». An
  unreadable file means none, and the app says so once at start-up (the file is left as it is
  until the next change overwrites it).
- The validated summaries go to `rounds/{roundId}` (§6.2, port `RoundLedger`,
  `FirestoreRoundLedger`), whose copy « Collecte » reads offline. A send never trusts Firestore's
  own queue alone: after a kill, an earlier `set` may still be queued or already on the server,
  and a second `set` would reach the server as an update, which the rules refuse. So `record`
  first waits for the server's word on the document (a listener's first snapshot neither from the
  cache nor with a write of this phone pending, which settles an earlier queued write), counts a
  document already there as kept, and only otherwise creates it and waits for the answer. Any
  Firestore error is a refusal (« Réessayer » asks again). (The stand-in of #108, files in
  `validated_rounds/`, was removed unreleased; a phone that ran it keeps that folder, unread.)
- MapLibre offline regions (tiles), behind the `OfflineMapStore` port
  (`infrastructure/maplibre_offline/`): one per downloaded secteur (two for a moment while
  one is replaced), in the map library's database (`files/mbgl-offline.db`). Each region's
  metadata is `{ tournee: id }`, so the regions of a secteur are found among the phone's.
- `cache_reset.json` (port `PhoneCacheReset`, `FirestoreCacheReset`, #144): `{ version: 1,
  reset: "none" | "waiting" | "due" }`. A secteur forgotten (left, removed, deleted, an admin's
  visit revoked) asks for Firestore's copy on the phone to be emptied, so its streets leave
  the phone: `waiting` at once, `due` once `waitForPendingWrites` says the server has every
  change made on this phone; each time the app is hidden (where Android may kill it) a reset
  asked goes back to `waiting` until the server has the changes made since. At a start, before
  anything asks Firestore anything, a `due` reset with the network (Firestore's host name looked
  up, ≤ 2 s) runs `clearPersistence`, deletes `tournee_downloads.json` (the open secteur is then
  downloaded again by itself, the others when opened) and goes back to `none`; offline, or still
  `waiting`, the copy stays (nothing queued is lost, the day without network keeps its data). A
  clear refused (Firestore already started) is tried at the next start. Known gap: a change made
  in the foreground and the app crashing before it is hidden, then a start with the network.
- `reminders.json` (port `ReminderPreferences`, `LocalReminderPreferences`, #82): `{ version: 1,
  on: bool, permissionAsked: bool }`, « Rappels pour repasser » (on by default) and whether
  Android's notification permission was asked once (at the first ↻ given a day). Same writing
  as the others; an unreadable file means on, never asked.
- The scheduled reminders themselves (#82) are kept by `flutter_local_notifications` in its own
  storage on the phone (for its boot receiver), each with a title, a text (addresses and an
  hour) and a payload (street id, house number, door id); `ScheduleReminders` replaces them all
  at each change, so none outlives its ↻, the secteur or the switch.
- **Android backup** (#144): `android:allowBackup="false"` and data extraction rules excluding
  every domain (cloud backup and device transfer, Android 12+): nothing of the app is copied to
  a Google backup or a new phone, so uninstalling removes all it kept.
- The names on the phone that say « tournee » (`my_tournees.json`, `tournee_downloads.json`,
  their keys `tournees` and `tournee`, the regions' metadata key) date from before the code
  said `Sector` (#116) and stay as they are, so an updated phone keeps its secteurs, the open
  one and its offline map.

---

## 7. Sync and offline behaviour

**Goal:** once the app has been online with the secteur open, it can be used for a whole day with
no network, including a cold start, and loses nothing. The download is **automatic and
invisible** (decided 2026-11-01, #32): no button, no banner, no progress, nothing about map
versions.

| What | How it works offline |
|---|---|
| Sign-in | The anonymous Firebase session is persisted on the phone; no network needed at start-up. After an offline first start, the sign-in is tried again when Créer / Rejoindre need it (§6.1) |
| Secteur data | Firestore persistent cache with **unlimited size** (no eviction). The download reads every street of the secteur once from the server, so all of them are in the cache |
| Live updates | Snapshot listeners serve the cache at once, then the server when reachable |
| Writes | Applied locally at once, queued by Firestore, survive restarts, sent when back online |
| Map | MapLibre offline region covering the secteur's bounding box + 300 m margin, zooms 12–17, OpenFreeMap « liberty » style (its own URL). ≈ 7 MB measured in the T0.4 spike for a 1.5 km box (6.6 MB, 96 % fonts: a fixed cost; tiles stop at z14), ≈ 8–9 MB expected for a 3 km secteur. Street lines and house dots are drawn from the cached street documents, not from the network |
| New streets in the secteur added by teammates | Arrive with the next sync; when one reaches beyond the downloaded area, the app downloads the secteur again by itself |

- The pending-writes indicator (« ☁ Modifications de 3 rues en attente d'envoi », « … d'une
  rue … » for one) comes from the snapshot metadata `hasPendingWrites` (port `PendingSync`,
  T2.3): it counts the **streets** with writes waiting, since Firestore tells it per document,
  and words it so (not « 3 modifications »). The Firestore street adapter of the open secteur
  is the `PendingSync` too (one listener for both); with no secteur open there is no street,
  so nothing is pending. Shown only while the count is above 0.
- **Automatic download** (`DownloadSector`, run by `OfflineAutoDownload`, #32): the open
  secteur (not a pending request) is downloaded when it is opened (start-up, created, joined,
  switched to) and not downloaded yet, and again when its streets reach beyond the area kept
  (`coversStreets`). Both parts in turn: every street read from the server, then the map region
  of `sectorArea` (zooms 12–17); the date, map size and area are kept (§6.3) only once both are
  complete. A new region is always made beside the old one (1 m wider when the old one has the
  same bounds, `offlineRegionBounds`: the map library would otherwise delete the old region
  before downloading), and the secteur's older regions are deleted only after it completes.
  A map download that tells nothing for a minute fails (offline, MapLibre never reports a
  failure, it waits). One run at a time; switching secteur stops the run of the one left (its
  half region is deleted, nothing is recorded).
- **Silent map refresh** (`RefreshOfflineMaps`, #32): OpenFreeMap publishes new tiles every
  week, and once the app has been online after a change the stored map description points at
  the new version, so the tiles of an old region can no longer be reached offline
  (docs/spikes/map.md §5). So the map of every downloaded secteur is downloaded again, silently,
  whenever the app is online: at start-up, when it comes back to the foreground, at most every
  12 hours after a refresh that worked — and at once for the other secteurs right after a
  download (the description is shared by all regions). Same safe pattern: new region first, old
  one deleted after `Success`; a failure keeps the old region. `resetOfflineDatabase` is never
  used. Serving our own copy of the style (Firebase Hosting, stable `/planet/latest/` template)
  was considered and not taken: OpenFreeMap's own style URL is kept.
- **Retry:** any failure (offline, service down) waits 2 minutes, then tries again by itself,
  as the street shapes do (#92); no connectivity plugin.
- **Forgetting a secteur** (left, removed, deleted, a request refused): its download record and
  map regions are deleted (`PruneSectorDownloads`, run at start-up and after each change of
  « Mes secteurs »), whatever flow forgot it. Its streets leave Firestore's copy at a later
  start with the network (`cache_reset.json`, §6.3).
- What the member sees of all this (T4.2, #33): nothing on Accueil; one line in Paramètres
  (§5.9); offline, « Mes secteurs » greys a secteur not downloaded on this phone (« Disponible
  avec réseau », §5.3). « Offline » there comes from the snapshot metadata `isFromCache` of
  the open secteur's street listener (port `ServerConnection`), as the pending-writes count
  comes from `hasPendingWrites`.
- What needs the network: creating / joining a secteur, the download itself (run by the app),
  and **adding a street from the map** (reverse geocoding, BAN, the map's tiles for its line; the line of a
  street added without it is filled later, when online, #92). Adding a street by hand, adding
  numbers, taking streets and every status change work offline.
- Undo is a normal write that restores the previous value, not a rollback.

---

## 8. Security and privacy

### 8.1 Threat: someone guesses or obtains a code

The code space (31⁶ ≈ 887 million) protects one *given* secteur well, but not "any secteur":
with 1 000 secteurs in the app, one guess in ~887 000 lands somewhere. Without rate limiting,
a script could get in somewhere within minutes. A leaked code (forwarded WhatsApp message,
photo of the QR) is even more likely. So **knowing a code must not be enough**:

| Layer | What it stops | When |
|---|---|---|
| **Approval of newcomers.** Using a code creates a *pending* member who can read or write nothing until an accepted member accepts them (5.2, 5.8) | Guessed or leaked codes give no access at all | v1 |
| **App Check (Play Integrity)** enforced on Firestore: only the genuine app from the Play Store can talk to the database | Scripts, mass guessing, data scraping | v1 (M2) |
| **Strict security rules**: schema, allowed values and lengths for every field; members may only touch the fields of their job; nobody edits `createdBy`, codes, or other members except as below | A member corrupting documents or escalating | v1 |
| **Corbeille + attribution**: deletes are soft for 30 days (5.11); every change records who and when | Mistakes, and a member who makes a mess | v1 |
| **Remove member + new code** (creator) | A bad actor already inside | v1 |
| Server-side join with rate limiting (Cloud Function, needs the Blaze plan) | Large-scale guessing even from the real app | **Later, if needed** (decided at the M2 checkpoint, Q20): v1 stays on Spark. The join goes through the `SectorDirectory` port, so moving to a callable function is an adapter swap with no data migration. Per-uid limits are weak anyway (anonymous accounts are free to create); App Check is the real gate |

### 8.2 Security rules (`firebase/firestore.rules`, tested in the emulator, §11)

- `sectors/{id}/**`: read and write only for members with `status == "active"`.
- `members/{uid}` create: only by that uid, only `status: "pending"`, only with the secteur's
  current join code. Update `pending → active` or delete a pending request: any active member.
  Delete an active member: the creator, or the member themself (*Quitter*). Update
  `displayName` only: the member themself, active, a name as `MemberName` cleans it (≤ 30).
- `joinCodes/{code}`: `get` for signed-in users, `list` denied; holds only the preview fields.
- `part` of a street (#138, §6.2): optional on a new street, then written alone (set, or
  deleted for the whole street); each side `"all"`, `"none"` or `[from, to]`, integers
  0–99999, `from ≤ to`, both odd on the odd side and even on the even one. A new street held in
  part comes with **one** house in its first write instead of 2: checking the part costs more
  than two of the costliest houses leave of the 1 000 expressions (measured in the emulator).
- `streetParts/{banId}` (#133, 5.15): `get` for an admin or an active member of some secteur
  (#147, below), `list` denied. An active
  member of a secteur, or an admin (who deletes secteurs, member or not), may create the
  document or update it changing only the key of that secteur (`diff().affectedKeys()` within
  `[sector]` on `parts`), with `number` and `centreName` equal to the secteur's and sides in
  the shape above; deleting that key is the same write. The rules cannot tell which key of a
  map a write changed, so the write names its secteur in `sector` (#141): exactly `sector` and
  maybe `parts`, nothing else. The document itself is never deleted. Written when a street is
  added, its part changed, deleted, restored or purged, and when the secteur is deleted (each
  of its entries). A separate request from the street writes, so it costs nothing of their
  1 000 expressions. Tests: `firebase/test/street_parts.test.mjs`.
- `sectorKeys/{key}`: `get` for admins only (« Créer », admins only, must know the pair is
  taken; #147: it names the secteur's id, the target of a join request); create only if
  absent; never updated; deleted only with the secteur.
- **Directory documents tell no more than needed** (#147, decided 2026-11-11). The rules
  cannot search every secteur for the caller's member document, so « an active member of
  some secteur » is checked through `openSectors/{uid}`: the phone names there the secteur it
  has open (`FirestoreStreetPartIndex.declareReader`, sent without waiting when an active
  member's secteur opens; never for an admin who visits, nor before the phone has an
  account), and `isActiveSomewhere()` checks the caller is `active` in the secteur named.
  It is only a pointer: a wrong, stale (removed since, secteur deleted) or missing name gives
  nothing, so it needs no upkeep on leave, removal or deletion. Written by its own account
  only, exactly `{ sectorId }`, an id the app makes, of a secteur the caller is active in;
  deleted by its account; read by no one. `sectors/{id}`: `get` also allowed to any signed-in
  account when the secteur does not exist (`resource == null`), so a member whose own
  document went learns whether the secteur was deleted (not there) or they were removed
  (refused); it tells nothing of a secteur that exists. Nothing on the marking path reads
  either: offline, the index is read from the phone's copy or not at all, as before.
- `rescueCentres`: readable by signed-in users (station names only), create-only.
- **A name per secteur, unique in it** (#148, decided 2026-11-11, 5.16). `sectors/{id}/names/
  {key}` holds each member's name under its key: `nameKey(name)` in the rules works out
  `MemberName.key` (`replace` of the accented letters in both cases and of the separators,
  then `trim()` and `lower()`, which lowers A–Z only). Create only, exactly `{ member }` =
  the caller, and only while the caller's member document, as the write leaves it
  (`getAfter`), has a name of that key; never updated, so a name another member holds
  cannot be taken. Every member document written with a name requires its entry naming the
  caller after the write (`hasNameEntry`): a request (`isJoinRequest`), an admin's own
  document, the creator's included (`isAdminMembership`), a rename (`isRename`). Delete: an
  admin, or anyone signed in once the entry's member no longer holds that name (their
  document gone or renamed in the same write), or an entry that is not there (a member of
  before #148). `get`: the team and the admins, and anyone signed in for a free name or
  their own, so a newcomer learns from the refusal that a name is taken and nothing of who
  holds it; `list`: the team and the admins. The member rules do not require the entry to go
  with a deleted member (a member of before #148 has none): the adapters delete it in the
  same batch. A few `replace` calls per name write, far from the 1 000 expressions. Tests:
  `firebase/test/names.test.mjs`.
- Street and house writes: field-path updates only on `status`, `comeBack`, `tries`, `by`, `at`,
  `deletedAt/By`, numbers and dwellings; `status` in the enum; `comeBack` a time
  as the app writes it (#81, `isComeBackTime`: "", a day "2026-10-24" of the years 2000–2999,
  or a day and an hour "2026-10-24T18" of 08–21), so no free text at all (no `note`, §8.3; the
  free hint of before #81 is refused in a write, one already stored only goes when the house is
  next written); `tries` (#80, on a house or a door, `hasTries`) optional, an integer 1–99 when
  present, absent on a number just added; not tied to the status, so a mark by an app older
  than #80, which leaves it as it was, is still accepted;
  `by` must equal the caller's uid; `at` must be a timestamp. It is the phone's time of the
  change, not the server's (T2.3): a mark queued offline reaches the server hours later and
  must keep the time it was made, so the rules cannot require `at == request.time`.
- Only the creator: delete the secteur, regenerate the code, start a campaign. Previous
  campaigns are read-only.

**Admins (#75, 5.12)** change the rules as follows; where they contradict the lines above and
below, these win:

- `isAdmin()` = `exists(/databases/$(database)/documents/admins/$(request.auth.uid))`.
  `admins/{uid}`: `get` for signed-in users, never `list`, never written by a client.
- **Creating** a secteur (its reservation, code, first campaign, creator member) and a
  `rescueCentres` entry: admins only.
- **Reading and listing** `sectors` and everything under them: active members **or admins**
  (only admins may `list` `sectors` and query `members` of any secteur).
- **Streets** (every write allowed to a member, the 30-day purge included): active members or
  admins, `by` = the caller as before.
- **Members:** accept / refuse a request: an active member or an admin. Delete an active
  member: an admin (any member, admins included), or the member themself (*Quitter*, the
  creator too: their document no longer waits for the deleting batch). An admin creates their
  own document already `active`, `acceptedBy` = themself, without a code (« Rejoindre » of
  5.12).
- **New code, deleting the secteur, starting a campaign:** admins only, member or not. The
  deleting batch deletes every remaining member document (there may be none).
- Delivered in #75 (`firebase/firestore.rules`, `firebase/test/admins.test.mjs`): the
  deletion no longer requires the deleter's member document to go (the rules cannot list
  the members; the adapter deletes those that exist, since deleting a missing member
  document is refused). The undo of « Restaurer » may name an admin as the remover of a
  number (`exists(admins/{deletedBy})`), as an admin outside the team may have removed it.
  An admin's own active document (creation or « Rejoindre ») is one rule,
  `isAdminMembership`. The rules tests seed `admins/manu` (the creator) and `admins/sam`
  (in no secteur); the older tests that gave the creator powers now name an admin.

What the adapters write (T2.3), which the rules must allow:

- **Create** (one transaction): reads `sectorKeys/{key}`, `joinCodes/{code}` (more than one
  if a code is taken) and `rescueCentres/{key}`; writes `sectorKeys/{key}`,
  `joinCodes/{code}`, `sectors/{id}`, `members/{creator}` **already `active`** (accepted by
  themself), `names/{key}` of the creator's name (#148), `campaigns/{year}`, and
  `rescueCentres/{key}` only when absent.
- **Join:** the request is `members/{uid}` with `status: "pending"` and the `joinCode` used
  (the rule compares it with the secteur's). The newcomer **reads their own member document**
  while pending (« Demande envoyée » follows it) and deletes it to cancel. Since #148 the
  request is a transaction: it reads `names/{key}` (refused or another's: the name is taken;
  a refused write is taken too unless a read of `joinCodes/{code}` says the code changed),
  then writes the request and the entry (unless already the newcomer's). Cancelling deletes
  both, queued like any write.
- **Accept:** updates `status`, `acceptedBy` (the caller), `acceptedAt` only. Refuse, remove,
  leave: delete the member document and `names/{key}` of their name in one batch, queued.
  **Rename** (« Prénom », « Votre nom dans le secteur 49 »): a transaction that reads the new
  name's entry (another's: refused, `nameTaken`), the caller's member document (gone: nothing
  written) and the old name's entry when the key changes; then updates `displayName` only,
  creates the new entry when absent and deletes the old one when it is the caller's. **An
  admin joining** (« Rejoindre »): the same transaction, the member document `set` whole.
- **New code** (one transaction): reads `joinCodes/{new}`, updates `sectors/{id}.joinCode`,
  deletes `joinCodes/{old}`, creates `joinCodes/{new}`.
- **Delete:** lists `campaigns`, their `streets` and `rounds` (#110) and `members` from the
  server, deletes the campaigns, streets and rounds in batches of ≤ 500, then one batch: `joinCodes/{code}`,
  `sectorKeys/{key}`, `sectors/{id}`, the other members' documents and the creator's own,
  and the `names` they hold (#148); members and names listed again after it.
- **Streets:** the writes of the table in §6.2. Whole entries (a number added or renamed, a
  layout, an undo) carry door entries with the `by` / `at` they already had, possibly a
  teammate's: only the entries that change carry the caller's uid. The undo of « Restaurer »
  writes back the removal it undoes (`deletedBy` possibly a teammate's).
- `rescueCentres` is listed (a query), not only read by id.

Rules fixed in T2.4 (`firebase/firestore.rules`, emulator tests in `firebase/test/`, `npm test`):

- **Reading.** A secteur, its members, campaigns and streets: active members only. A pending
  newcomer reads their own member document and nothing else; someone outside reads nothing.
  `joinCodes`: `get` when signed in, `sectorKeys`: `get` by admins (#147), never `list`.
  `rescueCentres`: `get`
  and `list` when signed in. Anything not described is refused.
- **Values.** Every document holds exactly its fields (no more, no fewer) with the domain's
  limits: secteur number 1–9999, campaign 2000–2099, join code 6 characters of the alphabet,
  centre key words of `a–z 0–9` joined by `-`, names cleaned as the domain cleans them
  (one line, trimmed, single spaces): member ≤ 30, centre ≤ 80, street ≤ 150; commune code
  `69264` / `2A004`; house number 0–99999 with a suffix of ≤ 16 lowercase letters and digits,
  stored under its label; position in range or both null; statuses and label styles among
  their fixed names; a `comeBack` time exactly on « repasser » (a building may keep its own);
  a stamp a write sets is the caller's (`by` = uid, `at` a timestamp), a house added
  has none or the caller's (#70); no `note` anywhere. Lengths are counted in code points
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
- **Creating a secteur** is accepted only whole: the secteur checks with `getAfter` that the
  same transaction writes its reservation (create-only, so number + station stay unique), its
  code (create-only, so no one replaces another secteur's preview; the preview must repeat
  the secteur's number, station and campaign), its creator `active` and accepted by
  themself, and its first campaign (the current year). Each of those documents in turn is
  accepted only from the secteur's creator and must match the secteur as written.
- **Members.** A request is the caller's own document, `pending`, with the secteur's current
  code. Any active member accepts (status, `acceptedBy` = caller, `acceptedAt` only) or refuses
  a request; the newcomer cancels it. The creator removes an active member; a member leaves.
  An active member renames themself: their own document, `displayName` only, a cleaned name
  ≤ 30 (T2.7b); nobody renames someone else, not even the creator. A pending member cannot
  rename themself: a name changed while the request waits is sent by the phone once accepted
  (T2.7c), so the rules stay as they are.
  The creator's own document goes only in the batch that deletes the secteur.
- **New code** (creator): only `joinCode` changes, the new code document is created and the old
  one deleted in the same transaction. **Deleting** (creator): the contents first (campaigns,
  streets), then one batch where the secteur goes only with its code, its reservation and the
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
  - **add houses** (« numéros en plus », and the houses of a new street after its first
    write): at most 2 per write (#70), each checked whole, as below;
  - change the street's `name` or its deletion (`deletedBy` = caller), never its commune or BAN
    id;
  - **drop one house** of the Corbeille removed more than 30 days ago (the purge).
  Anything else (two houses changed at once, a house deleted outright before its 30 days in the Corbeille, a mark landing on a
  number or a door that is no longer there) is refused.
- **Houses written in bulk** (#70, decided 2026-11-02): a new street is written with its first
  houses, then updates adding the next ones; « numéros en plus » of several numbers is sent
  the same way. A write may add at most **2 houses** (`housesPerWrite()` in the rules,
  `housesPerWrite` in `infrastructure/firestore/mappers/street_writes.dart`; a Dart test
  checks they agree). Why 2: the rules have no loops, so the check is written out once per
  house, and a request may evaluate at most 1 000 expressions, every name, value, operator
  and call counted. Measured in the emulator: the membership, the secteur and the street
  cost ≈ 300, one house ≈ 200, the costliest (a building with a suffix, tries and a
  « repasser » time, marked and removed by the caller) ≈ 300; two of those leave ≈ 90 to
  spare, three do not fit. A rules test writes full writes of the costliest houses, so a
  rules change that makes them too dear fails there. A street of 300 numbers is ≈ 150
  writes; teammates may see it partly filled until the last one arrives (accepted).
  - **Sent in order, one after the other.** The Firestore plugin for Flutter does *not* keep
    the order of calls made back to back: on Android it runs each `set` / `update` on a
    thread of its own, so an update can reach the SDK before the `set` of its document, and
    is then lost (never applied offline, refused « not found » online). So each update of a
    new street is sent only once the phone's copy of the document (its snapshots, metadata
    changes included) holds the houses of the write before; the write's `Future` is not
    awaited (it completes on the server's answer, never offline). Local writes show at once,
    offline too: a few milliseconds each. The writes of one street also wait for those asked
    before on it (`OrderedWrites`, `infrastructure/firestore/ordered_writes.dart`), so a mark
    made while a street is still being written goes after the house it marks. The several
    updates of one change (numbers added, restored, purged) go all at once: they touch
    different houses of a document that exists, so their order does not matter. Once in the
    SDK, writes keep their order to the server, offline and across restarts. A write that
    never shows (the street deleted meanwhile) must not hold the street's later writes in
    memory, where a kill would lose them (#152): once the copy has shown a write of the
    batch, a copy saying the document is gone ends the batch (the rest would be refused);
    and no write is waited for more than 30 s, after which the rest of the batch is sent at
    once (debug log « Document … not shown after 30 s »).
  - **Killed in the middle** (#104). `add` returns at once (the phone has the street in
    memory) and the writes run in the background; a kill before their end (a street of 300
    numbers takes a second or two) would leave the writes not yet handed to the SDK unsent.
    So a street of more than 2 houses is first **kept on the phone**, whole
    (`unfinished_streets/…`, port `UnfinishedStreets`, §6.3), and its first write goes only
    once it is on the disk (a few milliseconds; a mark made meanwhile waits behind it, as
    any write of the street). It is forgotten once its last write shows in the phone's
    copy: from then on the SDK has them all and keeps them across a restart. A refused
    write also ends it (what follows would be refused too). If the disk refuses the record
    (full), the street is written all the same, without the safety net.
  - **Caught up at the next start.** When the secteur's streets are first listened to, each
    street still kept is compared with the phone's copy of its document (its first
    snapshot, which Firestore serves from the phone at once, offline cold start included):
    the houses missing are sent again, 2 per update, in order (`catchUpWrites`); the houses
    there are left as they are (a teammate may have marked them since). No copy at all (not
    even the first write reached the SDK): the street is written again from the start.
    Nothing missing: it is only forgotten. Marks made on the street between the add and the
    kill are lost, as any write not yet handed to the SDK. Known limit: closing the secteur
    and opening it again within the second a street takes would start its catch-up while
    its first writes still go (both would add the same houses); not guarded.
  - **Whole on this phone while it is written.** Firestore shows the new street growing
    2 houses per write; while its writes go (and during a catch-up), the adapter reads each
    snapshot of it with the houses it is missing taken from the whole street
    (`withHousesOf`), so the counters on this phone never climb 2, 4, 6… Teammates still see
    it fill up (accepted, above).
  - **Measured** in debug builds: each new street logs « Street <id> written (add | catch
    up): N writes in M ms » once its writes are all handed to Firestore (`flutter logs` or
    `adb logcat | grep "Street "`); M / N is the time per step.
  - **Checked per house**, as a single house is: exactly its fields (no `note`), number
    0–99999 and suffix, under its own label, position in range or both null, status among
    the four, a `comeBack` time only on « repasser » (no free hint), tries 1–99 or none,
    label style among the three for a building; marked (`by` / `at`) and in the Corbeille
    (`deletedBy` / `deletedAt`) only **by the caller**, or not at all, and then it is to
    do, without tries, not a building. So a number added may now come marked by the caller,
    which is harmless: the caller could mark it in the next write.
  - **Only counted**: the doors and layout rows of a building (doors ≤ 500, layout rows
    ≤ 26 × 51), in a new street, a number added or a layout written whole. A building can
    hold 500 doors: they could not be checked in writes of 2 without splitting a layout
    into many writes, leaving a building half laid out between them. A door changed on its
    own (a mark, an undo) is checked whole, as before.
- **A removal put back by an undo of « Restaurer »** keeps the teammate's stamp (§6.2): the
  rules accept a number's `deletedBy` that is the caller or an active member of the secteur
  (so a member could also name a teammate as the remover of a number; the stricter choice,
  stamping that undo with who undoes as for houses and doors, would change T2.3's undo).
- Fields no adapter writes yet (`prev` and a new campaign in v1.1) are refused: the task that
  writes them extends the rules and their tests.
- **Communes** (#78): a new secteur must hold `communes`, a list of 1 to 50 entries; the first
  entry is checked whole (`code` an INSEE code, `name` trimmed, not blank, ≤ 100, `lat` / `lon`
  in range or both null, nothing else), the others only counted. Any active member or admin
  updates `communes` alone, by one entry: an addition (checked whole, ≤ 50 in all) or a
  removal that leaves at least one. A secteur stored before has no list: it counts as empty, so
  its first commune can be added. Duplicates of a code cannot be ruled out (no loops): the
  reader skips them.
- **Shape** (T3.3): optional on a new street (an app of before the map writes none); `shape` a
  list of at most 1 000 lines (counted, not checked line by line), never
  changed afterwards, except **filled once** (#92, `isShapeFill`): an update of `shape` alone,
  1 to 1 000 lines (the first a text), while the stored shape is absent or `[]` (an older
  app never writes it; two phones filling at once cannot replace each other's).
- **No `assignees`** (5.14, #120): a new street may not carry the field (not even `[]`), and no
  update may add, change or delete it; a document written before keeps it, and every other
  write to it is checked as usual.
- **Tournées** (#63, built in #110): `campaigns/{year}/rounds/{roundId}` readable by active members
  and admins; **create only**, by an active member (checked at write time, not stored; an
  admin visiting runs no tournée), exactly the fields of §6.2, `startedAt < endedAt` (both
  timestamps), `housesVisited` and `free` 0–9 999, each `count` 0–9 999 and `cents`
  0–100 000 000, each total exactly `{ count, cents }`; the id one the app makes (`isId`), in
  the secteur's **current campaign** (#145, decided 2026-11-11: `year == currentCampaign`, and
  that campaign exists), so no summary lands in a past campaign; once a new campaign (v1.1)
  starts, a tournée of the old one validated after the switch is refused (accepted: a
  campaign changes once a year, out of season); **no update, no delete** (they go with the secteur or the campaign: `delete` for admins,
  as the streets). `FirestoreRoundLedger.record` is a `set` not awaited: recording the same
  tournée again reaches the server as an update, refused, so the first summary stays. The
  domain does not cap at these bounds: a tournée is one outing, far below 9 999 houses or dons
  and 1 000 000 €. **Accepted risk** (#145, decided 2026-11-11, as the backdated purge): any
  active member may create any number of summaries with any figures within those bounds, and
  nothing tells who did, since a summary carries no member by design (§8.3); only an admin
  can delete one (no screen offers it). The team is trusted and the code is the secret;
  storing the author, even in an admins-only document, would break « who ran it is never
  stored ».
- **Statuses and calendars** (#63): `status` also takes `REFUSED` (#113, accepted by the
  rules: like any status but `COME_BACK` it has no time; the app removes its tries); a house or door
  holds an optional `calendars` 1–99, only while its status is `done` (absent reads as 1 on a
  ✓, 0 otherwise), written in the same field-path updates as the status. Apps before 0.10.0
  cannot read `REFUSED`; they are not supported (they read the old `tournees/` paths anyway).
  Built in #114 (`hasCalendars`): a building itself never holds one, a whole entry (a new
  number, a renumbering, an undo) may carry it on a ✓, and « + Ajouter un don » / « − » write
  `calendars`, `by`, `at` with the caller's stamp; leaving ✓ without removing it is refused.
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
  the app reads them. No residents' names, no residents' answers. **Money (#63)**: for each
  validated tournée, its start and end, the houses visited and the count and total per
  payment method and of free calendars, seen by the secteur, **without its member**; **never
  a don per house, door or address**. The list of a tournée's dons stays on the phone, without
  house or time, until it is validated, then it is erased. A house or door marked ✓ keeps
  **how many calendars it took** (no amount, no method), seen by the team like its status,
  reset with the statuses at the next campaign. `PRIVACY.md` and the Confidentialité page (#79)
  say so in « Données enregistrées », « Hébergement » and « Suppression » (#112): the text was
  drafted on 2026-11-02 and awaits the user's review on the phone.
- **Streets held by other secteurs (#133):** `streetParts/{banId}` tells an active member of
  any secteur, or an admin (#147), which secteurs (number and centre) hold which numbers of a
  street, read by the street's BAN id: no marks, no members, no money, only which secteur
  covers which addresses. An account in no secteur reads nothing of it. `PRIVACY.md` and the Confidentialité page say so in
  « Données enregistrées » (#141).
- **Reminders (#82):** local notifications, scheduled on the phone from its copy of the
  streets; nothing is sent anywhere. A notification shows an address and an hour, never a
  person; only the ↻ the member set ring on their phone. Android asks for the notification
  permission the first time the member gives a ↻ a day, never at launch; no exact-alarm
  permission.
- **Location:** the phone's position is used only on screen ("locate me"), never stored or
  sent. Permission is asked when the button is first tapped.
- Firestore region: `europe-west` (EU).
- Attribution shown on the map and in Paramètres: © OpenStreetMap contributors (ODbL),
  OpenFreeMap, Base Adresse Nationale (Licence Ouverte).
- Play Store: needs a privacy policy (Firebase + network + location). Data can be deleted by
  deleting the secteur; the previous-but-one campaign is to be deleted at each roll-over once
  M6 exists (until then the text says past campaigns stay until the secteur is deleted, #144). The
  policy is `PRIVACY.md` at the root of the repository (with a contact address); the
  Confidentialité page (5.9) shows its five sections word for word and links to it.

---

## 9. External services (verified 2026-10-04, no key needed)

| Purpose | Endpoint | Notes |
|---|---|---|
| Map tiles + style | `https://tiles.openfreemap.org/styles/liberty` (or `positron`) | OSM vector tiles for MapLibre. Offline download through `maplibre_gl` offline regions; check OpenFreeMap's terms on bulk download in the spike task |
| Street under a tap | `https://data.geopf.fr/geocodage/reverse?lon={lon}&lat={lat}&index=address&type=street&limit=1` | Returns BAN `id` = idVoie (`69264_1460`), `name`, `citycode`, `city`, one point of the street; always the nearest street, whatever the distance |
| Street search by name | `https://data.geopf.fr/geocodage/search?q={q}&index=address&type=street&citycode={code}&limit=10` | For the search box; `q` 3–200 characters starting with a letter or digit, else HTTP 400 |
| Commune by name | `https://geo.api.gouv.fr/communes?nom={q}&fields=nom,code,codesPostaux,centre&boost=population&limit=5` | « Liste » of « Ajouter des rues » (5.4), the communes of a secteur (5.2, 5.8): `nom`, `code` (INSEE), `codesPostaux`, `centre` (GeoJSON point); `[]` when nothing matches |
| Commune by name, fallback | `https://data.geopf.fr/geocodage/search?q={q}&type=municipality&limit=5` | Asked only when geo.api.gouv.fr fails (transport error, timeout, non-200, unreadable answer; it refused connections for a minute on 2026-11-10, #137): `name`, `citycode` (INSEE), one `postcode`, the point as centre; ranked by its score, not by population; `q` 3–200 characters, else HTTP 400 |
| Streets of a commune | `https://plateforme.adresse.data.gouv.fr/lookup/{inseeCode}` | `voies[]`: `idVoie`, `nomVoie`, `nbNumeros`, `type`; 404 for an unknown commune |
| Numbers of a street | `https://plateforme.adresse.data.gouv.fr/lookup/{idVoie}` | `numeros[]`: `numero`, `suffixe`, `position.coordinates` [lon, lat]; a number may appear twice; 404 for an unknown street |
| Road segments with their BAN ids (§5.18, #166) | `https://data.geopf.fr/wfs/ows?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetFeature&TYPENAMES=BDTOPO_V3:troncon_de_route&OUTPUTFORMAT=application/json&SRSNAME=EPSG:4326&PROPERTYNAME=…&COUNT=1000` + `CQL_FILTER=BBOX(geometrie,minLat,minLon,maxLat,maxLon,'urn:ogc:def:crs:EPSG::4326') AND (identifiant_voie_ban_gauche='{idVoie}' OR identifiant_voie_ban_droite='{idVoie}')` (a street: its houses plus 2 km) or `BBOX=minLat,minLon,maxLat,maxLon,urn:ogc:def:crs:EPSG::4326` (a tap, a zone) | IGN BD TOPO, Licence Ouverte 2.0 (credit « IGN (BD TOPO) »). Per segment: `identifiant_voie_ban_gauche/_droite`, `nom_voie_ban_*`, `insee_commune_*`, `nom_collaboratif_*`, `geometrie` (LineString, lon/lat + altitude). A segment may carry no BAN id. ≈ 0.1–0.35 s (2026-11-13); the id filter **without** a `BBOX` takes 16–20 s (no index), hence the box. `numberMatched` tells how many the area holds past `COUNT` |
| Shape of a street (fallback from §5.18) | OpenFreeMap TileJSON `https://tiles.openfreemap.org/planet` (its `tiles` template, versioned weekly: `…/planet/20261011_080001_pt/{z}/{x}/{y}.pbf`), then the z14 vector tiles around the street's houses, layer `transportation_name`, property `name` (§6.1, #92) | Same data as the map. A tile ≈ 50–250 kB, ≈ 0.1 s; max zoom 14. Lines clipped per tile with a buffer: cut and joined by the app. Fallback when empty: no shape, house dots only. Replaced Overpass (#92: 41 s then 502 on 2026-10-18) |

All of them are wrapped behind domain interfaces (`AddressDirectory`, `CommuneSearch`, `StreetShapes`), so the rest
of the app never sees HTTP or JSON, and tests use fakes. Parsing is tested against JSON fixtures
captured from the real services.

**No network or a service down (#137).** A call that gets no answer is `noNetwork` only when
the phone has no way out: the service's name not found (airplane mode, no signal), no route to
the network (`ENETUNREACH`, `EHOSTUNREACH`, an OS connect timeout), or no answer within the
adapter's timeout (`infrastructure/http/no_network.dart`, shared by the BAN, geopf, commune and
tiles adapters). A refused or reset connection, a TLS failure, a connection cut mid-answer, an
HTTP error or an unreadable answer is `serviceError`: the screens then say « Impossible de
<what the user does> pour l'instant. Réessayez plus tard. » instead of « Pas de réseau ».

---

## 10. Architecture and tech stack

### 10.1 Layers (strict DDD, hexagonal)

```
lib/
├── domain/          Pure Dart. Aggregates, entities, value objects, domain services,
│   ├── sector/     repository ports. Imports nothing but dart:core / dart:math / collection.
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
  `AddManualStreet`, `EditStreetNumbers`, `DescribeBuilding`, `CreateSector`,
  `RequestToJoin`, `AcceptMember`, `DownloadSector`, `StartCampaign`, … A use case loads the
  aggregate through its port, calls the root, saves the `StreetChange` through the port.
- **One exception to « aggregates change only through their root »:** a request to join
  (`RequestToJoin`) adds a pending member without the `Sector` root, since the newcomer cannot
  read the secteur; the domain value `JoinRequest` builds it (pending, no acceptance, the code
  used) and the security rules check the same on the server (§8.2, #157).
- **Adapters translate**: Firestore maps ⇄ aggregates, `StreetChange` → field-path updates,
  geopf / BAN JSON, vector tiles → value objects. Translation code is pure functions, tested alone.
- The map is split the same way: the domain computes *what* to draw; `ui/map/` only turns that
  into MapLibre GeoJSON sources and layers, and taps into coordinates. The map's read models
  (`domain/map/`: `MapLayers`, `HouseDotStatus`, `PartDrawing`, `PartDotLook`) are projections
  of the aggregates with display words (« dot », « look »); they stay in the domain on purpose,
  pure Dart and tested there, since what the map shows is a domain decision (decided 2026-11-11,
  #159).

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
| Reminders | `flutter_local_notifications` (+ `timezone`), local and inexact, no push (#82, §5.17); Android needs core-library desugaring and compileSdk 37 for it |
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
| Widgets | widget tests for the critical interactions only: welcome gating, tap-cycle + undo on street tiles, hold → house sheet (to become: tap → status picker → ✓ / don / ⊘ / ↻ steps + undo, calendars badge, #63), building grid, edit mode remove + undo, street card, ticking and adding streets on « Ajouter des rues », join pending screen | `flutter test` (headless) | end of each UI task, CI | a few per UI task; the whole suite stays under 60 s |
| Architecture | import rules between layers | Dart VM | every run | < 1 s |
| Coverage | **100 % line coverage** on `domain/`, `application/`, `presentation/` and the adapters' mapping code, checked by a script on `coverage/lcov.info` | — | end of task, CI | piggybacks |
| Rules | Firestore security rules in the Firebase emulator (`@firebase/rules-unit-testing`, `node --test`): `cd firebase && npm ci && npm test` starts the emulator itself (`firebase emulators:exec`, demo project, versions pinned: firebase-tools 15, rules-unit-testing 5, Node 20+, Java 11+) | Node + emulator | when `firebase/` or the Firestore adapters change, CI | < 1 min |
| Instrumented | `integration_test/`: a handful of end-to-end flows in the real app, ≤ 10 tests over both files. `app_test.dart` (launch, mark a house + undo, building, edit a street, offline cold start…) on the real project, Firestore offline. `admin_test.dart` (create a secteur, « Tous les secteurs » → Rejoindre, revocation → « Vous n'êtes plus administrateur. ») against the local Auth + Firestore emulators with the real rules: the test adds and removes `admins/{uid}` itself (`tool/admin_e2e.sh`) | Android emulator (`Medium_Phone_API_36.1`), run by Claude | before every push to `main` | < 3 min |
| Device | Manual checklist on your phone: map render, tap-to-add, offline download, **airplane-mode day** (cold start, mark, restart, reconnect, sync), QR scan | your phone | after every task, and the full checklist before release | — |

**No mutation-testing gate:** Dart has no maintained equivalent of Pitest. To compensate, the
developer agent follows explicit test-writing rules: each branch gets a test whose values would
fail if the condition were inverted or a boundary moved by one; every field of a returned value
object is asserted, not just equality of the whole; no test without an assertion on behaviour.

The MapLibre widget and the offline tile download are SDK glue, kept thin, outside the
gated paths, and covered by the device checklist: `infrastructure/maplibre_offline/` holds
only the adapter and its mapper (`mappers/`, gated); the decisions (which bounds, when to
delete, stalls, retries) are in the use cases and `presentation/offline/`, tested with fakes.

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
| M4 | Offline: automatic, invisible download (cache + tiles, silent map refresh), pending-writes indicator, what « Mes secteurs » / Paramètres show of it (#33), airplane-mode checklist | a full day without network |
| M5 | Polish and release: dark mode, accessibility (TalkBack, 200 % font), icon, privacy policy, Play listing | store-ready |
| M8 | Status picker and tournées (#63): a tap shows the five statuses with « Refusé » (§5.6), calendars per house, tournées with dons per payment method, recap, Collecte (§5.13), rules; « Secteur » and the code glossary | a tournée counted to the cent, validated, seen by the secteur |
| M6 (v1.1) | Nouvelle campagne: copy / reset, *Reprendre mes rues*, last year's result in the sheets, read-only archive | secteur 49 starts 2027 from 2026 |

M1 comes before Firebase on purpose: the street screen is where the app succeeds or fails,
and a real reference area stored on the phone lets you try it in the street before any backend
exists. No invented data at any stage.

---

## 13. Decisions from the review (2026-10-04)

| # | Question | Answer |
|---|---|---|
| Q1 | Join code | 6 random characters without look-alikes (`K7P-2QX`, ≈ 887 M combinations), shared as a QR code too. The secteur number is displayed but never used to join. |
| Q2 | Who deletes what | Any member adds, edits and deletes streets. Only the creator deletes the secteur or removes members. **From #75: only admins** (5.12). |
| Q3 | "Refused" status | **No.** The app never records residents' choices or amounts: only whether the door was visited. |
| Q4 | Several secteurs per person | Yes. The app opens the last one; the title on Accueil switches (Q21). |
| Q5 | App id | `fr.mandarine.tourneecalendriers`, store name "Tournée Calendriers". |
| Q6 | Public repo | Yes: `google-services.json` is gitignored and injected in CI from a secret. |
| Q7 | minSdk | 26 (Android). iOS 15+ later. |
| Q8 | Street selection | On a map: tap roads to tick them → add them at once (5.14, #124; before: a street card per road). Manual entry for what the map or BAN lacks. |
| Q9 | Where the map lives | Accueil = map + streets panel; "Ajouter des rues" is a map mode, opened from Secteur since 5.14 (replaces the Sector list). |
| Q10 | Progress on the map | Streets coloured by progress; houses as status dots when zoomed in. |
| Q11 | Offline | Download of the secteur (data + map tiles), then fully offline, sync when possible. **Changed 2026-11-01 (#32): automatic and invisible** — the app downloads the open secteur whenever it is online, refreshes the maps silently (weekly tile versions), retries every 2 minutes after a failure; no button, banner or progress (§7). |
| Q12 | Language | French only. |
| Q13 | Adding streets | The map mode is called *Ajouter des rues*. |
| Q14 | Correcting streets | Edit mode on the street screen (✏): remove / add / rename numbers, rename, make a building, stop covering, delete. Manual street always reachable from *Ajouter des rues*. |
| Q15 | Buildings | Described by floor (and staircase when several); one row per floor, top to bottom. |
| Q16 | Secteur identity | Number + centre de secours + code. Number + CS unique; CS picked from a shared list. Joining needs only the code (or QR), with a confirmation of number + CS. |
| Q17 | Next year | One campaign per year inside the secteur. New campaign keeps streets, numbers, buildings; resets statuses, *repasser*, assignees; *Reprendre mes rues 2026*; last year's result shown in the sheets. v1.1, model ready in v1. |
| Q18 | Who starts a campaign, what is kept | The creator (an admin from #75, 5.12). Previous campaign read-only; the one before is deleted. |
| Q19 | Guessed / leaked codes | A code only creates a pending request; any accepted member accepts or refuses. App Check in v1. Soft delete with a 30-day Corbeille. |
| Q20 | Infrastructure | **Decided at the M2 checkpoint (2026-10-05): Spark (free), Blaze-ready.** Join on the phone (`joinCodes` get → pending member) behind a `SectorDirectory` port; App Check + approval are the guard; the Corbeille purge runs on members' phones (5.11). Move to Blaze (1 click, no data migration) and a rate-limited callable join + scheduled purge when real usage nears Spark's shared daily quota (50 k reads, 20 k writes for the whole app ≈ 10 busy secteurs a day) or abuse shows up. Another backend was rejected: it loses Firestore's offline cache. |
| Q21 | Switching / creating from Accueil | The title is a button: « Mes secteurs » sheet with all my secteurs (progress, pending requests), *Créer*, *Rejoindre*. Since #135 the title opens Secteur, whose first row « Changer de secteur » opens that sheet. |
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
