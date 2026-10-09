// The documents of a tournée in Firestore (PLAN §6.2): the tournée and its
// members, the join code's preview, the number + centre reservation and
// the shared list of centres de secours.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/tournee_document_mapper.dart';

import '../../../domain/tournee/tournee_fixtures.dart';
import '../../../support/results.dart';

Timestamp at(DateTime time) => Timestamp.fromDate(time);

/// [team]'s documents as Firestore gives them back.
Map<String, dynamic> tourneeData() => <String, dynamic>{
  ...tourneeToDocument(team()),
};

Map<String, Map<String, dynamic>> memberData() => {
  for (final member in team().members)
    member.id.value: <String, dynamic>{...memberToDocument(member)},
};

Tournee read({
  void Function(Map<String, dynamic> tournee)? tournee,
  void Function(Map<String, Map<String, dynamic>> members)? members,
}) {
  final data = tourneeData();
  final memberDocs = memberData();
  tournee?.call(data);
  members?.call(memberDocs);
  return tourneeFromDocuments(tourneeId.value, data, memberDocs);
}

final preview = JoinPreview(
  code: firstCode,
  tourneeId: tourneeId,
  number: number49,
  centre: csVillefranche,
  campaign: campaign2026,
);

void main() {
  group('tournée', () {
    test('should write the tournée fields under their stored names', () {
      expect(tourneeToDocument(team()), {
        'number': 49,
        'centreKey': 'villefranche',
        'centreName': 'CS Villefranche',
        'joinCode': 'K7P2QX',
        'createdBy': 'uid-manu',
        'createdAt': at(createdAt),
        'currentCampaign': 2026,
      });
    });

    test('should give back the same tournée when read again', () {
      final back = read();
      final original = team();

      expect(back.id, original.id);
      expect(back.number, original.number);
      expect(back.centre, original.centre);
      expect(back.joinCode, original.joinCode);
      expect(back.createdBy, original.createdBy);
      expect(back.createdAt, original.createdAt);
      expect(back.createdAt.isUtc, isTrue);
      expect(back.currentCampaign, original.currentCampaign);
      expect(back.members, original.members);
    });

    test('should refuse a tournée without its number', () {
      expect(
        () => read(tournee: (data) => data.remove('number')),
        throwsFormatException,
      );
    });

    test('should refuse a number the domain refuses', () {
      expect(
        () => read(tournee: (data) => data['number'] = 0),
        throwsFormatException,
      );
    });

    test('should refuse a centre name the domain refuses', () {
      expect(
        () => read(tournee: (data) => data['centreName'] = 'CS'),
        throwsFormatException,
      );
    });

    test('should refuse a join code the domain refuses', () {
      expect(
        () => read(tournee: (data) => data['joinCode'] = 'K7P2Q0'),
        throwsFormatException,
      );
    });

    test('should refuse a campaign the domain refuses', () {
      expect(
        () => read(tournee: (data) => data['currentCampaign'] = 1999),
        throwsFormatException,
      );
    });

    test('should refuse a blank creator', () {
      expect(
        () => read(tournee: (data) => data['createdBy'] = ' '),
        throwsFormatException,
      );
    });

    test('should refuse a tournée whose creator is not a member', () {
      expect(
        () => read(members: (members) => members.remove('uid-manu')),
        throwsFormatException,
      );
    });
  });

  group('member', () {
    test('should write an active member with who accepted them and when', () {
      expect(memberToDocument(lea), {
        'displayName': 'Léa',
        'status': 'active',
        'requestedAt': at(leaAskedAt),
        'acceptedBy': 'uid-manu',
        'acceptedAt': at(leaAcceptedAt),
      });
    });

    test('should write a pending member without acceptance', () {
      expect(memberToDocument(julie), {
        'displayName': 'Julie',
        'status': 'pending',
        'requestedAt': at(julieAskedAt),
        'acceptedBy': null,
        'acceptedAt': null,
      });
    });

    test('should write a request with the code it was made with', () {
      expect(joinRequestDocument(julie, firstCode), {
        ...memberToDocument(julie),
        'joinCode': 'K7P2QX',
      });
    });

    test('should write only the acceptance of an accepted member', () {
      expect(acceptanceFields(lea), {
        'status': 'active',
        'acceptedBy': 'uid-manu',
        'acceptedAt': at(leaAcceptedAt),
      });
    });

    test('should read a member back with the id of its document', () {
      final back = memberFromDocument('uid-lea', {...memberToDocument(lea)});

      expect(back, lea);
      expect(back.status, MemberStatus.active);
    });

    test('should read a pending member back', () {
      final back = memberFromDocument('uid-julie', {
        ...joinRequestDocument(julie, firstCode),
      });

      expect(back, julie);
      expect(back.status, MemberStatus.pending);
    });

    test('should refuse an active member without acceptance', () {
      expect(
        () => memberFromDocument('uid-julie', {
          ...memberToDocument(julie),
          'status': 'active',
        }),
        throwsFormatException,
      );
    });

    test('should refuse a pending member with an acceptance', () {
      expect(
        () => memberFromDocument('uid-lea', {
          ...memberToDocument(lea),
          'status': 'pending',
        }),
        throwsFormatException,
      );
    });

    test('should refuse a status it does not know', () {
      expect(
        () => memberFromDocument('uid-lea', {
          ...memberToDocument(lea),
          'status': 'ACTIVE',
        }),
        throwsFormatException,
      );
    });

    test('should refuse a name the domain refuses', () {
      expect(
        () => memberFromDocument('uid-lea', {
          ...memberToDocument(lea),
          'displayName': '  ',
        }),
        throwsFormatException,
      );
    });

    test('should refuse a member without its request time', () {
      expect(
        () => memberFromDocument(
          'uid-lea',
          {...memberToDocument(lea)}..remove('requestedAt'),
        ),
        throwsFormatException,
      );
    });

    test('should refuse a blank member id', () {
      expect(
        () => memberFromDocument(' ', {...memberToDocument(lea)}),
        throwsFormatException,
      );
    });
  });

  group('join code', () {
    test('should write only what the join preview shows', () {
      expect(joinCodeDocument(team()), {
        'tourneeId': 't49',
        'number': 49,
        'centreName': 'CS Villefranche',
        'campaign': 2026,
      });
    });

    test('should read the preview of a code back', () {
      expect(
        joinPreviewFromDocument(firstCode, {...joinCodeDocument(team())}),
        preview,
      );
    });

    test('should refuse a preview without its tournée', () {
      expect(
        () => joinPreviewFromDocument(
          firstCode,
          {...joinCodeDocument(team())}..remove('tourneeId'),
        ),
        throwsFormatException,
      );
    });

    test('should refuse a preview whose year the domain refuses', () {
      expect(
        () => joinPreviewFromDocument(firstCode, {
          ...joinCodeDocument(team()),
          'campaign': 2100,
        }),
        throwsFormatException,
      );
    });
  });

  group('reservation and centres', () {
    test('should key the reservation by centre and number', () {
      final centre = valueOf(RescueCentre.create('CIS Villefranche-sur-Saône'));
      final number = valueOf(TourneeNumber.create(7));

      expect(tourneeKeyId(centre, number), 'villefranche-sur-saone_7');
    });

    test('should write which tournée holds the reservation', () {
      expect(tourneeKeyDocument(team()), {'tourneeId': 't49'});
    });

    test('should read the tournée of a reservation', () {
      expect(tourneeIdFromKeyDocument({'tourneeId': 't49'}), TourneeId('t49'));
    });

    test('should refuse a reservation without its tournée', () {
      expect(
        () => tourneeIdFromKeyDocument({'tourneeId': null}),
        throwsFormatException,
      );
    });

    test('should start the first campaign when the tournée is created', () {
      expect(firstCampaignDocument(team()), {
        'startedAt': at(createdAt),
        'previousYear': null,
      });
    });

    test('should write the name of a centre as typed', () {
      final centre = valueOf(RescueCentre.create('CIS  Villefranche'));

      expect(rescueCentreDocument(centre), {'name': 'CIS Villefranche'});
    });

    test('should read a centre back from its name', () {
      expect(
        rescueCentreFromDocument({'name': 'CS Villefranche'}),
        csVillefranche,
      );
    });

    test('should refuse a centre name the domain refuses', () {
      expect(
        () => rescueCentreFromDocument({'name': '!?'}),
        throwsFormatException,
      );
    });

    test('should refuse a centre without its name', () {
      expect(() => rescueCentreFromDocument({}), throwsFormatException);
    });
  });
}
