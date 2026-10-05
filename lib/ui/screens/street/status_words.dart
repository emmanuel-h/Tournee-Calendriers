import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

// The look and the French words of a status, shared by the street screen
// and the building grid.

/// The look of a tile (or door) that shows [mark].
TileStatus tileStatusOf(TileMark mark) => switch (mark) {
  ToDoMark() => const ToDoTile(),
  DoneMark() => const DoneTile(),
  NobodyHomeMark() => const NobodyHomeTile(),
  ComeBackMark() => const ComeBackTile(),
  PartialBuildingMark(:final done, :final total) => BuildingPartialTile(
    done: done,
    total: total,
  ),
};

/// The spoken status of a door tile (« à faire, repasser »).
String spokenMark(AppLocalizations l10n, TileMark mark) => switch (mark) {
  ToDoMark() => l10n.tileStatusToDo,
  DoneMark() => l10n.tileStatusDone,
  NobodyHomeMark() => l10n.tileStatusNobodyHome,
  ComeBackMark() => l10n.tileStatusComeBack,
  // A door is never a building: its look is one of the four above.
  PartialBuildingMark() => l10n.tileStatusToDo,
};

/// The spoken name of [status] (« fait »), after a tap.
String spokenStatus(AppLocalizations l10n, VisitStatus status) =>
    switch (status) {
      VisitStatus.toDo => l10n.tileStatusToDo,
      VisitStatus.done => l10n.tileStatusDone,
      VisitStatus.nobodyHome => l10n.tileStatusNobodyHome,
    };

/// The written name of [status] (« Fait »), in the snackbar.
String statusName(AppLocalizations l10n, VisitStatus status) =>
    switch (status) {
      VisitStatus.toDo => l10n.statusToDo,
      VisitStatus.done => l10n.statusDone,
      VisitStatus.nobodyHome => l10n.statusNobodyHome,
    };
