// The documents a new campaign writes (#39, PLAN §5.10, §6.2). Pure
// functions, tested alone.
//
//   sectors/{id}                    { …, currentCampaign: 2027 }   ← switched
//     campaigns/{year}              { startedAt: time, previousYear: 2026 }
//       streets/{streetId}          ← each street's copy (street_document_mapper)
//   joinCodes/{code}                { …, campaign: 2027 }          ← switched too
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// The document `campaigns/{year}` of a campaign copied from [from].
///
/// Started at the server's time (`serverTimestamp`): it is only told, and
/// the domain has no clock to give (the use case runs on the admin's
/// phone, online by then).
Map<String, Object?> nextCampaignDocument({required CampaignYear from}) => {
  'startedAt': FieldValue.serverTimestamp(),
  'previousYear': from.value,
};

/// The year of the campaign document [id] (`2027`); null when it is not a
/// year the domain takes.
CampaignYear? campaignYearOf(String id) => switch (CampaignYear.parse(id)) {
  Ok(:final value) => value,
  Err() => null,
};

/// The year the secteur stored as [data] works on; null when there is no
/// secteur or no readable year.
CampaignYear? currentCampaignOf(Map<String, Object?>? data) =>
    switch (data?['currentCampaign']) {
      final int year => switch (CampaignYear.create(year)) {
        Ok(:final value) => value,
        Err() => null,
      },
      _ => null,
    };

/// The update of `sectors/{id}` that moves it to [year].
Map<String, Object?> campaignSwitchFields(CampaignYear year) => {
  'currentCampaign': year.value,
};

/// The update of `joinCodes/{code}` that shows [year] to newcomers, in the
/// same write as [campaignSwitchFields] (the security rules require both).
Map<String, Object?> previewCampaignFields(CampaignYear year) => {
  'campaign': year.value,
};
