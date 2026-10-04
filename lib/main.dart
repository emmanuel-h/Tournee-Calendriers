import 'package:tournee_calendriers/bootstrap/bootstrap.dart';

/// Entry point Flutter looks for in `lib/main.dart`. It only hands over to the
/// composition root, so that everything the app is wired with lives in
/// `bootstrap/`. It returns the start-up `Future`, so a test can wait until
/// the app runs.
Future<void> main() => bootstrap();
