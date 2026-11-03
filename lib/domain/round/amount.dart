import 'package:tournee_calendriers/domain/shared/result.dart';

/// Why a text or a number of cents cannot become an [Amount]. Each one has
/// its own words under « Montant » (PLAN §5.13).
enum AmountFailure {
  /// Nothing typed: « Écrivez un montant. »
  empty,

  /// Not a number, or no money at all: « Entrez un montant valide. »
  notValid,

  /// A third digit after the comma: « Deux chiffres après la virgule au
  /// plus. »
  tooManyDecimals,

  /// Past [Amount.largest]: « 1 000 € au plus par don. »
  tooLarge,
}

/// The money of one don (PLAN §5.13), in whole euro cents: 0,01 € to
/// 1 000 €.
///
/// Cents in an `int` rather than euros in a `double`: `0.1 + 0.2` is not
/// `0.3` in floating point, and a tournée's total must be right to the
/// cent.
final class Amount {
  const Amount._(this.cents);

  /// The smallest don, in cents: 0,01 €.
  static const smallest = 1;

  /// The largest don, in cents: 1 000 €.
  static const largest = 100000;

  // Digits, then at most one comma or dot followed by digits. Either side
  // may be empty (« 7, », « ,5 »); `parse` refuses a lone separator.
  static final _euros = RegExp(r'^(\d*)(?:[.,](\d*))?$');
  static final _spaces = RegExp(r'\s');
  static final _leadingZeros = RegExp('^0+');

  /// The amount of [cents], or why it is not one.
  static Result<Amount, AmountFailure> create(int cents) {
    if (cents < smallest) return const Err(AmountFailure.notValid);
    if (cents > largest) return const Err(AmountFailure.tooLarge);
    return Ok(Amount._(cents));
  }

  /// Reads the « Montant » field: « 7,50 », « 7.5 », « 7 » or « 1 000 »
  /// (spaces are dropped, so the French thousands separator is too).
  static Result<Amount, AmountFailure> parse(String text) {
    final typed = text.replaceAll(_spaces, '');
    if (typed.isEmpty) return const Err(AmountFailure.empty);
    final match = _euros.firstMatch(typed);
    if (match == null) return const Err(AmountFailure.notValid);
    final euros = match[1]!.replaceFirst(_leadingZeros, '');
    final decimals = match[2] ?? '';
    if (match[1]!.isEmpty && decimals.isEmpty) {
      return const Err(AmountFailure.notValid);
    }
    if (decimals.length > 2) return const Err(AmountFailure.tooManyDecimals);
    // Five digits of euros are 10 000 € at least: refused before
    // `int.parse`, which cannot read a number past the largest `int`.
    if (euros.length > 4) return const Err(AmountFailure.tooLarge);
    return create(
      int.parse(euros.isEmpty ? '0' : euros) * 100 +
          int.parse(decimals.padRight(2, '0')),
    );
  }

  final int cents;

  @override
  bool operator ==(Object other) => other is Amount && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => 'Amount($cents)';
}
