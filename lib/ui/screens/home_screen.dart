import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// Placeholder for Accueil (PLAN §5.3), where the app starts.
///
/// Until a tournée exists it shows the app's name as its title. In debug
/// builds it also offers the component gallery.
final class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.showGallery});

  final bool showGallery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: showGallery
          ? Padding(
              padding: const EdgeInsets.all(AppSizes.gutter),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SecondaryButton(
                  key: const Key('home.gallery'),
                  label: l10n.galleryTitle,
                  // `push` stacks the gallery on top of home, so the app
                  // bar shows a back arrow.
                  onPressed: () => context.push(AppRoutes.gallery),
                ),
              ),
            )
          : null,
    );
  }
}
