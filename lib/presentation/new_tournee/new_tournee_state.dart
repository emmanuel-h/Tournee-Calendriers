import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';

/// The centres de secours the app knows, as far as the screen got them.
/// `sealed`: the picker handles each case.
sealed class KnownCentres {
  const KnownCentres();
}

/// Not asked yet (the phone signs in first), or on their way.
final class CentresLoading extends KnownCentres {
  const CentresLoading();
}

/// The [centres] the app knows, by name.
final class CentresLoaded extends KnownCentres {
  CentresLoaded(List<RescueCentre> centres)
    : centres = List.unmodifiable(centres);

  final List<RescueCentre> centres;

  @override
  bool operator ==(Object other) =>
      other is CentresLoaded && sameItems(other.centres, centres);

  @override
  int get hashCode => Object.hashAll(centres);
}

/// The server could not be reached: only a new centre can be added.
final class CentresUnavailable extends KnownCentres {
  const CentresUnavailable();
}

/// What the server said of the number in the chosen centre (« La tournée
/// 49 du CS Villefranche existe déjà »).
enum DuplicateCheck {
  /// Not asked yet, on its way, or the server could not be reached.
  unknown,

  /// No tournée has this number in this centre.
  free,

  /// The tournée exists: ask its creator for the code.
  taken,
}

/// Where « Créer » stands. `sealed`: the screen handles each case.
sealed class CreateRun {
  const CreateRun();
}

/// Nothing asked yet, or asked again after a refusal.
final class CreateIdle extends CreateRun {
  const CreateIdle();
}

/// The tournée is being created on the server.
final class CreateInProgress extends CreateRun {
  const CreateInProgress();
}

/// The server could not be reached (« Pas de réseau »): « Créer » again.
final class CreateOffline extends CreateRun {
  const CreateOffline();
}

/// The server refused: the member is no longer an admin (« Vous n'êtes
/// plus administrateur. »). « Créer » stays off: asking again would be
/// refused again.
final class CreateNotAdmin extends CreateRun {
  const CreateNotAdmin();
}

/// The tournée exists and is open on the phone: its code and QR code to
/// show the team (Create mockup).
final class TourneeCreated extends CreateRun {
  const TourneeCreated({
    required this.number,
    required this.centre,
    required this.code,
    required this.qrData,
  });

  /// [tournee] as stored.
  factory TourneeCreated.of(Tournee tournee) => TourneeCreated(
    number: tournee.number.value,
    centre: tournee.centre.name,
    code: tournee.joinCode.display,
    qrData: tournee.joinCode.value,
  );

  final int number;
  final String centre;

  /// The code as shown, `K7P-2QX`.
  final String code;

  /// What the QR code holds: the code alone, `K7P2QX` (PLAN §5.2).
  final String qrData;

  @override
  bool operator ==(Object other) =>
      other is TourneeCreated &&
      other.number == number &&
      other.centre == centre &&
      other.code == code &&
      other.qrData == qrData;

  @override
  int get hashCode => Object.hash(number, centre, code, qrData);

  @override
  String toString() => 'TourneeCreated($number, $centre, $code)';
}

/// What « Nouvelle tournée » shows (PLAN §5.2, Create and CreateTaken
/// mockups). Immutable: the notifier replaces it with [copyWith].
final class NewTourneeState {
  NewTourneeState({
    required this.signedIn,
    required this.hasName,
    required this.centreQuery,
    required this.centre,
    required this.known,
    required this.number,
    required this.numberInvalid,
    required this.initialYear,
    required this.year,
    required this.yearInvalid,
    required this.duplicate,
    required this.run,
    List<CommuneOption> communes = const [],
  }) : communes = List.unmodifiable(communes);

  /// The form as it opens: the year pre-filled with [initialYear].
  factory NewTourneeState.start({
    required String initialYear,
    required bool signedIn,
    required bool hasName,
  }) {
    final year = switch (CampaignYear.parse(initialYear)) {
      Ok(:final value) => value,
      Err() => null,
    };
    return NewTourneeState(
      signedIn: signedIn,
      hasName: hasName,
      centreQuery: '',
      centre: null,
      known: const CentresLoading(),
      number: null,
      numberInvalid: false,
      initialYear: initialYear,
      year: year,
      yearInvalid: year == null,
      duplicate: DuplicateCheck.unknown,
      run: const CreateIdle(),
    );
  }

  /// The phone has its account: the server can be asked.
  final bool signedIn;

  /// The member gave their first name, which the team will see.
  final bool hasName;

  /// The text of « Centre de secours », as typed.
  final String centreQuery;

  /// The centre picked from the list or added; null while the member
  /// types.
  final RescueCentre? centre;
  final KnownCentres known;

  /// The number typed, when valid.
  final TourneeNumber? number;

  /// The number typed is not one (« Un numéro de 1 à 9999. »); a blank
  /// field is not invalid, only incomplete.
  final bool numberInvalid;

  /// What « Année » holds when the screen opens: the current year.
  final String initialYear;

  /// The year typed, when valid.
  final CampaignYear? year;

  /// The year typed is not one (« Une année de 2000 à 2099. »).
  final bool yearInvalid;
  final DuplicateCheck duplicate;
  final CreateRun run;

  /// « Communes »: the communes picked, in the order picked (a chip each,
  /// with ✕). At least one is needed to « Créer ».
  final List<CommuneOption> communes;

  /// « Ajouter une commune… » shows: the form is not done with, and the
  /// tournée may cover one more commune.
  bool get canAddCommune =>
      communes.length < Tournee.maxCommunes && run is! TourneeCreated;

  /// The centre typed, as a station (null when blank or too long).
  RescueCentre? get _typedCentre => switch (RescueCentre.create(centreQuery)) {
    Ok(:final value) => value,
    Err() => null,
  };

  /// The name typed is longer than `RescueCentre.maxLength`.
  bool get centreTooLong => switch (RescueCentre.create(centreQuery)) {
    Err(failure: RescueCentreFailure.tooLong) => true,
    Ok() || Err() => false,
  };

  List<RescueCentre> get _knownCentres => switch (known) {
    CentresLoaded(:final centres) => centres,
    CentresLoading() || CentresUnavailable() => const [],
  };

  /// The known centres the typed text names, while none is picked: all of
  /// them before anything that names a station is typed. Compared as
  /// stations (`RescueCentreKey`): « villef » finds « CS Villefranche » and
  /// « CIS Villefranche-sur-Saône ».
  List<RescueCentre> get suggestions {
    if (centre != null || centreTooLong) return const [];
    final typed = _typedCentre;
    if (typed == null) return _knownCentres;
    return [
      for (final known in _knownCentres)
        if (known.key.value.contains(typed.key.value)) known,
    ];
  }

  /// The station the typed text would add (« Ajouter « villef » »), while
  /// none is picked and no known one is that same station.
  RescueCentre? get newCentre {
    final typed = _typedCentre;
    if (centre != null || typed == null) return null;
    if (_knownCentres.any(typed.isSameStationAs)) return null;
    return typed;
  }

  /// « Créer » can be pressed.
  bool get canCreate =>
      signedIn &&
      hasName &&
      centre != null &&
      communes.isNotEmpty &&
      number != null &&
      year != null &&
      duplicate != DuplicateCheck.taken &&
      (run is CreateIdle || run is CreateOffline);

  /// The tournée exists: the form is done with.
  bool get isCreated => run is TourneeCreated;

  /// A copy with the given fields replaced. [centre] is a function so it
  /// can be set back to null: `copyWith(centre: () => null)`.
  NewTourneeState copyWith({
    bool? signedIn,
    String? centreQuery,
    RescueCentre? Function()? centre,
    KnownCentres? known,
    TourneeNumber? Function()? number,
    bool? numberInvalid,
    CampaignYear? Function()? year,
    bool? yearInvalid,
    DuplicateCheck? duplicate,
    CreateRun? run,
    List<CommuneOption>? communes,
  }) => NewTourneeState(
    signedIn: signedIn ?? this.signedIn,
    hasName: hasName,
    centreQuery: centreQuery ?? this.centreQuery,
    centre: centre == null ? this.centre : centre(),
    known: known ?? this.known,
    number: number == null ? this.number : number(),
    numberInvalid: numberInvalid ?? this.numberInvalid,
    initialYear: initialYear,
    year: year == null ? this.year : year(),
    yearInvalid: yearInvalid ?? this.yearInvalid,
    duplicate: duplicate ?? this.duplicate,
    run: run ?? this.run,
    communes: communes ?? this.communes,
  );
}
