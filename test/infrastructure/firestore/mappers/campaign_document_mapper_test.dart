import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/campaign_document_mapper.dart';

import '../../../domain/sector/my_sectors_fixtures.dart';
import '../../../domain/sector/sector_fixtures.dart' show campaign2026;

void main() {
  group('nextCampaignDocument', () {
    test('should name the year it is copied from, started at the server\'s '
        'time', () {
      final doc = nextCampaignDocument(from: campaign2026);

      expect(doc.keys, unorderedEquals(['startedAt', 'previousYear']));
      expect(doc['previousYear'], 2026);
      expect(doc['startedAt'], FieldValue.serverTimestamp());
    });
  });

  group('campaignYearOf', () {
    test('should read the year a campaign document is named after', () {
      expect(campaignYearOf('2027'), campaign2027);
    });

    test('should read nothing of an id that is not a year in range', () {
      expect(campaignYearOf('next'), isNull);
      expect(campaignYearOf('1999'), isNull);
      expect(campaignYearOf(''), isNull);
    });
  });

  group('currentCampaignOf', () {
    test('should read the year a secteur works on', () {
      expect(
        currentCampaignOf({'number': 49, 'currentCampaign': 2027}),
        campaign2027,
      );
    });

    test('should read nothing of a missing secteur, or a year that is not '
        'one', () {
      expect(currentCampaignOf(null), isNull);
      expect(currentCampaignOf({'number': 49}), isNull);
      expect(currentCampaignOf({'currentCampaign': '2027'}), isNull);
      expect(currentCampaignOf({'currentCampaign': 2100}), isNull);
    });
  });

  test('should move the secteur and its join preview to the year', () {
    expect(campaignSwitchFields(campaign2027), {'currentCampaign': 2027});
    expect(previewCampaignFields(campaign2027), {'campaign': 2027});
  });
}
