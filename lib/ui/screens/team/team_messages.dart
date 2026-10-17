import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/presentation/team/team_state.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

/// Why a command of Équipe (or of the admin banner) was not done, in
/// French. A `switch` without `default`: a new failure breaks the build
/// here until it is phrased.
String teamActionMessage(AppLocalizations l10n, TeamActionFailure failure) =>
    switch (failure) {
      TeamActionFailure.teamChanged => l10n.teamChanged,
      TeamActionFailure.offline => l10n.teamOffline,
      // Only « Rejoindre » of the banner asks for a name, which it gets
      // first: said here should it ever happen.
      TeamActionFailure.noName => l10n.nameBlank,
      TeamActionFailure.notAdmin => l10n.notAdminAnyMore,
      TeamActionFailure.communeAlreadyIn => l10n.teamCommuneAlreadyIn,
      TeamActionFailure.tooManyCommunes => l10n.teamTooManyCommunes(
        Tournee.maxCommunes,
      ),
    };
