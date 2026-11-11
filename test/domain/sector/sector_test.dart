import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/actor.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector.dart';
import 'package:tournee_calendriers/domain/sector/sector_change.dart';
import 'package:tournee_calendriers/domain/sector/sector_commune.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

import '../../support/results.dart';
import '../../support/scripted_random.dart';
import '../../support/street_fixtures.dart' show insee;
import 'sector_fixtures.dart';

void main() {
  group('createdBy', () {
    final number = valueOf(SectorNumber.create(12));
    final centre = valueOf(RescueCentre.create('CIS Villefranche-sur-Saône'));
    final year = valueOf(CampaignYear.create(2027));
    final at = DateTime.utc(2026, 12, 5, 19, 30);

    Sector created({List<SectorCommune>? communes}) => Sector.createdBy(
      id: SectorId('t12'),
      number: number,
      centre: centre,
      campaign: year,
      joinCode: codeOf('ABC-234'),
      creator: leaId,
      creatorName: nameOf('Léa'),
      at: at,
      communes: communes ?? [gleizeCommune, villefrancheCommune],
    );

    test('should cover the communes picked, in their order', () {
      expect(created().communes, [gleizeCommune, villefrancheCommune]);
    });

    test('should take as many communes as allowed', () {
      final communes = _communes(Sector.maxCommunes);

      expect(created(communes: communes).communes, communes);
    });

    test('should throw when no commune is given', () {
      expect(() => created(communes: []), throwsArgumentError);
    });

    test('should throw when two communes share a code', () {
      final otherCentre = SectorCommune(commune: villefrancheCommune.commune);

      expect(
        () => created(communes: [villefrancheCommune, otherCentre]),
        throwsArgumentError,
      );
    });

    test('should throw when given more communes than allowed', () {
      expect(
        () => created(communes: _communes(Sector.maxCommunes + 1)),
        throwsArgumentError,
      );
    });

    test('should keep its identity when a member creates it', () {
      final sector = created();

      expect(sector.id, SectorId('t12'));
      expect(sector.number, number);
      expect(sector.centre, centre);
      expect(sector.currentCampaign, year);
      expect(sector.joinCode, codeOf('ABC234'));
      expect(sector.createdBy, leaId);
      expect(sector.createdAt, at);
    });

    test('should hold only its creator, active, when it is created', () {
      final sector = created();

      expect(sector.members, [
        Member(
          id: leaId,
          name: nameOf('Léa'),
          requestedAt: at,
          acceptance: ChangeStamp(by: leaId, at: at),
        ),
      ]);
      expect(sector.memberOf(leaId)!.isActive, isTrue);
    });
  });

  group('create (from storage)', () {
    test('should keep every field when the members are valid', () {
      final sector = team();

      expect(sector.id, sectorId);
      expect(sector.number, number49);
      expect(sector.centre, csVillefranche);
      expect(sector.joinCode, firstCode);
      expect(sector.createdBy, manuId);
      expect(sector.createdAt, createdAt);
      expect(sector.currentCampaign, campaign2026);
    });

    test('should have no commune when stored before the communes', () {
      expect(team().communes, isEmpty);
    });

    test('should keep the stored communes in their order', () {
      expect(team(communes: [villefrancheCommune, gleizeCommune]).communes, [
        villefrancheCommune,
        gleizeCommune,
      ]);
    });

    test('should keep as many communes as allowed', () {
      final communes = _communes(Sector.maxCommunes);

      expect(valueOf(_restore([manu], communes: communes)).communes, communes);
    });

    test('should refuse two communes of the same code', () {
      final otherCentre = SectorCommune(commune: villefrancheCommune.commune);

      expect(
        failureOf(
          _restore([manu], communes: [villefrancheCommune, otherCentre]),
        ),
        NewSectorFailure.duplicateCommune,
      );
    });

    test('should refuse more communes than allowed', () {
      expect(
        failureOf(
          _restore([manu], communes: _communes(Sector.maxCommunes + 1)),
        ),
        NewSectorFailure.tooManyCommunes,
      );
    });

    test('should not let the communes be changed from outside', () {
      final communes = team(communes: [villefrancheCommune]).communes;

      expect(() => communes.add(gleizeCommune), throwsUnsupportedError);
    });

    test('should sort the members by request time when they come in any '
        'order', () {
      expect(team(members: [julie, manu, lea]).members, [manu, lea, julie]);
    });

    test('should sort members by id when they asked at the same time', () {
      final early = Member(
        id: MemberId('uid-b'),
        name: nameOf('Bea'),
        requestedAt: julieAskedAt,
      );
      final late = Member(
        id: MemberId('uid-a'),
        name: nameOf('Ali'),
        requestedAt: julieAskedAt,
      );

      expect(
        team(members: [early, manu, late]).members.map((m) => m.id.value),
        ['uid-manu', 'uid-a', 'uid-b'],
      );
    });

    test('should keep a secteur whose creator left', () {
      // The creator has no power of their own any more (PLAN §5.12): they
      // may leave like anyone, and the secteur goes on.
      final sector = valueOf(_restore([lea, julie]));

      expect(sector.createdBy, manuId);
      expect(sector.members, [lea, julie]);
    });

    test('should keep a secteur with no member left', () {
      // Even the last member may leave: admins manage the empty secteur.
      expect(valueOf(_restore([])).members, isEmpty);
    });

    test('should refuse the members when two share an id', () {
      final leaAgain = Member(
        id: leaId,
        name: nameOf('Léa B'),
        requestedAt: julieAskedAt,
      );

      expect(
        failureOf(_restore([manu, lea, leaAgain])),
        NewSectorFailure.duplicateMember,
      );
    });

    test('should not let the member list be changed from outside', () {
      expect(() => team().members.add(julie), throwsUnsupportedError);
    });
  });

  group('queries', () {
    test('should list the pending requests apart when asked for them', () {
      expect(team().pendingMembers, [julie]);
    });

    test('should list the active members in order when asked for them', () {
      expect(team().activeMembers, [manu, lea]);
    });

    test('should find a member when given their id', () {
      expect(team().memberOf(leaId), lea);
    });

    test('should find nobody when the id is not in the secteur', () {
      expect(team().memberOf(paulId), isNull);
    });
  });

  group('accept', () {
    final at = DateTime.utc(2026, 11, 2, 8, 20);

    test('should make the request active, stamped, when an active member '
        'accepts it', () {
      final (sector, change) = valueOf(
        team().accept(julieId, by: leaActing, at: at),
      );

      final accepted = Member(
        id: julieId,
        name: nameOf('Julie'),
        requestedAt: julieAskedAt,
        acceptance: ChangeStamp(by: leaId, at: at),
      );
      expect(sector.members, [manu, lea, accepted]);
      expect(sector.pendingMembers, isEmpty);
      expect(change.sectorId, sectorId);
      expect(change.member, accepted);
    });

    test('should keep the rest of the secteur when a request is accepted', () {
      final (sector, _) = valueOf(
        team().accept(julieId, by: manuAsAdmin, at: at),
      );

      _expectSameIdentity(sector, team());
    });

    test('should stamp the admin who is not in the secteur when they '
        'accept a request', () {
      final (_, change) = valueOf(
        team().accept(julieId, by: samAsAdmin, at: at),
      );

      expect(change.member.acceptance, ChangeStamp(by: samId, at: at));
    });

    test('should refuse when the member is unknown', () {
      expect(
        failureOf(team().accept(paulId, by: manuAsAdmin, at: at)),
        SectorCommandFailure.unknownMember,
      );
    });

    test('should refuse when the member is already active', () {
      expect(
        failureOf(team().accept(leaId, by: manuAsAdmin, at: at)),
        SectorCommandFailure.alreadyActive,
      );
    });
  });

  group('refuse', () {
    test('should remove the request when an active member refuses it', () {
      final (sector, change) = valueOf(team().refuse(julieId, by: leaActing));

      expect(sector.members, [manu, lea]);
      expect(change.sectorId, sectorId);
      expect(change.member, julie);
      _expectSameIdentity(sector, team());
    });

    test('should refuse when the member is unknown', () {
      expect(
        failureOf(team().refuse(paulId, by: manuAsAdmin)),
        SectorCommandFailure.unknownMember,
      );
    });

    test('should refuse when the member is already active', () {
      expect(
        failureOf(team().refuse(leaId, by: manuAsAdmin)),
        SectorCommandFailure.alreadyActive,
      );
    });
  });

  group('remove', () {
    test('should cut the member out when an admin removes them', () {
      final (sector, change) = valueOf(team().remove(leaId, by: manuAsAdmin));

      expect(sector.members, [manu, julie]);
      expect(change.sectorId, sectorId);
      expect(change.member, lea);
      _expectSameIdentity(sector, team());
    });

    test('should refuse when the member is unknown', () {
      expect(
        failureOf(team().remove(paulId, by: manuAsAdmin)),
        SectorCommandFailure.unknownMember,
      );
    });

    test('should remove an admin, the creator too, when another admin '
        'removes them', () {
      final (sector, change) = valueOf(team().remove(manuId, by: samAsAdmin));

      expect(sector.members, [lea, julie]);
      expect(change.member, manu);
    });

    test('should refuse when the member is a pending request', () {
      expect(
        failureOf(team().remove(julieId, by: manuAsAdmin)),
        SectorCommandFailure.memberPending,
      );
    });
  });

  group('leave', () {
    test('should take an active member out when they leave', () {
      final (sector, change) = valueOf(team().leave(by: leaId));

      expect(sector.members, [manu, julie]);
      expect(change.sectorId, sectorId);
      expect(change.member, lea);
      _expectSameIdentity(sector, team());
    });

    test('should take a pending request out when its author cancels it', () {
      final (sector, change) = valueOf(team().leave(by: julieId));

      expect(sector.members, [manu, lea]);
      expect(change.member, julie);
    });

    test('should take the creator out when they leave', () {
      final (sector, change) = valueOf(team().leave(by: manuId));

      expect(sector.members, [lea, julie]);
      expect(sector.createdBy, manuId);
      expect(change.member, manu);
    });

    test('should leave nobody when the last member leaves', () {
      final (sector, _) = valueOf(team(members: [manu]).leave(by: manuId));

      expect(sector.members, isEmpty);
    });
  });

  group('rename', () {
    test('should give the member their new name when they rename '
        'themself', () {
      final (sector, change) = valueOf(
        team().rename(nameOf('Léa B.'), by: leaId),
      );

      final renamed = Member(
        id: leaId,
        name: nameOf('Léa B.'),
        requestedAt: leaAskedAt,
        acceptance: ChangeStamp(by: manuId, at: leaAcceptedAt),
      );
      expect(sector.members, [manu, renamed, julie]);
      expect(change.sectorId, sectorId);
      expect(change.member, renamed);
      _expectSameIdentity(sector, team());
    });

    test('should rename the creator too when they rename themself', () {
      final (sector, change) = valueOf(
        team().rename(nameOf('Emmanuel'), by: manuId),
      );

      expect(sector.memberOf(manuId)!.name, nameOf('Emmanuel'));
      expect(
        sector.memberOf(manuId)!.acceptance,
        ChangeStamp(by: manuId, at: createdAt),
      );
      expect(change.member.name, nameOf('Emmanuel'));
      expect(sector.members.skip(1), [lea, julie]);
    });

    test('should refuse a name another member holds, case and accents '
        'ignored', () {
      expect(
        failureOf(team().rename(nameOf('LEA'), by: manuId)),
        SectorCommandFailure.nameTaken,
      );
    });

    test('should refuse the name of a pending request too', () {
      expect(
        failureOf(team().rename(nameOf('julie'), by: leaId)),
        SectorCommandFailure.nameTaken,
      );
    });

    test('should let a member write their own name another way', () {
      final (sector, change) = valueOf(team().rename(nameOf('LÉA'), by: leaId));

      expect(sector.memberOf(leaId)!.name, nameOf('LÉA'));
      expect(change.member.name, nameOf('LÉA'));
    });

    test('should say first that the one renaming is not in the secteur', () {
      expect(
        failureOf(team().rename(nameOf('Léa'), by: paulId)),
        SectorCommandFailure.notAMember,
      );
    });
  });

  group('regenerateCode', () {
    test('should give a new code drawn from the source when an admin asks', () {
      // A, B, C, D, E, F: positions 0 to 5 of the alphabet.
      final random = ScriptedRandom([0, 1, 2, 3, 4, 5]);

      final (sector, change) = valueOf(
        team().regenerateCode(by: manuAsAdmin, random: random),
      );

      expect(sector.joinCode, codeOf('ABCDEF'));
      expect(change.sectorId, sectorId);
      expect(change.before, firstCode);
      expect(change.code, codeOf('ABCDEF'));
      expect(sector.members, team().members);
      expect(sector.id, sectorId);
      expect(sector.number, number49);
      expect(sector.centre, csVillefranche);
      expect(sector.createdBy, manuId);
      expect(sector.createdAt, createdAt);
      expect(sector.currentCampaign, campaign2026);
    });

    test('should draw again when the new code is the old one', () {
      // K7P2QX first (the current code), then AAAAAA.
      final random = ScriptedRandom([
        9, 28, 12, 23, 13, 20, //
        0, 0, 0, 0, 0, 0,
      ]);

      final (sector, change) = valueOf(
        team().regenerateCode(by: manuAsAdmin, random: random),
      );

      expect(sector.joinCode, codeOf('AAAAAA'));
      expect(change.code, codeOf('AAAAAA'));
    });
  });

  group('withJoinCode', () {
    test('should hold the code given and keep everything else', () {
      final sector = team(communes: [villefrancheCommune])
          .withJoinCode(codeOf('ABCDEF'));

      expect(sector.joinCode, codeOf('ABCDEF'));
      expect(sector.communes, [villefrancheCommune]);
      expect(sector.members, team().members);
      expect(sector.id, sectorId);
      expect(sector.number, number49);
      expect(sector.centre, csVillefranche);
      expect(sector.createdBy, manuId);
      expect(sector.createdAt, createdAt);
      expect(sector.currentCampaign, campaign2026);
    });
  });

  group('delete', () {
    test('should hand the whole secteur to storage when an admin deletes '
        'it', () {
      final sector = team();

      final deleted = valueOf(sector.delete(by: samAsAdmin));

      expect(deleted.sector, same(sector));
    });
  });

  group('joinAsAdmin', () {
    final at = DateTime.utc(2026, 11, 2, 10);

    test('should add the admin as an active member accepted by themself', () {
      final (sector, change) = valueOf(
        team().joinAsAdmin(by: samAsAdmin, name: nameOf('Sam'), at: at),
      );

      final sam = Member(
        id: samId,
        name: nameOf('Sam'),
        requestedAt: at,
        acceptance: ChangeStamp(by: samId, at: at),
      );
      expect(sector.members, [manu, lea, julie, sam]);
      expect(sector.activeMembers, [manu, lea, sam]);
      expect(change.sectorId, sectorId);
      expect(change.member, sam);
      _expectSameIdentity(sector, team());
    });

    test('should refuse a name a member holds, case and accents ignored', () {
      expect(
        failureOf(
          team().joinAsAdmin(by: samAsAdmin, name: nameOf('lea'), at: at),
        ),
        SectorCommandFailure.nameTaken,
      );
    });

    test('should say first that the admin is already in the secteur', () {
      expect(
        failureOf(
          team().joinAsAdmin(by: manuAsAdmin, name: nameOf('Manu'), at: at),
        ),
        SectorCommandFailure.alreadyMember,
      );
    });
  });

  group('addCommune', () {
    test('should add the commune after the others when a member adds it', () {
      final before = team(communes: [villefrancheCommune]);

      final (sector, change) = valueOf(
        before.addCommune(gleizeCommune, by: leaActing),
      );

      expect(sector.communes, [villefrancheCommune, gleizeCommune]);
      expect(change, CommuneAdded(sectorId: sectorId, commune: gleizeCommune));
      expect(sector.members, before.members);
      _expectSameIdentity(sector, before);
    });

    test('should give a secteur without commune its first one', () {
      final (sector, _) = valueOf(
        team().addCommune(villefrancheCommune, by: leaActing),
      );

      expect(sector.communes, [villefrancheCommune]);
    });

    test('should refuse a commune of a code the secteur already has', () {
      final otherCentre = SectorCommune(commune: villefrancheCommune.commune);
      final sector = team(communes: [villefrancheCommune]);

      expect(
        failureOf(sector.addCommune(otherCentre, by: leaActing)),
        SectorCommandFailure.communeAlreadyIn,
      );
    });

    test('should add the last commune allowed', () {
      final sector = team(communes: _communes(Sector.maxCommunes - 1));

      final (added, _) = valueOf(
        sector.addCommune(villefrancheCommune, by: leaActing),
      );

      expect(added.communes, hasLength(Sector.maxCommunes));
    });

    test('should refuse a commune beyond those allowed', () {
      final sector = team(communes: _communes(Sector.maxCommunes));

      expect(
        failureOf(sector.addCommune(villefrancheCommune, by: leaActing)),
        SectorCommandFailure.tooManyCommunes,
      );
    });
  });

  group('removeCommune', () {
    test('should take the commune out when a member removes it', () {
      final before = team(communes: [villefrancheCommune, gleizeCommune]);

      final (sector, change) = valueOf(
        before.removeCommune(insee('69264'), by: leaActing),
      );

      expect(sector.communes, [gleizeCommune]);
      expect(
        change,
        CommuneRemoved(sectorId: sectorId, commune: villefrancheCommune),
      );
      expect(sector.members, before.members);
      _expectSameIdentity(sector, before);
    });

    test('should refuse a commune the secteur does not have', () {
      final sector = team(communes: [villefrancheCommune, gleizeCommune]);

      expect(
        failureOf(sector.removeCommune(insee('69001'), by: leaActing)),
        SectorCommandFailure.unknownCommune,
      );
    });

    test('should refuse to remove the last commune', () {
      final sector = team(communes: [villefrancheCommune]);

      expect(
        failureOf(sector.removeCommune(insee('69264'), by: leaActing)),
        SectorCommandFailure.lastCommune,
      );
    });
  });

  test('should keep the communes when a member command changes the team', () {
    final (sector, _) = valueOf(
      team(communes: [villefrancheCommune])
          .accept(julieId, by: leaActing, at: DateTime.utc(2026, 11, 3)),
    );

    expect(sector.communes, [villefrancheCommune]);
  });

  test('should show its id, number, centre and campaign when printed', () {
    expect(team().toString(), 'Sector(t49, 49, CS Villefranche, 2026)');
  });

  group('permissions', () {
    // Who may run each command (PLAN §5.12, §6.1, §8.2): `null` means the
    // command is allowed, otherwise the failure it returns. Manu created
    // the secteur and is an admin, Léa is active, Julie is pending, Paul is
    // not in it; Sam is an admin who is not in it, and Julie is tried once
    // more as an admin whose own request still waits.
    final at = DateTime.utc(2026, 11, 2, 9);
    final commands = <String, Object? Function(Sector, Actor)>{
      'accept a request': (t, by) => t.accept(julieId, by: by, at: at),
      'refuse a request': (t, by) => t.refuse(julieId, by: by),
      'remove Léa': (t, by) => t.remove(leaId, by: by),
      'leave': (t, by) => t.leave(by: by.member),
      'regenerate the code': (t, by) =>
          t.regenerateCode(by: by, random: ScriptedRandom([0, 0, 0, 0, 0, 0])),
      'delete the secteur': (t, by) => t.delete(by: by),
      'rename themself': (t, by) => t.rename(nameOf('Zoé'), by: by.member),
      'join as an admin': (t, by) =>
          t.joinAsAdmin(by: by, name: nameOf('Zoé'), at: at),
      'add a commune': (t, by) => t.addCommune(gleizeCommune, by: by),
      'remove a commune': (t, by) =>
          team(communes: [villefrancheCommune, gleizeCommune])
              .removeCommune(insee('69092'), by: by),
    };
    const SectorCommandFailure? ok = null;
    const pending = SectorCommandFailure.requestPending;
    const outsider = SectorCommandFailure.notAMember;
    const notAdmin = SectorCommandFailure.notAdmin;
    const inIt = SectorCommandFailure.alreadyMember;
    const matrix = <String, List<SectorCommandFailure?>>{
      //                 Manu, Léa, Julie, Paul, Sam, Julie (admin)
      'accept a request': [ok, ok, pending, outsider, ok, ok],
      'refuse a request': [ok, ok, pending, outsider, ok, ok],
      'remove Léa': [ok, notAdmin, pending, outsider, ok, ok],
      'leave': [ok, ok, ok, outsider, outsider, ok],
      'regenerate the code': [ok, notAdmin, pending, outsider, ok, ok],
      'delete the secteur': [ok, notAdmin, pending, outsider, ok, ok],
      'rename themself': [ok, ok, pending, outsider, outsider, pending],
      'join as an admin': [inIt, notAdmin, notAdmin, notAdmin, ok, inIt],
      'add a commune': [ok, ok, pending, outsider, ok, ok],
      'remove a commune': [ok, ok, pending, outsider, ok, ok],
    };
    final actors = {
      'Manu (active admin)': manuAsAdmin,
      'Léa (active)': leaActing,
      'Julie (pending)': julieActing,
      'Paul (outsider)': paulActing,
      'Sam (admin, outsider)': samAsAdmin,
      'Julie (pending admin)': Actor(member: julieId, isAdmin: true),
    };

    for (final MapEntry(key: command, value: run) in commands.entries) {
      final expected = matrix[command]!;
      var column = 0;
      for (final MapEntry(key: actor, value: by) in actors.entries) {
        final failure = expected[column++];
        final verdict = failure == null ? 'allow' : 'refuse with $failure';
        test('should $verdict when $actor tries to $command', () {
          final result = run(team(), by);

          if (failure == null) {
            expect(result, isA<Ok<Object?, SectorCommandFailure>>());
          } else {
            expect(
              result,
              isA<Err<Object?, SectorCommandFailure>>().having(
                (err) => err.failure,
                'failure',
                failure,
              ),
            );
          }
        });
      }
    }
  });
}

Result<Sector, NewSectorFailure> _restore(
  List<Member> members, {
  List<SectorCommune> communes = const [],
}) => Sector.create(
  id: sectorId,
  number: number49,
  centre: csVillefranche,
  joinCode: firstCode,
  createdBy: manuId,
  createdAt: createdAt,
  currentCampaign: campaign2026,
  members: members,
  communes: communes,
);

/// [count] different communes of the Rhône (69001, 69002…), without
/// centre: only their number matters.
List<SectorCommune> _communes(int count) => [
  for (var i = 1; i <= count; i++)
    SectorCommune(
      commune: valueOf(
        Commune.create(
          inseeCode: '69${'$i'.padLeft(3, '0')}',
          name: 'Commune $i',
        ),
      ),
    ),
];

/// Checks that a command on members left the rest of the secteur as it was.
void _expectSameIdentity(Sector actual, Sector expected) {
  expect(actual.id, expected.id);
  expect(actual.number, expected.number);
  expect(actual.centre, expected.centre);
  expect(actual.joinCode, expected.joinCode);
  expect(actual.createdBy, expected.createdBy);
  expect(actual.createdAt, expected.createdAt);
  expect(actual.currentCampaign, expected.currentCampaign);
}
