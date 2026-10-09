import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why a year cannot become a [CampaignYear].
enum CampaignYearFailure {
  /// The text is not made of digits only.
  notANumber,

  /// Not between [CampaignYear.first] and [CampaignYear.last].
  outOfRange,
}

/// The year of a campaign (« Campagne 2026 », PLAN §2): a tournée holds
/// one campaign per year, and the statuses belong to it.
///
/// Chosen by the creator, pre-filled with the current year: calendars sold
/// in late 2026 may be called 2027 (PLAN §5.2). The domain has no clock, so
/// the range is fixed rather than relative to today.
final class CampaignYear {
  const CampaignYear._(this.value);

  /// The earliest year accepted.
  static const first = 2000;

  /// The latest year accepted: a typo such as `20266` is refused, and the
  /// year stays four digits in storage (`campaigns/2026`, PLAN §6.2).
  static const last = 2099;

  static final _digits = RegExp(r'^\d+$');

  /// The campaign of [year], or [CampaignYearFailure.outOfRange].
  static Result<CampaignYear, CampaignYearFailure> create(int year) {
    if (year < first || year > last) {
      return const Err(CampaignYearFailure.outOfRange);
    }
    return Ok(CampaignYear._(year));
  }

  /// Reads the « Année » field: digits only, spaces around ignored.
  static Result<CampaignYear, CampaignYearFailure> parse(String text) {
    final digits = text.trim();
    // Checked first: `int.tryParse` would also read `+2026` or `0x7EA`.
    if (!_digits.hasMatch(digits)) {
      return const Err(CampaignYearFailure.notANumber);
    }
    // Null past the largest `int`, which is far out of range anyway.
    final year = int.tryParse(digits);
    if (year == null) return const Err(CampaignYearFailure.outOfRange);
    return create(year);
  }

  final int value;

  @override
  bool operator ==(Object other) =>
      other is CampaignYear && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'CampaignYear($value)';
}
