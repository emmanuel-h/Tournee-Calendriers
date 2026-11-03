import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/offline/offline_auto_download.dart';

/// Keeps the open tournée downloaded for offline use while the app runs,
/// unseen (PLAN §7): it keeps `offlineAutoDownloadProvider` alive (which
/// checks at start-up and when a tournée opens) and asks it to check again
/// each time the app comes back to the foreground, when the network may be
/// back. Shows nothing but [child].
final class OfflineUpkeep extends ConsumerStatefulWidget {
  const OfflineUpkeep({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OfflineUpkeep> createState() => _OfflineUpkeepState();
}

final class _OfflineUpkeepState extends ConsumerState<OfflineUpkeep> {
  /// Tells when the app goes to the background and comes back.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      // `ref.read`: the download of the tournée open now, once.
      onResume: () => unawaited(ref.read(offlineAutoDownloadProvider).check()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `ref.listen` keeps the provider alive (and built again when another
    // tournée opens) without building this widget again.
    ref.listen(offlineAutoDownloadProvider, (_, _) {});
    return widget.child;
  }
}
