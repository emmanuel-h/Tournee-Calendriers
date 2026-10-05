import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/components/status_tile.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// Debug-only screen showing every shared component, to check them on a
/// phone without building a real screen first.
final class ComponentGalleryScreen extends StatelessWidget {
  const ComponentGalleryScreen({super.key});

  /// One sample tile per status; house numbers are sample data, not copy.
  static const _tiles = [
    ('1', ToDoTile(), false),
    ('3', DoneTile(), false),
    ('3bis', NobodyHomeTile(), false),
    ('5', ComeBackTile(), false),
    ('8', BuildingPartialTile(done: 7, total: 12), true),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const gutter = EdgeInsets.symmetric(horizontal: AppSizes.gutter);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.galleryTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          SectionHeader(l10n.galleryButtons),
          Padding(
            padding: gutter,
            child: Column(
              spacing: 12,
              children: [
                PrimaryButton(
                  label: l10n.galleryPrimaryButton,
                  onPressed: () {},
                ),
                PrimaryButton(
                  label: l10n.galleryDisabledButton,
                  onPressed: null,
                ),
                SecondaryButton(
                  label: l10n.gallerySecondaryButton,
                  onPressed: () {},
                ),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: l10n.galleryCompactButton,
                        compact: true,
                        onPressed: () {},
                      ),
                    ),
                    Expanded(
                      child: SecondaryButton(
                        label: l10n.galleryCompactButton,
                        compact: true,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SectionHeader(l10n.galleryStatusTiles),
          Padding(
            padding: gutter,
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                for (final (number, status, isBuilding) in _tiles)
                  SizedBox(
                    width: 170,
                    child: StatusTile(
                      number: number,
                      status: status,
                      isBuilding: isBuilding,
                      onTap: () {},
                      onLongPress: () {},
                    ),
                  ),
              ],
            ),
          ),
          SectionHeader(l10n.gallerySheetAndSnackBar),
          Padding(
            padding: gutter,
            child: Column(
              spacing: 12,
              children: [
                SecondaryButton(
                  key: const Key('gallery.showSheet'),
                  label: l10n.galleryShowSheet,
                  onPressed: () => showAppBottomSheet<void>(
                    context: context,
                    builder: (context) => SheetScaffold(
                      title: l10n.gallerySheetTitle,
                      children: [
                        Text(l10n.gallerySheetBody),
                        PrimaryButton(
                          label: l10n.galleryPrimaryButton,
                          compact: true,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ),
                SecondaryButton(
                  key: const Key('gallery.showSnackBar'),
                  label: l10n.galleryShowSnackBar,
                  onPressed: () => showActionSnackBar(
                    ScaffoldMessenger.of(context),
                    message: l10n.gallerySnackBarMessage,
                    actionLabel: l10n.undo,
                    onAction: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
