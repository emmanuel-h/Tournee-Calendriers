# Screen mockups

Source of the visual mockups for `docs/PLAN.md` §5, one `.dc.html` file per screen
(`Main.dc.html` is the Street screen). `NoSector.dc.html` is Accueil with no secteur open
(PLAN §5.0, #119): the base map, « Aucun secteur ouvert » and « Rejoindre un secteur »
(« Créer un secteur » for an admin only); it replaced `Start.dc.html` (« Mes rues » of M1) and
`Import.dc.html` (« Importer des rues »), removed with the phone-only streets.
`Doors.dc.html` is « Modifier les portes » (PLAN §5.7), opened from « Gérer l'immeuble » under a
building's grid (`Building.dc.html`). `AllTournees.dc.html`, `HomeAdmin.dc.html` and `TeamMember.dc.html` are the admin
screens of PLAN §5.12 (#75): `Team.dc.html` is Équipe seen by an admin, `TeamMember.dc.html` by a
member; `Welcome.dc.html` shows a phone that is not an admin. `AddList.dc.html` is the « Liste » tab of « Ajouter des rues » (#78, next to the map's « Carte » tab in `Pick.dc.html`); `Create.dc.html` picks the secteur's communes (#78). `HouseNobody.dc.html` shows the tries with nobody home and « Repassé, toujours personne » (#80); `HouseComeBack.dc.html` is the sheet a tap to ↻ opens, with the day + hour « Quand repasser ? » that replaces the free hint on every sheet (#81). The secteur download is automatic and invisible (M4): no banner on `Home.dc.html`, one line in `Settings.dc.html`, and `Switcher.dc.html` shows, greyed, a secteur that cannot open offline (« Disponible avec réseau »). `icon/launcher_icon.svg` is the approved launcher icon (#101): a chrome F1 helmet on a street map in the app's colours, its `background` and `foreground` groups being the two adaptive-icon layers; `icon/preview.png` shows it in the round and squircle masks and at 96 / 48 dp. In the app (#101) the layers are the vector drawables `android/app/src/main/res/drawable/ic_launcher_{background,foreground}.xml`, now the source of truth; `ic_launcher_monochrome.xml` (Android 13+ themed icons) is the helmet silhouette alone, larger, with the visor and the dial cut out. The launch screen is the foreground (helmet + ✓) on Ground `#F3F1EC`, `#15181C` in dark mode. `tool/render_play_icon.py` renders the 512 px Play icon from the drawables into `store/listing/`. All copy is French, as in the app.

**Status picker and tournées (#63, agreed 2026-11-02, to build):** a tap on a house or a door shows its five statuses (✓ Fait, ⊘ Refusé, ✗ Personne, ↻ Repasser, ○ À faire) and one tap stores one; only ✓ during a tournée (« Montant du don ») and ↻ (the day and hour) ask for more (PLAN §5.6). `Main.dc.html` is the street screen with it (a ⊘ tile, n° 9 with the « 2 » badge of its calendars), `House.dc.html` the picker on a house to do, `HouseNobody.dc.html` on a house ✗ again (« De nouveau personne »), `HouseComeBack.dc.html` the ↻ step; the door grid (`Building.dc.html`) opens the same picker on a door. No hold, no Fiche maison. On Accueil (`Home`, `HomeAdmin`, `RunStart`, `RunHome`) « + Ajouter des rues » is a muted row after the streets. The row « Tournées et collecte (#63) » holds the outings (PLAN §5.13; the team's area is now the « secteur »): `RunStart.dc.html` and `RunHome.dc.html` (Accueil without and with a tournée), `RunStreet.dc.html` (a ✓ house during a tournée, « + Ajouter un don »), `RunDons.dc.html` (« Dons de la tournée »), `RunDon.dc.html` (« Modifier le don »), `RunRecap.dc.html` (« Bilan de la tournée », with « Abandonner la tournée » in red text under « Continuer la tournée » and its confirmation, #136), `RunTeam.dc.html` (Équipe with « COLLECTE 2026 », no money per member) and `Cash.dc.html` (« Collecte 2026 »).

**Préparer / partir en tournée (PLAN §5.14, agreed 2026-11-03; built in #120–#125 (« Ajouter des rues » with several roads in #124, a zone in #125)):** two moments on two different screens. No attribution: every member covers the whole secteur, so « Mes rues » / « Autres rues », « libre », « Équipe : n % », the streets per member and « Ne plus la faire » are gone from `Home`, `HomeAdmin`, `HomeZoom`, `RunStart`, `RunHome`, `Team`, `TeamMember`, `RunTeam` and `Edit`. The 👥 button became « Secteur », a folded map (`Icons.map_outlined`), then went with #135: Accueil's title (`Home`, `HomeAdmin`, `HomeZoom`, `RunStart`) opens Secteur and carries the red dot of a waiting request (« Secteur 49 · 2026, CS Villefranche, 1 demande en attente »), and Secteur (`Team`, `TeamMember`, `RunTeam`) starts with « ⇄ Changer de secteur › », which opens « Mes secteurs » (`Switcher`). Secteur (`Team`, `TeamMember`, `RunTeam`) holds « RUES (n) » with « + Ajouter des rues » and the Corbeille; Accueil no longer has the add row. `Pick.dc.html` is the map with several roads ticked and the selection sheet (« Ajouter 2 rues »); `PickZone.dc.html` is « Zone », a rectangle and the streets found in it. Since #134 « Ajouter N rues » stays on the screen (the snackbar there), a zone is drawn at any zoom and two fingers move the map in « Zone ». `RunHome.dc.html` and `RunStreet.dc.html` show the « En tournée » band on top (white, red edge on the left) (it replaces the tournée card); `StreetIdle.dc.html` is the street with no tournée: a tap says « Commencez une tournée pour marquer les maisons. » with « Commencer ». `Home.dc.html` predates the tournées; `RunStart.dc.html` is the reference for Accueil without a tournée.

**Partie de la rue (PLAN §5.15, #133, agreed 2026-11-11, to build):** a street split between secteurs. `StreetPart.dc.html` is the full screen « Partie de la rue »: « Les deux | Impairs | Pairs », two marks that slide along the road and snap between two house dots (« entre 5 et 7 »), the kept stretch as the selected road, another secteur's stretch hatched (« Secteur 12 ») with the shared numbers amber, the result « Impairs 7–21 · pairs 2–30 », and a warning (never a block) when numbers are also in another secteur. It opens from « Toute la rue › » under each row of the selection sheet (`Pick.dc.html`; « Pairs 2–8 › » once a part is chosen, the count following) and from the « Partie de la rue » row under the name in edit mode (`Edit.dc.html`).

Status: **awaiting approval**. Once approved, these are the visual reference for the `ui/` code:
the colours, type, spacing and status treatments below are the design tokens.

| Token | Light | Dark (T5.1) | Use |
|---|---|---|---|
| Ground | `#F3F1EC` | `#15181C` | screen background |
| Surface | `#FFFFFF` | `#1F2328` | cards, sheets, to-do tiles |
| Ink | `#1B1F24` | `#ECEAE5` | text |
| Muted | `#4A5058` | `#A9AFB7` | secondary text |
| Line | `#CFC9BD` / `#E2DED5` | `#6B737E` / `#2E3238` | borders / dividers |
| Accent | `#B3261E`, white text | `#E5766F`, `#1B1F24` text | primary buttons, red text |
| Alert | `#FBE9E7` bg, accent border, ⚠ | `#3A1F1D` bg | a warning (« Le secteur 49 … existe déjà ») |
| Done | `#1E6B47` bg, white text, `✓` | `#237A51` bg, white text, border `#2E9463` | |
| Done ink | `#1E6B47` | `#33A872` | the done green as text, mark or progress bar on Surface / Ground |
| Nobody home | `#F2B33D` bg, ink text, `✗` | same, `#1B1F24` text | |
| Nobody home, tries block | `#FDF3DC` bg, button outlined `#D99A22`; greyed (`#F3F1EC`) unless ✗ / ↻ | `#3A2F17` bg; greyed `#15181C` | house and door sheets (#80); tiles add « ×N » from 2 tries |
| Come back | `#D6E6F5` bg, `#1D4E7A` text, `↻` | `#1D3B57` bg, `#D6E6F5` text, border `#3A6A96` | |
| Building partial | `#EFE9DD` bg, dashed border, `◐ n/m` | `#2B2822` bg, `#ECEAE5` text, border `#6B6558` | |
| Building (any status) | 20px building icon before the number, 10×20 `›` at the right edge, text colour | same | tap opens the grid |
| Snackbar | `#1B1F24` bar, white text, `#F2B33D` action | `#ECEAE5` bar, `#1B1F24` text, `#9A3412` action | undo |
| Map: street faite | `#1E6B47` line | same | the base map stays light in dark mode |
| Map: street en partie | `#E0A21B` line | same | |
| Map: street à faire | `#2F5DA8` line | same | |
| Map: selected road | `#1B1F24` casing, white core | same | |
| Map: Partie de la rue | road `#CFC9BD`; dot kept `#1B1F24`, left out `#FFFFFF` in `#4A5058`, other side `#E2DED5` in `#CFC9BD`; marks `#1B1F24` / `#FFFFFF` | same | `StreetPart.dc.html` (#139) |
| Map: other secteurs | stretch: `#FFFFFF` band at 0.7 crossed by diagonal `#4A5058` bars (a repeated picture), beside the road on its side; dot shared `#F2B33D` in `#1B1F24`; warning `#FDF3DC` bg, `#D99A22` border, ⚠ | dots same; warning `#3A2F17` bg | `StreetPart.dc.html` (#141) |
| Fonts | Atkinson Hyperlegible (text), Barlow Condensed (numbers, titles) | same | |

No screen shows a free note: it was removed for privacy (PLAN §8.3, Q23, T1.20). The house,
door and building sheets have no note field and no privacy hint, tiles and doors no note dot,
and the button under the building grid reads « Repasser ». The « Quand repasser ? » hint
(≤ 20 characters) is the only free text.
