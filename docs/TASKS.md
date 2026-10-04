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

M1 runs on real BAN streets of an area you choose, stored on the phone until Firestore takes
over in M2. **To choose** — commune: ______ · streets: ______


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
| [#11](https://github.com/emmanuel-h/Tournee-Calendriers/issues/11) | T1.7 Street screen |  |
| [#12](https://github.com/emmanuel-h/Tournee-Calendriers/issues/12) | T1.8 House sheet |  |
| [#13](https://github.com/emmanuel-h/Tournee-Calendriers/issues/13) | T1.9 Building grid and "Décrire l'immeuble" |  |
| [#14](https://github.com/emmanuel-h/Tournee-Calendriers/issues/14) | T1.10 Edit mode and "Ajouter des numéros" |  |
| [#15](https://github.com/emmanuel-h/Tournee-Calendriers/issues/15) | T1.11 Field build on the reference area | manual |

## M2 Team and sync

| Issue | Task | Labels |
|---|---|---|
| [#16](https://github.com/emmanuel-h/Tournee-Calendriers/issues/16) | T2.0 Infrastructure checkpoint | manual, checkpoint |
| [#17](https://github.com/emmanuel-h/Tournee-Calendriers/issues/17) | T2.1 Firebase project and bootstrap | manual |
| [#18](https://github.com/emmanuel-h/Tournee-Calendriers/issues/18) | T2.2 Tournée aggregate (domain) |  |
| [#19](https://github.com/emmanuel-h/Tournee-Calendriers/issues/19) | T2.3 Firestore adapters |  |
| [#20](https://github.com/emmanuel-h/Tournee-Calendriers/issues/20) | T2.4 Security rules |  |
| [#21](https://github.com/emmanuel-h/Tournee-Calendriers/issues/21) | T2.5 Onboarding screens |  |
| [#22](https://github.com/emmanuel-h/Tournee-Calendriers/issues/22) | T2.6 Équipe and Corbeille |  |
| [#23](https://github.com/emmanuel-h/Tournee-Calendriers/issues/23) | T2.7 Mes tournées and Paramètres |  |
| [#24](https://github.com/emmanuel-h/Tournee-Calendriers/issues/24) | T2.8 Street screen on Firestore |  |
| [#25](https://github.com/emmanuel-h/Tournee-Calendriers/issues/25) | T2.9 Pending-sync indicator |  |

## M3 Map and streets

| Issue | Task | Labels |
|---|---|---|
| [#26](https://github.com/emmanuel-h/Tournee-Calendriers/issues/26) | T3.1 Geometry and map layers (domain) |  |
| [#27](https://github.com/emmanuel-h/Tournee-Calendriers/issues/27) | T3.2 Address and shape adapters |  |
| [#28](https://github.com/emmanuel-h/Tournee-Calendriers/issues/28) | T3.3 Street-picking use cases |  |
| [#29](https://github.com/emmanuel-h/Tournee-Calendriers/issues/29) | T3.4 Map widget |  |
| [#30](https://github.com/emmanuel-h/Tournee-Calendriers/issues/30) | T3.5 Accueil |  |
| [#31](https://github.com/emmanuel-h/Tournee-Calendriers/issues/31) | T3.6 Ajouter des rues |  |

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

## M6 Next year (v1.1)

| Issue | Task | Labels |
|---|---|---|
| [#38](https://github.com/emmanuel-h/Tournee-Calendriers/issues/38) | T6.1 Roll-over rules (domain) |  |
| [#39](https://github.com/emmanuel-h/Tournee-Calendriers/issues/39) | T6.2 StartCampaign |  |
| [#40](https://github.com/emmanuel-h/Tournee-Calendriers/issues/40) | T6.3 Campaign UI |  |

## M7 iOS

| Issue | Task | Labels |
|---|---|---|
| [#41](https://github.com/emmanuel-h/Tournee-Calendriers/issues/41) | T7.1 iOS build in the cloud | manual |
| [#42](https://github.com/emmanuel-h/Tournee-Calendriers/issues/42) | T7.2 iPhone pass | manual |
