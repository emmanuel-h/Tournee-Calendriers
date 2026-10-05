import 'package:go_router/go_router.dart';

/// Opens [location] on top of the current screen without waiting: `push`
/// returns a `Future` that ends only when the pushed screen is closed.
void unawaitedPush(GoRouter router, String location) {
  router.push<void>(location).ignore();
}
