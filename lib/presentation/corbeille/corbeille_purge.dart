import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/purge_corbeille.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// The 30-day purge of the Corbeille (PLAN §5.11), run on the streets bound
/// now: the open tournée's, or the phone's own while none is open.
///
/// A `FutureProvider` runs its function once and keeps the result. It
/// `ref.watch`es the use case, which watches the street storage: when
/// another tournée is opened, the composition root binds other streets, so
/// this provider is built again and purges those too. The app listens to
/// it from the start (`TourneeApp`), which is what starts it; nothing is
/// shown of it.
///
/// A failure (the streets cannot be read: this member was removed) only
/// settles it in error. `retry` returning null turns off Riverpod's own
/// retries, which could not help: the purge is tried again at the next
/// start, or when a tournée is opened.
final corbeillePurgeProvider = FutureProvider<CorbeillePurged>(
  (ref) => ref.watch(purgeCorbeilleProvider)(),
  retry: (_, _) => null,
);
