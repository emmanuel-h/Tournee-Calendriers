import 'dart:math';

import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Opens [builder]'s content as a modal bottom sheet over a dimmed screen
/// (Fiche maison, Mes secteurs, Ajouter des numéros…).
///
/// `isScrollControlled` lets a tall sheet grow past half the screen, and
/// `useSafeArea` keeps it below the status bar. Returns what the sheet passes
/// to `Navigator.pop`, if anything.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: builder,
);

/// The inside of every bottom sheet: grabber, optional title, then [children]
/// stacked with even spacing, as in the mockups.
final class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    this.title,
    this.spacing = 18,
    required this.children,
  });

  final String? title;
  final List<Widget> children;

  /// Space between two children: 18 dp in most sheets, less in a dense
  /// form (« Décrire l'immeuble »).
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final title = this.title;
    // The sheet is drawn edge to edge, under the phone's navigation bar
    // (`useSafeArea` only guards its top and sides). `paddingOf` is the
    // height of that bar: tall with the 3-button bar, thin with gestures.
    // `viewInsetsOf` is the keyboard, which covers the bar when it is up,
    // hence the larger of the two rather than their sum.
    final bottom = max(
      MediaQuery.viewInsetsOf(context).bottom,
      MediaQuery.paddingOf(context).bottom,
    );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing,
        children: [
          Center(
            child: Container(
              width: AppSizes.dragHandleWidth,
              height: AppSizes.dragHandleHeight,
              decoration: BoxDecoration(
                color: colors.line,
                borderRadius: BorderRadius.circular(
                  AppSizes.dragHandleHeight / 2,
                ),
              ),
            ),
          ),
          if (title != null)
            Semantics(
              header: true,
              child: Text(
                title,
                style: AppTextStyles.title.copyWith(color: colors.ink),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}
