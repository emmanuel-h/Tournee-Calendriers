// « Repasser » shared by the tests of « À repasser » and the reminders
// (PLAN §5.17). Streets of Villefranche-sur-Saône, as every test place.
import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/come_back.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

import '../../support/street_fixtures.dart';

final nationaleId = StreetId('nationale');
final lilasId = StreetId('lilas');
final pinsId = StreetId('pins');
final pasteurId = StreetId('pasteur');

/// The name of each street id above.
final _names = {
  nationaleId: 'Rue Nationale',
  lilasId: 'Rue des Lilas',
  pinsId: 'Allée des Pins',
  pasteurId: 'Rue Pasteur',
};

/// Saturday 24 October 2026, the day the tests look from.
final saturday = day('2026-10-24');

/// The « repasser » of house [number] of [street] (of the door [door]),
/// set by Léa unless [setBy] says otherwise.
ComeBackEntry entry(
  StreetId street,
  String number,
  ComeBack comeBack, {
  DwellingKey? door,
  ChangeStamp? setBy,
  bool nobody = false,
}) => ComeBackEntry(
  place: ComeBackPlace(street: street, number: n(number), door: door),
  streetName: streetName(_names[street]!),
  comeBack: comeBack,
  setBy: nobody ? null : setBy ?? leaAtTwo,
);
