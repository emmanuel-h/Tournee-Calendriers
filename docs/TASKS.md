# Tasks

**Tasks live in GitHub issues** — that is where their status, discussion and acceptance criteria
are tracked. This file is only a map of them.

- All tasks: https://github.com/emmanuel-h/Tournee-Calendriers/issues?q=label%3Atask
- By milestone: https://github.com/emmanuel-h/Tournee-Calendriers/milestones
- Needing you (accounts, decisions, phone in hand): https://github.com/emmanuel-h/Tournee-Calendriers/issues?q=is%3Aopen+label%3Amanual

How it works:

- One issue = one run of the `developer` agent = one reviewed commit (`Refs #N`), pushed to
  `main`, tested on the emulator by Claude, then on your phone by you.
- **An issue is closed only when you say so** (after your phone test).
- Issues are ordered; an issue only depends on those above it in its milestone and in earlier
  milestones.
- Label `manual` = a step only you can do; `checkpoint` = a decision we take together;
  `spike` = throwaway exploration whose deliverable is a report.
- New work found along the way becomes a new issue in the right milestone, not an edit here.

## Reference area (M1)

M1 runs on real BAN streets, stored on the phone until Firestore takes over in M2. The field-test
area is **chosen and kept private**: it is typed in on the phone and never appears in this repo.
Fixtures, examples and screenshots use **Villefranche-sur-Saône** (public data).


## M0 Foundations

| Issue | Task | Labels |
|---|---|---|
| [#1](https://github.com/emmanuel-h/Tournee-Calendriers/issues/1) | T0.1 Project skeleton and guard rails |  |
| [#2](https://github.com/emmanuel-h/Tournee-Calendriers/issues/2) | T0.2 Design system and app shell |  |
| [#3](https://github.com/emmanuel-h/Tournee-Calendriers/issues/3) | T0.3 Continuous integration |  |
| [#4](https://github.com/emmanuel-h/Tournee-Calendriers/issues/4) | T0.4 Spike: map and offline tiles | spike |

## M1 The street, on a real area

| Issue | Task | Labels |
|---|---|---|
| [#5](https://github.com/emmanuel-h/Tournee-Calendriers/issues/5) | T1.1 House numbers and statuses (domain) |  |
| [#6](https://github.com/emmanuel-h/Tournee-Calendriers/issues/6) | T1.2 Street aggregate |  |
| [#7](https://github.com/emmanuel-h/Tournee-Calendriers/issues/7) | T1.3 Buildings (domain) |  |
| [#8](https://github.com/emmanuel-h/Tournee-Calendriers/issues/8) | T1.4 Editing numbers (domain) |  |
| [#9](https://github.com/emmanuel-h/Tournee-Calendriers/issues/9) | T1.5 BAN adapter (real streets and numbers) |  |
| [#10](https://github.com/emmanuel-h/Tournee-Calendriers/issues/10) | T1.6 Street use cases and on-phone storage |  |
| [#46](https://github.com/emmanuel-h/Tournee-Calendriers/issues/46) | T1.6b Status glyphs drawn at a consistent size |  |
| [#11](https://github.com/emmanuel-h/Tournee-Calendriers/issues/11) | T1.7 Street screen |  |
| [#12](https://github.com/emmanuel-h/Tournee-Calendriers/issues/12) | T1.8 House sheet |  |
| [#13](https://github.com/emmanuel-h/Tournee-Calendriers/issues/13) | T1.9 Building grid and "Décrire l'immeuble" |  |
| [#14](https://github.com/emmanuel-h/Tournee-Calendriers/issues/14) | T1.10 Edit mode and "Ajouter des numéros" |  |
| [#15](https://github.com/emmanuel-h/Tournee-Calendriers/issues/15) | T1.11 Field build on the reference area | manual |
| [#54](https://github.com/emmanuel-h/Tournee-Calendriers/issues/54) | T1.12 Adjust one floor of a building | |
| [#55](https://github.com/emmanuel-h/Tournee-Calendriers/issues/55) | T1.13 Draw the « → » of the undo messages | |
| [#56](https://github.com/emmanuel-h/Tournee-Calendriers/issues/56) | T1.14 Keep a street name typed in edit mode | |
| [#57](https://github.com/emmanuel-h/Tournee-Calendriers/issues/57) | T1.15 Keep focus on a refused name, no wrap inside « » | |
| [#58](https://github.com/emmanuel-h/Tournee-Calendriers/issues/58) | T1.16 « Repasser » becomes a fourth status | |
| [#59](https://github.com/emmanuel-h/Tournee-Calendriers/issues/59) | T1.17 Re-import a street from the Corbeille | |
| [#60](https://github.com/emmanuel-h/Tournee-Calendriers/issues/60) | T1.18 One building screen and per-staircase setup | |
| [#61](https://github.com/emmanuel-h/Tournee-Calendriers/issues/61) | T1.19 Copy and « Modifier les portes » fixes | |
| [#62](https://github.com/emmanuel-h/Tournee-Calendriers/issues/62) | T1.20 Remove the note field | |

Later, to design with you: [#63](https://github.com/emmanuel-h/Tournee-Calendriers/issues/63) Runs and
money recap (global amounts per payment method, never per house).

The temporary start screen of #15 was built right after #46, before the street screen, so every
later screen could be checked with real streets (decided with you on 2026-10-04).

## M2 Team and sync

| Issue | Task | Labels |
|---|---|---|
| [#16](https://github.com/emmanuel-h/Tournee-Calendriers/issues/16) | T2.0 Infrastructure checkpoint | manual, checkpoint |
| [#17](https://github.com/emmanuel-h/Tournee-Calendriers/issues/17) | T2.1 Firebase project and bootstrap | manual |
| [#68](https://github.com/emmanuel-h/Tournee-Calendriers/issues/68) | T2.1b App Check registration and enforcement | manual |
| [#67](https://github.com/emmanuel-h/Tournee-Calendriers/issues/67) | T2.1c Wait for or retry the anonymous sign-in |  |
| [#18](https://github.com/emmanuel-h/Tournee-Calendriers/issues/18) | T2.2 Tournée aggregate (domain) |  |
| [#19](https://github.com/emmanuel-h/Tournee-Calendriers/issues/19) | T2.3 Firestore adapters |  |
| [#20](https://github.com/emmanuel-h/Tournee-Calendriers/issues/20) | T2.4 Security rules |  |
| [#21](https://github.com/emmanuel-h/Tournee-Calendriers/issues/21) | T2.5 Onboarding screens |  |
| [#22](https://github.com/emmanuel-h/Tournee-Calendriers/issues/22) | T2.6 Équipe and Corbeille |  |
| [#72](https://github.com/emmanuel-h/Tournee-Calendriers/issues/72) | T2.6b Purge the Corbeille after 30 days |  |
| [#73](https://github.com/emmanuel-h/Tournee-Calendriers/issues/73) | T2.6c A removed member, or a deleted tournée, leaves « Mes tournées » |  |
| [#23](https://github.com/emmanuel-h/Tournee-Calendriers/issues/23) | T2.7 Mes tournées and Paramètres |  |
| [#71](https://github.com/emmanuel-h/Tournee-Calendriers/issues/71) | T2.7b A new first name reaches the team |  |
| [#24](https://github.com/emmanuel-h/Tournee-Calendriers/issues/24) | T2.8 Street screen on Firestore |  |
| [#25](https://github.com/emmanuel-h/Tournee-Calendriers/issues/25) | T2.9 Pending-sync indicator |  |
| [#75](https://github.com/emmanuel-h/Tournee-Calendriers/issues/75) | Only admins add a centre de secours, create a tournée or draw a new code | checkpoint |
| [#76](https://github.com/emmanuel-h/Tournee-Calendriers/issues/76) | Copy button next to the code |  |
| [#77](https://github.com/emmanuel-h/Tournee-Calendriers/issues/77) | Licences page keeps loading on the phone |  |
| [#83](https://github.com/emmanuel-h/Tournee-Calendriers/issues/83) | « Version » opens Nouveautés; licences get their own row |  |

## M3 Map and streets

| Issue | Task | Labels |
|---|---|---|
| [#26](https://github.com/emmanuel-h/Tournee-Calendriers/issues/26) | T3.1 Geometry and map layers (domain) |  |
| [#27](https://github.com/emmanuel-h/Tournee-Calendriers/issues/27) | T3.2 Address and shape adapters |  |
| [#28](https://github.com/emmanuel-h/Tournee-Calendriers/issues/28) | T3.3 Street-picking use cases |  |
| [#29](https://github.com/emmanuel-h/Tournee-Calendriers/issues/29) | T3.4 Map widget |  |
| [#30](https://github.com/emmanuel-h/Tournee-Calendriers/issues/30) | T3.5 Accueil |  |
| [#31](https://github.com/emmanuel-h/Tournee-Calendriers/issues/31) | T3.6 Ajouter des rues |  |
| [#78](https://github.com/emmanuel-h/Tournee-Calendriers/issues/78) | A tournée's commune: map centred on it, map and list to add streets | checkpoint |
| [#80](https://github.com/emmanuel-h/Tournee-Calendriers/issues/80) | Count the visits to a house: « still nobody » on a return |  |
| [#81](https://github.com/emmanuel-h/Tournee-Calendriers/issues/81) | The third tap opens the details to set when to come back |  |
| [#91](https://github.com/emmanuel-h/Tournee-Calendriers/issues/91) | Release the streets of a member removed from the tournée |  |
| [#92](https://github.com/emmanuel-h/Tournee-Calendriers/issues/92) | Take street shapes from the map tiles, and fill the shapes of streets without one |  |
| [#93](https://github.com/emmanuel-h/Tournee-Calendriers/issues/93) | Take a street from « Autres rues de la tournée » on Accueil |  |

## M4 Offline

| Issue | Task | Labels |
|---|---|---|
| [#32](https://github.com/emmanuel-h/Tournee-Calendriers/issues/32) | T4.1 Download the tournée |  |
| [#33](https://github.com/emmanuel-h/Tournee-Calendriers/issues/33) | T4.2 Offline in the UI |  |
| [#34](https://github.com/emmanuel-h/Tournee-Calendriers/issues/34) | T4.3 Airplane-mode day | manual |

## M5 Release (Android)

| Issue | Task | Labels |
|---|---|---|
| [#35](https://github.com/emmanuel-h/Tournee-Calendriers/issues/35) | T5.1 Dark mode and accessibility |  |
| [#36](https://github.com/emmanuel-h/Tournee-Calendriers/issues/36) | T5.2 Identity and store assets |  |
| [#37](https://github.com/emmanuel-h/Tournee-Calendriers/issues/37) | T5.3 Signed release | manual |
| [#69](https://github.com/emmanuel-h/Tournee-Calendriers/issues/69) | Upgrade the rules test tooling past Node 18 |  |
| [#70](https://github.com/emmanuel-h/Tournee-Calendriers/issues/70) | Check bulk street writes entry by entry in the rules |  |
| [#79](https://github.com/emmanuel-h/Tournee-Calendriers/issues/79) | Rewrite the Confidentialité screen | manual |
| [#101](https://github.com/emmanuel-h/Tournee-Calendriers/issues/101) | T5.4 App icon |  |

## M6 Next year (v1.1)

| Issue | Task | Labels |
|---|---|---|
| [#38](https://github.com/emmanuel-h/Tournee-Calendriers/issues/38) | T6.1 Roll-over rules (domain) |  |
| [#39](https://github.com/emmanuel-h/Tournee-Calendriers/issues/39) | T6.2 StartCampaign |  |
| [#40](https://github.com/emmanuel-h/Tournee-Calendriers/issues/40) | T6.3 Campaign UI |  |
| [#82](https://github.com/emmanuel-h/Tournee-Calendriers/issues/82) | Come-back reminders and a list of houses to come back to |  |

## M7 iOS

| Issue | Task | Labels |
|---|---|---|
| [#41](https://github.com/emmanuel-h/Tournee-Calendriers/issues/41) | T7.1 iOS build in the cloud | manual |
| [#42](https://github.com/emmanuel-h/Tournee-Calendriers/issues/42) | T7.2 iPhone pass | manual |

## M9 Prepare, then go out

| Issue | Task | Labels |
|---|---|---|
| [#120](https://github.com/emmanuel-h/Tournee-Calendriers/issues/120) | T9.1 No attribution: the secteur covers all its streets |  |
| [#121](https://github.com/emmanuel-h/Tournee-Calendriers/issues/121) | T9.2 Secteur screen: icon, « Ajouter des rues » moves there |  |
| [#122](https://github.com/emmanuel-h/Tournee-Calendriers/issues/122) | T9.3 Houses are marked only during a tournée |  |
| [#123](https://github.com/emmanuel-h/Tournee-Calendriers/issues/123) | T9.4 « En tournée » band on top |  |
| [#124](https://github.com/emmanuel-h/Tournee-Calendriers/issues/124) | T9.5 Ajouter des rues: tick several roads, add them at once |  |
| [#125](https://github.com/emmanuel-h/Tournee-Calendriers/issues/125) | T9.6 Ajouter des rues: select a zone |  |

## M10 Streets split between secteurs

Planned 2026-11-11 from [#133](https://github.com/emmanuel-h/Tournee-Calendriers/issues/133) (PLAN §5.15, mockup StreetPart).

| Issue | Task | Labels |
|---|---|---|
| [#138](https://github.com/emmanuel-h/Tournee-Calendriers/issues/138) | T10.1 StreetPart: a part per side, stored on the street, changed with the Corbeille |  |
| [#139](https://github.com/emmanuel-h/Tournee-Calendriers/issues/139) | T10.2 « Partie de la rue » screen: marks on the map, opened from edit mode |  |
| [#140](https://github.com/emmanuel-h/Tournee-Calendriers/issues/140) | T10.3 Choose the part when adding streets |  |
| [#141](https://github.com/emmanuel-h/Tournee-Calendriers/issues/141) | T10.4 Shared index of the secteurs' parts, with overlap warning |  |
| [#142](https://github.com/emmanuel-h/Tournee-Calendriers/issues/142) | T10.5 Map: draw only the held stretch of a street |  |

## M11 Audit follow-ups

Planned 2026-11-11 from the security, reliability and DDD audit of that day. The severity is a label of its own (`severity: medium`, `low`, `info`).

| Issue | Task | Labels |
|---|---|---|
| [#143](https://github.com/emmanuel-h/Tournee-Calendriers/issues/143) | T11.1 Keep a validated tournée on the phone until the server has it | severity: medium |
| [#144](https://github.com/emmanuel-h/Tournee-Calendriers/issues/144) | T11.2 Privacy text: campaign erasure not implemented, Android backup, cache of a lost secteur | severity: medium |
| [#145](https://github.com/emmanuel-h/Tournee-Calendriers/issues/145) | T11.3 Collecte: any member can add unattributed tournée summaries | severity: medium |
| [#146](https://github.com/emmanuel-h/Tournee-Calendriers/issues/146) | T11.4 Confirm App Check enforcement and the Spark quota margin | severity: low |
| [#147](https://github.com/emmanuel-h/Tournee-Calendriers/issues/147) | T11.5 Directory documents tell more than needed (sectorKeys, streetParts) | severity: low |
| [#148](https://github.com/emmanuel-h/Tournee-Calendriers/issues/148) | T11.6 Join requests: cheap to flood, easy to impersonate, code kept after a removal | severity: low |
| [#149](https://github.com/emmanuel-h/Tournee-Calendriers/issues/149) | T11.7 Show an unreadable street instead of leaving it out | severity: low |
| [#150](https://github.com/emmanuel-h/Tournee-Calendriers/issues/150) | T11.8 Deleting a secteur can leave documents and index entries behind | severity: low |
| [#151](https://github.com/emmanuel-h/Tournee-Calendriers/issues/151) | T11.9 Map tiles: guard the parser, the tile address and the sizes | severity: low |
| [#152](https://github.com/emmanuel-h/Tournee-Calendriers/issues/152) | T11.10 OrderedWrites: a write never shown stalls its street's queue | severity: low |
| [#153](https://github.com/emmanuel-h/Tournee-Calendriers/issues/153) | T11.11 CI: pin actions by commit and set the token's permissions | severity: info |
| [#154](https://github.com/emmanuel-h/Tournee-Calendriers/issues/154) | T11.12 « tournée » still names the secteur in comments and messages | severity: low |
| [#155](https://github.com/emmanuel-h/Tournee-Calendriers/issues/155) | T11.13 Round: model « validated, not yet sent » and stop hiding the second write's failure | severity: low |
| [#156](https://github.com/emmanuel-h/Tournee-Calendriers/issues/156) | T11.14 Undo stamp is decided in the Firestore adapter | severity: info |
| [#157](https://github.com/emmanuel-h/Tournee-Calendriers/issues/157) | T11.15 Join request builds a Member outside the Sector root | severity: info |
| [#158](https://github.com/emmanuel-h/Tournee-Calendriers/issues/158) | T11.16 IndexedStreetRepository: a change handler written as a repository | severity: info |
| [#159](https://github.com/emmanuel-h/Tournee-Calendriers/issues/159) | T11.17 Map read models live in the domain | severity: info |
