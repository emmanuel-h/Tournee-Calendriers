import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/id_generator.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// What became of one street of the import, for the import screen's
/// summary. `sealed`: the screen's `switch` handles each case.
sealed class StreetImport {
  const StreetImport(this.banId);

  /// Which BAN street this outcome is about.
  final BanStreetId banId;
}

/// The street is now on the phone, with [numberCount] houses to do.
final class StreetImported extends StreetImport {
  const StreetImported(
    super.banId, {
    required this.streetId,
    required this.numberCount,
    required this.skippedNumbers,
  });

  /// The id of the new street, to open it.
  final StreetId streetId;

  /// How many houses the street has.
  final int numberCount;

  /// How many BAN entries were left out: unreadable, or a number listed
  /// twice (see `StreetNumbers`).
  final int skippedNumbers;
}

/// The street was in the Corbeille: it is back in « Mes rues » exactly as it
/// was deleted, its marks included, without asking the BAN.
final class StreetRestoredFromCorbeille extends StreetImport {
  const StreetRestoredFromCorbeille(super.banId, {required this.streetId});

  /// The id of the street on the phone.
  final StreetId streetId;
}

/// The street was imported before and is not in the Corbeille. It is left
/// exactly as it is: importing again must never wipe the marks made since.
final class StreetAlreadyImported extends StreetImport {
  const StreetAlreadyImported(super.banId, {required this.streetId});

  /// The id of the street on the phone.
  final StreetId streetId;
}

/// The street could not be imported, for [failure]. Importing again later
/// tries it again (and skips the streets imported meanwhile).
final class StreetImportFailed extends StreetImport {
  const StreetImportFailed(super.banId, this.failure);

  final AddressDirectoryFailure failure;
}

/// The summary of an import, what the import screen shows at the end.
final class ImportReport {
  /// The lists are copied, so changing them afterwards does not change the
  /// report.
  ImportReport({
    required this.commune,
    required List<StreetImport> streets,
    required List<BanStreetId> unknownStreets,
    required this.emptyStreets,
  }) : streets = List.unmodifiable(streets),
       unknownStreets = List.unmodifiable(unknownStreets);

  final Commune commune;

  /// One outcome per street tried: the chosen streets already on the phone
  /// first, then the others in the BAN's order. Read-only.
  final List<StreetImport> streets;

  /// The chosen streets the commune does not list (a stale choice), which
  /// were not tried. Read-only.
  final List<BanStreetId> unknownStreets;

  /// When the whole commune was imported, how many of its streets were left
  /// out because the BAN has no number for them (most lieux-dits).
  final int emptyStreets;
}

/// Brings the reference area onto the phone (PLAN §12, M1): the streets of
/// a commune typed in by the user, all of them or a chosen few, with their
/// numbers and positions from the BAN. Nothing is hard-coded. Needs the
/// network, once; afterwards everything works offline.
///
/// - **Never wipes marks.** A street whose BAN id is already on the phone is
///   left as it is and reported; if it is in the Corbeille it comes back
///   from it, marks included (PLAN §6.1).
/// - **The streets already on the phone need no network.** The chosen ones
///   are handled before the BAN is asked anything, so bringing a street back
///   from the Corbeille works in airplane mode, and when only such streets
///   are chosen the BAN is not asked at all.
/// - **One street failing does not stop the others**: the BAN refusing a
///   street, or answering nonsense, is reported for that street and the
///   import goes on. Once the network is gone, though, the remaining
///   streets are reported as failed without being asked: each would wait
///   for its own timeout. The streets imported so far stay, so importing
///   again when the network is back finishes the job.
final class ImportReferenceArea {
  const ImportReferenceArea(this._directory, this._streets, this._ids);

  final AddressDirectory _directory;
  final StreetRepository _streets;
  final IdGenerator _ids;

  /// Imports the streets of the commune [inseeCode]: those listed in
  /// [only], or when it is null every street the BAN has numbers for.
  /// [onProgress] is told after each street asked of the BAN how many are
  /// done out of how many (the streets already on the phone count as done),
  /// for a progress bar.
  ///
  /// Fails as a whole only when the commune itself cannot be listed and
  /// none of the chosen streets is on the phone.
  Future<Result<ImportReport, AddressDirectoryFailure>> call(
    InseeCode inseeCode, {
    Iterable<BanStreetId>? only,
    void Function(int done, int total)? onProgress,
  }) async {
    final chosen = only?.toSet();

    // The chosen streets already on the phone first: they need no BAN.
    final outcomes = <StreetImport>[];
    final toAsk = <BanStreetId>{};
    Commune? storedCommune;
    for (final id in chosen ?? const <BanStreetId>{}) {
      final stored = await _streets.findByBanId(id);
      if (stored == null) {
        toAsk.add(id);
      } else {
        outcomes.add(await _keep(id, stored));
        storedCommune ??= stored.commune;
      }
    }
    if (storedCommune != null && toAsk.isEmpty) {
      return Ok(_report(storedCommune, outcomes));
    }

    final CommuneStreets listed;
    switch (await _directory.streetsOf(inseeCode)) {
      case Err(:final failure):
        if (storedCommune == null) return Err(failure);
        // Some streets came back from the phone: they are told, and the
        // ones the BAN was needed for failed.
        return Ok(
          _report(storedCommune, [
            ...outcomes,
            for (final id in toAsk) StreetImportFailed(id, failure),
          ]),
        );
      case Ok(:final value):
        listed = value;
    }

    final listedIds = {for (final street in listed.streets) street.id};
    final toImport = [
      for (final street in listed.streets)
        if (chosen == null ? street.numberCount > 0 : toAsk.contains(street.id))
          street,
    ];

    final total = outcomes.length + toImport.length;
    var offline = false;
    for (final street in toImport) {
      final outcome = await _importOne(street, offline: offline);
      if (outcome case StreetImportFailed(
        failure: AddressDirectoryFailure.noNetwork,
      )) {
        offline = true;
      }
      outcomes.add(outcome);
      onProgress?.call(outcomes.length, total);
    }

    return Ok(
      _report(
        listed.commune,
        outcomes,
        unknownStreets: [
          for (final id in toAsk)
            if (!listedIds.contains(id)) id,
        ],
        emptyStreets: chosen != null
            ? 0
            : listed.streets.where((street) => street.numberCount == 0).length,
      ),
    );
  }

  static ImportReport _report(
    Commune commune,
    List<StreetImport> streets, {
    List<BanStreetId> unknownStreets = const [],
    int emptyStreets = 0,
  }) => ImportReport(
    commune: commune,
    streets: streets,
    unknownStreets: unknownStreets,
    emptyStreets: emptyStreets,
  );

  /// The street [stored], imported before from [banId]: brought back from
  /// the Corbeille if it is there, otherwise left as it is.
  Future<StreetImport> _keep(BanStreetId banId, Street stored) async {
    if (!stored.isDeleted) {
      return StreetAlreadyImported(banId, streetId: stored.id);
    }
    final (restored, change) = stored.restore();
    await _streets.save(restored, change);
    return StreetRestoredFromCorbeille(banId, streetId: stored.id);
  }

  /// Imports [street] unless it is on the phone already; when [offline],
  /// does not ask the BAN.
  Future<StreetImport> _importOne(
    DirectoryStreet street, {
    required bool offline,
  }) async {
    final existing = await _streets.findByBanId(street.id);
    if (existing != null) return _keep(street.id, existing);
    if (offline) {
      return StreetImportFailed(street.id, AddressDirectoryFailure.noNetwork);
    }
    final StreetNumbers numbers;
    switch (await _directory.numbersOf(street.id)) {
      case Err(:final failure):
        return StreetImportFailed(street.id, failure);
      case Ok(:final value):
        numbers = value;
    }
    switch (Street.create(
      id: StreetId(_ids.newId()),
      name: numbers.name.text,
      commune: numbers.commune,
      banId: numbers.id,
      houses: [
        for (final number in numbers.numbers)
          House(number: number.number, position: number.position),
      ],
    )) {
      case Err():
        // The directory promises each number once; a street breaking that
        // is a service answering nonsense.
        return StreetImportFailed(
          street.id,
          AddressDirectoryFailure.serviceError,
        );
      case Ok(value: final created):
        await _streets.add(created);
        return StreetImported(
          street.id,
          streetId: created.id,
          numberCount: created.houses.length,
          skippedNumbers: numbers.invalidNumbers + numbers.duplicateNumbers,
        );
    }
  }
}
