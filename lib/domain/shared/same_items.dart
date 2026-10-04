/// Whether [a] and [b] hold equal items in the same order.
///
/// Two Dart lists are `==` only when they are the same object, so a value
/// type holding a list (a floor and its doors) compares the items itself.
/// `package:collection` offers the same, but it is not a dependency of the
/// app and the domain needs only this.
bool sameItems<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
