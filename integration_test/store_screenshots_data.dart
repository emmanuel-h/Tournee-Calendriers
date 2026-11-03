// The round shown on the Play Store screenshots
// (`store_screenshots_test.dart`): the tournée 12 of the CS Villefranche,
// seventeen real streets of the centre of Villefranche-sur-Saône (INSEE
// 69264, the only real place the repository may name) and a team of five.
// Everything here is made up but the streets and their shapes, which come
// from OpenStreetMap (© OpenStreetMap contributors, ODbL); no device id,
// no real join code.
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/building/building.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/nobody_home_tries.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../test/domain/sector/sector_fixtures.dart'
    show codeOf, nameOf, villefrancheCommune;
import '../test/support/building_fixtures.dart';
import '../test/support/geo_fixtures.dart';
import '../test/support/results.dart';
import '../test/support/street_fixtures.dart';

/// Saturday 14 November 2026, five to noon: the day of the screenshots.
/// The status bar of the device says 12:00 (`tool/store_screenshots.sh`).
final storeNow = DateTime(2026, 11, 14, 11, 55);

/// [hour]:[minute] on the day of the screenshots.
DateTime _today(int hour, int minute) => DateTime(2026, 11, 14, hour, minute);

final hugo = MemberId('uid-hugo');
final leaOnPhone = MemberId('uid-lea');
final camille = MemberId('uid-camille');
final thomas = MemberId('uid-thomas');
final julie = MemberId('uid-julie');

final _sectorId = SectorId('t12');
final _number = valueOf(SectorNumber.create(12));
final _centre = valueOf(RescueCentre.create('CS Villefranche'));
final _campaign = valueOf(CampaignYear.create(2026));

/// The tournée 12 as « Mes secteurs » keeps it on Léa's phone.
final storeSectorSummary = SectorSummary(
  id: _sectorId,
  number: _number,
  centre: _centre,
  campaign: _campaign,
  status: MemberStatus.active,
);

/// A member of the team, accepted by Hugo, who created the tournée.
Member _member(MemberId id, String name, DateTime at) => Member(
  id: id,
  name: nameOf(name),
  requestedAt: at,
  acceptance: ChangeStamp(by: hugo, at: at),
);

/// The tournée 12 of Hugo, Léa, Camille, Thomas and Julie, over
/// Villefranche-sur-Saône. Its join code is made up.
final storeSector = valueOf(
  Sector.create(
    id: _sectorId,
    number: _number,
    centre: _centre,
    joinCode: codeOf('W8F-3NT'),
    createdBy: hugo,
    createdAt: DateTime(2026, 10, 3, 18),
    currentCampaign: _campaign,
    members: [
      _member(hugo, 'Hugo', DateTime(2026, 10, 3, 18)),
      _member(leaOnPhone, 'Léa', DateTime(2026, 10, 4, 9, 12)),
      _member(camille, 'Camille', DateTime(2026, 10, 4, 10, 30)),
      _member(thomas, 'Thomas', DateTime(2026, 10, 5, 19, 2)),
      _member(julie, 'Julie', DateTime(2026, 10, 6, 8, 45)),
    ],
    communes: [villefrancheCommune],
  ),
);

/// The street screen, the house sheet and the building grid show this one.
final rueDeThizy = StreetId('thizy');

/// The house of Rue de Thizy whose sheet is shown: nobody home once,
/// « repasser » tomorrow at about 18 h.
const comeBackHouse = '11';

/// The immeuble of Rue de Thizy whose grid is shown.
const buildingHouse = '12';

/// The streets of the secteur, each marked by one member: Léa's three
/// (one partly done, one to do, one done) and the others'. A few streets close together: the map
/// fits them with a 300 m margin (`sectorArea`), so a wider round would
/// show them smaller.
List<Street> storeStreets() => [
  _thizy(),
  _plain("Rue d'Alma", leaOnPhone, done: 0, total: 14),
  _plain('Rue Pierre Morin', leaOnPhone, done: 10, total: 10),
  _plain('Rue de Villars', camille, done: 18, total: 18),
  _plain('Rue de la République', camille, done: 6, total: 20),
  _plain('Rue Roland', hugo, done: 12, total: 12),
  _plain('Rue des Jardiniers', hugo, done: 9, total: 24),
  _plain('Rue de la Gare', thomas, done: 0, total: 16),
  _plain('Rue de Stalingrad', thomas, done: 14, total: 14),
  _plain('Rue Victor Hugo', julie, done: 11, total: 30),
  _plain('Rue Corlin', julie, done: 0, total: 12),
  _plain('Rue Nationale', thomas, done: 0, total: 40),
  _plain('Rue de la Paix', camille, done: 8, total: 8),
  _plain('Rue Thivend', camille, done: 3, total: 6),
  _plain('Rue Jean Moulin', hugo, done: 0, total: 10),
  _plain('Rue de Prony', julie, done: 0, total: 6),
  _plain('Rue André Chénier', hugo, done: 4, total: 4),
];

/// A street named [name] of [total] houses numbered 1, 2, 3…, the first
/// [done] done by [markedBy].
Street _plain(
  String name,
  MemberId markedBy, {
  required int done,
  required int total,
}) => valueOf(
  Street.create(
    id: StreetId(name.toLowerCase().replaceAll(RegExp('[^a-z]'), '')),
    name: name,
    commune: villefranche,
    shape: _shapeOf(name),
    houses: [
      for (var i = 1; i <= total; i++)
        House(
          number: n('$i'),
          status: i <= done ? VisitStatus.done : VisitStatus.toDo,
          lastChange: i <= done
              ? ChangeStamp(by: markedBy, at: _today(10, i))
              : null,
        ),
    ],
  ),
);

/// Rue de Thizy, Léa's street of the morning: several houses done, two
/// with nobody home, one to come back to, the immeuble at 12 partly done.
Street _thizy() {
  House house(
    String number,
    VisitStatus status, {
    int tries = 0,
    ComeBack? comeBack,
    int minute = 0,
  }) => House(
    number: n(number),
    status: status,
    tries: valueOf(NobodyHomeTries.create(tries)),
    comeBack: comeBack,
    lastChange: status == VisitStatus.toDo
        ? null
        : ChangeStamp(by: leaOnPhone, at: _today(11, minute)),
  );
  return valueOf(
    Street.create(
      id: rueDeThizy,
      name: 'Rue de Thizy',
      commune: villefranche,
      shape: _shapeOf('Rue de Thizy'),
      houses: [
        house('1', VisitStatus.done, minute: 2),
        house('2', VisitStatus.done, minute: 4),
        house('3', VisitStatus.done, minute: 6),
        house('3bis', VisitStatus.done, tries: 1, minute: 8),
        house('4', VisitStatus.done, minute: 10),
        house('5', VisitStatus.nobodyHome, tries: 1, minute: 12),
        house('6', VisitStatus.done, minute: 14),
        house('7', VisitStatus.done, minute: 16),
        house('8', VisitStatus.done, minute: 18),
        house('9', VisitStatus.done, minute: 20),
        house('10', VisitStatus.nobodyHome, tries: 2, minute: 24),
        house(
          comeBackHouse,
          VisitStatus.comeBack,
          tries: 1,
          comeBack: comeBack('2026-11-15', hour: 18),
          minute: 40,
        ),
        House(number: n(buildingHouse), building: _building()),
        house('13', VisitStatus.toDo),
        house('14', VisitStatus.toDo),
        house('15', VisitStatus.toDo),
        house('16', VisitStatus.toDo),
        house('17', VisitStatus.toDo),
        house('18', VisitStatus.toDo),
        house('19', VisitStatus.toDo),
        house('20', VisitStatus.toDo),
        house('21', VisitStatus.toDo),
        house('22', VisitStatus.toDo),
      ],
    ),
  );
}

/// The immeuble at 12: one staircase, RdC to 4e, three doors a floor;
/// Léa went up this morning.
Building _building() {
  var laidOut = building(topFloor: 4, doors: 3);
  final staircase = escA;
  void mark(
    int level,
    String label,
    VisitStatus status, {
    int tries = 0,
    int minute = 0,
  }) {
    laidOut = laidOut.withDwelling(
      staircase,
      level,
      Dwelling(
        label: d(label),
        status: status,
        tries: valueOf(NobodyHomeTries.create(tries)),
        lastChange: ChangeStamp(by: leaOnPhone, at: _today(11, minute)),
      ),
    );
  }

  mark(0, '01', VisitStatus.done, minute: 26);
  mark(0, '02', VisitStatus.done, minute: 27);
  mark(0, '03', VisitStatus.nobodyHome, tries: 1, minute: 28);
  mark(1, '11', VisitStatus.done, minute: 29);
  mark(1, '12', VisitStatus.comeBack, tries: 1, minute: 30);
  mark(1, '13', VisitStatus.done, minute: 31);
  mark(2, '21', VisitStatus.done, minute: 32);
  mark(2, '23', VisitStatus.nobodyHome, tries: 1, minute: 33);
  mark(3, '31', VisitStatus.done, minute: 35);
  return laidOut;
}

StreetShape _shapeOf(String name) => StreetShape([
  for (final line in _shapes[name]!)
    [for (final (latitude, longitude) in line) at(latitude, longitude)],
]);

/// The streets' lines, from OpenStreetMap.
const _shapes = <String, List<List<(double, double)>>>{
  'Rue de Thizy': [
    [
      (45.98688, 4.71488),
      (45.98681, 4.71506),
      (45.98657, 4.71573),
      (45.98620, 4.71674),
      (45.98607, 4.71710),
      (45.98575, 4.71794),
      (45.98565, 4.71812),
    ],
    [
      (45.98701, 4.71456),
      (45.98701, 4.71466),
      (45.98702, 4.71475),
      (45.98702, 4.71477),
      (45.98704, 4.71490),
    ],
  ],
  "Rue d'Alma": [
    [(45.98554, 4.71810), (45.98556, 4.71794), (45.98557, 4.71786)],
    [(45.98597, 4.71500), (45.98596, 4.71507), (45.98589, 4.71560)],
    [(45.98589, 4.71560), (45.98567, 4.71711)],
    [(45.98557, 4.71786), (45.98567, 4.71711)],
  ],
  'Rue Pierre Morin': [
    [(45.98704, 4.71490), (45.98706, 4.71503), (45.98711, 4.71551)],
    [
      (45.98711, 4.71551),
      (45.98709, 4.71564),
      (45.98718, 4.71657),
      (45.98719, 4.71661),
      (45.98720, 4.71673),
    ],
    [(45.98720, 4.71673), (45.98722, 4.71690), (45.98723, 4.71705)],
  ],
  'Rue de Villars': [
    [
      (45.98617, 4.71765),
      (45.98622, 4.71755),
      (45.98636, 4.71740),
      (45.98642, 4.71735),
      (45.98647, 4.71730),
      (45.98664, 4.71723),
      (45.98681, 4.71717),
      (45.98717, 4.71707),
      (45.98723, 4.71705),
    ],
    [(45.98723, 4.71705), (45.98803, 4.71696)],
    [(45.98604, 4.71816), (45.98610, 4.71798), (45.98617, 4.71765)],
  ],
  'Rue de la République': [
    [
      (45.98720, 4.71673),
      (45.98715, 4.71673),
      (45.98713, 4.71673),
      (45.98620, 4.71674),
    ],
    [(45.98802, 4.71667), (45.98733, 4.71672)],
    [(45.98733, 4.71672), (45.98730, 4.71672), (45.98720, 4.71673)],
  ],
  'Rue Roland': [
    [
      (45.98631, 4.71898),
      (45.98635, 4.71901),
      (45.98641, 4.71903),
      (45.98684, 4.71911),
    ],
    [(45.98723, 4.71918), (45.98740, 4.71920)],
    [(45.98740, 4.71920), (45.98769, 4.71921)],
    [(45.98698, 4.71913), (45.98723, 4.71918)],
    [(45.98684, 4.71911), (45.98698, 4.71913)],
  ],
  'Rue des Jardiniers': [
    [
      (45.98565, 4.71954),
      (45.98572, 4.71957),
      (45.98691, 4.72006),
      (45.98720, 4.72019),
    ],
    [(45.98804, 4.72038), (45.98799, 4.72037), (45.98720, 4.72019)],
  ],
  'Rue de la Gare': [
    [
      (45.98497, 4.71991),
      (45.98495, 4.71998),
      (45.98489, 4.72014),
      (45.98485, 4.72025),
      (45.98482, 4.72033),
      (45.98476, 4.72049),
    ],
    [(45.98476, 4.72049), (45.98474, 4.72053)],
    [(45.98529, 4.71909), (45.98497, 4.71991)],
    [
      (45.98565, 4.71812),
      (45.98563, 4.71819),
      (45.98546, 4.71864),
      (45.98529, 4.71909),
    ],
  ],
  'Rue de Stalingrad': [
    [
      (45.98565, 4.71954),
      (45.98571, 4.71915),
      (45.98572, 4.71885),
      (45.98570, 4.71860),
      (45.98567, 4.71835),
      (45.98566, 4.71819),
      (45.98565, 4.71812),
    ],
    [(45.98544, 4.72095), (45.98546, 4.72086)],
    [(45.98546, 4.72086), (45.98548, 4.72073)],
    [(45.98556, 4.72017), (45.98563, 4.71963), (45.98565, 4.71954)],
    [
      (45.98548, 4.72073),
      (45.98550, 4.72056),
      (45.98553, 4.72037),
      (45.98556, 4.72017),
    ],
  ],
  'Rue Victor Hugo': [
    [(45.98726, 4.71832), (45.98723, 4.71918), (45.98721, 4.71989)],
    [
      (45.98723, 4.71705),
      (45.98727, 4.71741),
      (45.98728, 4.71749),
      (45.98726, 4.71832),
    ],
    [(45.98721, 4.71989), (45.98720, 4.72019), (45.98719, 4.72072)],
    [
      (45.98719, 4.72072),
      (45.98718, 4.72107),
      (45.98718, 4.72110),
      (45.98714, 4.72128),
    ],
  ],
  'Rue Corlin': [
    [
      (45.98728, 4.71749),
      (45.98745, 4.71751),
      (45.98805, 4.71762),
      (45.98807, 4.71762),
      (45.98890, 4.71778),
      (45.98896, 4.71779),
    ],
  ],
  'Rue Nationale': [
    [
      (45.98565, 4.71812),
      (45.98604, 4.71816),
      (45.98628, 4.71820),
      (45.98639, 4.71822),
      (45.98647, 4.71822),
      (45.98652, 4.71823),
      (45.98666, 4.71825),
      (45.98680, 4.71827),
      (45.98703, 4.71829),
      (45.98726, 4.71832),
    ],
    [
      (45.98726, 4.71832),
      (45.98745, 4.71834),
      (45.98800, 4.71841),
      (45.98813, 4.71843),
      (45.98854, 4.71848),
      (45.98876, 4.71851),
      (45.98900, 4.71854),
      (45.98909, 4.71855),
      (45.98939, 4.71860),
      (45.98976, 4.71865),
      (45.98985, 4.71866),
    ],
  ],
  'Rue de la Paix': [
    [(45.98711, 4.71551), (45.98717, 4.71551), (45.98781, 4.71556)],
  ],
  'Rue Thivend': [
    [(45.98745, 4.71834), (45.98740, 4.71920)],
  ],
  'Rue Jean Moulin': [
    [(45.98567, 4.71711), (45.98542, 4.71709)],
    [(45.98542, 4.71709), (45.98511, 4.71706), (45.98506, 4.71705)],
  ],
  'Rue de Prony': [
    [(45.98571, 4.71915), (45.98574, 4.71914), (45.98631, 4.71898)],
  ],
  'Rue André Chénier': [
    [(45.98542, 4.71709), (45.98536, 4.71791)],
  ],
};
