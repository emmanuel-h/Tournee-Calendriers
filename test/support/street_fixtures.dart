// Literal values shared by the street tests. Every place is in
// Villefranche-sur-Saône (INSEE 69264): the only real place tests may name.
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling_label.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';

import 'results.dart';

/// A house number the test knows is valid: `n('12bis')`.
HouseNumber n(String text) => valueOf(HouseNumber.parse(text));

/// A « repasser » with a hint the test knows is valid.
ComeBack comeBack(String hint) => valueOf(ComeBack.create(hint));

/// A street name the test knows is valid.
StreetName streetName(String text) => valueOf(StreetName.create(text));

/// An INSEE code the test knows is valid: `insee('69264')`.
InseeCode insee(String text) => valueOf(InseeCode.parse(text));

final villefranche = valueOf(
  Commune.create(inseeCode: '69264', name: 'Villefranche-sur-Saône'),
);

/// The entrance of a house in the centre of Villefranche-sur-Saône.
final townHallDoor = valueOf(
  GeoPoint.create(latitude: 45.98915, longitude: 4.71862),
);

/// Another entrance, a little further north.
final northDoor = valueOf(
  GeoPoint.create(latitude: 45.99210, longitude: 4.71705),
);

final lea = MemberId('lea');
final paul = MemberId('paul');

final twoPm = DateTime.utc(2026, 11, 2, 14, 2);
final threePm = DateTime.utc(2026, 11, 2, 15);

final leaAtTwo = ChangeStamp(by: lea, at: twoPm);
final paulAtThree = ChangeStamp(by: paul, at: threePm);

/// A dwelling label the test knows is valid: `d('51')`.
DwellingLabel d(String text) => valueOf(DwellingLabel.parse(text));

final escA = StaircaseName('A');
final escB = StaircaseName('B');
