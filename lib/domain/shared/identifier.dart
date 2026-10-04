/// Returns [value] when it holds something other than spaces, otherwise
/// throws an [ArgumentError] naming the identifier ([name]).
///
/// Identifiers (a member, a street, a BAN street) are never typed by a
/// person: an adapter makes them (Firebase, the BAN, a generator on the
/// phone). A blank one is a bug in that adapter, not something the user can
/// fix, so it throws instead of returning a failure value.
String requireNotBlank(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
  return value;
}
