import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/donations_taken_out.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/components/tries_words.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

// The look and the French words of a status, shared by the street screen
// and the building grid.

/// The look of a tile (or door) that shows [mark].
TileStatus tileStatusOf(TileMark mark) => switch (mark) {
  ToDoMark() => const ToDoTile(),
  DoneMark() => const DoneTile(),
  RefusedMark() => const RefusedTile(),
  NobodyHomeMark() => const NobodyHomeTile(),
  ComeBackMark() => const ComeBackTile(),
  PartialBuildingMark(:final done, :final total) => BuildingPartialTile(
    done: done,
    total: total,
  ),
};

/// The look of [status] on a status button of the picker, as on a tile.
TileStatus tileStatusFor(VisitStatus status) => switch (status) {
  VisitStatus.toDo => const ToDoTile(),
  VisitStatus.done => const DoneTile(),
  VisitStatus.refused => const RefusedTile(),
  VisitStatus.nobodyHome => const NobodyHomeTile(),
  VisitStatus.comeBack => const ComeBackTile(),
};

/// The spoken status of a door tile (« repasser »).
String spokenMark(AppLocalizations l10n, TileMark mark) => switch (mark) {
  ToDoMark() => l10n.tileStatusToDo,
  DoneMark() => l10n.tileStatusDone,
  RefusedMark() => l10n.tileStatusRefused,
  NobodyHomeMark() => l10n.tileStatusNobodyHome,
  ComeBackMark() => l10n.tileStatusComeBack,
  // A door is never a building: its look is one of the five above.
  PartialBuildingMark() => l10n.tileStatusToDo,
};

/// The spoken name of [status] (« fait »), once it is chosen.
String spokenStatus(AppLocalizations l10n, VisitStatus status) =>
    switch (status) {
      VisitStatus.toDo => l10n.tileStatusToDo,
      VisitStatus.done => l10n.tileStatusDone,
      VisitStatus.refused => l10n.tileStatusRefused,
      VisitStatus.nobodyHome => l10n.tileStatusNobodyHome,
      VisitStatus.comeBack => l10n.tileStatusComeBack,
    };

/// The written name of [status] (« Fait »), on the buttons and in the
/// title of the status picker.
String statusName(AppLocalizations l10n, VisitStatus status) =>
    switch (status) {
      VisitStatus.toDo => l10n.statusToDo,
      VisitStatus.done => l10n.statusDone,
      VisitStatus.refused => l10n.statusRefused,
      VisitStatus.nobodyHome => l10n.statusNobodyHome,
      VisitStatus.comeBack => l10n.statusComeBack,
    };

/// What the snackbar says once the picker of the house [label] stored
/// [status]: « N° 7 : fait », or « N° 3bis : personne (3e passage) » once
/// nobody was home two times or more ([tries], the count the tile shows);
/// « N° 7 fait · 10 € en espèces » when a [donation] came with it, during
/// a tournée; « N° 3 : personne · son don de 20 € en espèces est retiré de
/// la tournée » when a ✓ taken back took its dons out ([takenOut]).
String houseStoredMessage(
  AppLocalizations l10n,
  String label,
  VisitStatus status,
  int? tries, {
  Donation? donation,
  DonationsTakenOut? takenOut,
}) => _withTakenOut(l10n, takenOut, switch ((status, tries, donation)) {
  (_, _, final donation?) => l10n.houseDoneWithDonation(
    label,
    donationWords(l10n, donation),
  ),
  (VisitStatus.nobodyHome, final int count, _) => l10n.houseStatusStoredTries(
    label,
    spokenStatus(l10n, status),
    count,
  ),
  _ => l10n.houseStatusStored(label, spokenStatus(l10n, status)),
});

/// The same for the door [label] of a building: « Porte 51 : fait »,
/// « Porte 51 : personne (3e passage) », « Porte 51 : fait · 10 € en
/// espèces », « Porte 51 : personne · son don de 20 € en espèces est retiré
/// de la tournée ».
String doorStoredMessage(
  AppLocalizations l10n,
  String label,
  VisitStatus status,
  int? tries, {
  Donation? donation,
  DonationsTakenOut? takenOut,
}) => _withTakenOut(l10n, takenOut, switch ((status, tries, donation)) {
  (_, _, final donation?) => l10n.doorDoneWithDonation(
    label,
    donationWords(l10n, donation),
  ),
  (VisitStatus.nobodyHome, final int count, _) => l10n.doorStatusStoredTries(
    label,
    spokenStatus(l10n, status),
    count,
  ),
  _ => l10n.doorStatusStored(label, spokenStatus(l10n, status)),
});

/// [marked], then what left the tournée with it, if anything did.
String _withTakenOut(
  AppLocalizations l10n,
  DonationsTakenOut? takenOut,
  String marked,
) => switch (takenOut) {
  null => marked,
  final taken => l10n.markedWithDonationsTakenOut(
    marked,
    takenOutWords(l10n, taken.donations),
  ),
};

/// The dons a ✓ taken back took out of the tournée (PLAN §5.21): « son don
/// de 20 € en espèces est retiré de la tournée », « son calendrier offert
/// est retiré de la tournée », or « ses 2 dons (15 €) sont retirés de la
/// tournée » with the money of the paid ones.
String takenOutWords(AppLocalizations l10n, List<Donation> donations) =>
    switch (donations) {
      [final PaidDonation paid] => l10n.donationTakenOutPaid(
        donationWords(l10n, paid),
      ),
      [FreeCalendar()] => l10n.donationTakenOutFree,
      _ => l10n.donationsTakenOut(
        donations.length,
        eurosText(l10n, DonationTotals.of(donations).cents),
      ),
    };

/// The spoken name of [status] after a mark, with the [tries] the tile
/// now shows: « personne, 3e passage », « fait, 2 passages sans
/// personne ».
String spokenMarked(AppLocalizations l10n, VisitStatus status, int? tries) =>
    spokenWithTries(
      l10n,
      spokenStatus(l10n, status),
      nobodyHome: status == VisitStatus.nobodyHome,
      tries: tries,
    );
