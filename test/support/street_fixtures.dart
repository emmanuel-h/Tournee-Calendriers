// Literal values shared by the street tests. Every place is in
// Villefranche-sur-Saône (INSEE 69264): the only real place tests may name.
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/note.dart';

import 'results.dart';

/// A house number the test knows is valid: `n('12bis')`.
HouseNumber n(String text) => valueOf(HouseNumber.parse(text));

/// A note the test knows is valid.
Note note(String text) => valueOf(Note.create(text));

/// A « repasser » with a hint the test knows is valid.
ComeBack comeBack(String hint) => valueOf(ComeBack.create(hint));

final villefranche = valueOf(
  Commune.create(inseeCode: '69264', name: 'Villefranche-sur-Saône'),
);

final lea = MemberId('lea');
final paul = MemberId('paul');

final twoPm = DateTime.utc(2026, 11, 2, 14, 2);
final threePm = DateTime.utc(2026, 11, 2, 15);

final leaAtTwo = ChangeStamp(by: lea, at: twoPm);
final paulAtThree = ChangeStamp(by: paul, at: threePm);
