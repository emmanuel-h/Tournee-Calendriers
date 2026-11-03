/// How a don was paid (PLAN §2): « Espèces », « Chèque » or « Carte
/// bancaire ». A calendar given for nothing is not a payment method but a
/// `Donation.free()`.
enum PaymentMethod {
  /// « Espèces ».
  cash,

  /// « Chèque ».
  cheque,

  /// « Carte bancaire ».
  card,
}
