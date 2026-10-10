import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The main action of a screen: a red pill (« Créer », « Rejoindre »).
///
/// It fills the width it is given. Passing `null` as [onPressed] disables it,
/// the Flutter convention for every button.
final class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 52 dp instead of 56 dp, for buttons inside sheets or side by side.
  final bool compact;

  /// Drawn before the label (« + Importer des rues »); decoration only, the
  /// label names the action.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return icon == null
        ? FilledButton(
            onPressed: onPressed,
            style: _sizeStyle(compact),
            child: Text(label),
          )
        : FilledButton.icon(
            onPressed: onPressed,
            style: _sizeStyle(compact),
            icon: Icon(icon, size: AppSizes.smallIcon),
            label: Text(label),
          );
  }
}

/// A secondary action: a white pill with a thin outline.
final class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.leading,
    this.destructive = false,
    this.strong = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// 52 dp instead of 56 dp, for buttons inside sheets or side by side.
  final bool compact;

  /// Drawn before the label (the building of « Transformer en
  /// immeuble… »); decoration only, the label names the action. A widget
  /// rather than an `IconData`, so a drawn icon fits too.
  final Widget? leading;

  /// Outline and label in the accent red, for an action that removes
  /// something (« Supprimer la rue »); it still asks before doing it.
  final bool destructive;

  /// Outline in ink rather than the light line, for the action a sheet
  /// leads to most after its main one (« Modifier les portes »).
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    final colors = AppColors.of(context);
    final accent = colors.accent;
    final style = destructive
        ? _sizeStyle(compact).copyWith(
            foregroundColor: WidgetStatePropertyAll(accent),
            side: WidgetStatePropertyAll(
              BorderSide(color: accent, width: AppSizes.borderWidth),
            ),
          )
        : strong
        ? _sizeStyle(compact).copyWith(
            side: WidgetStatePropertyAll(
              BorderSide(color: colors.ink, width: AppSizes.borderWidth),
            ),
          )
        : _sizeStyle(compact);
    return leading == null
        ? OutlinedButton(onPressed: onPressed, style: style, child: Text(label))
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: leading,
            label: Text(label),
          );
  }
}

/// A small outlined pill that sits in a row beside text (« Partager »,
/// « Restaurer »): as wide as its label, 40 dp drawn, still answering taps
/// over 48 dp.
final class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.strong = false,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Outline in ink rather than the light line, for the action the row is
  /// about (« Restaurer »).
  final bool strong;

  /// What screen readers hear instead of [label], to say which row the
  /// button acts on (« Restaurer 14ter Rue des Lilas »).
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      // A node of its own, not merged with the text beside it.
      container: true,
      button: true,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(0, AppSizes.pillHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14),
          ),
          textStyle: const WidgetStatePropertyAll(AppTextStyles.pill),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: strong ? colors.ink : colors.line,
              width: AppSizes.borderWidth,
            ),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Height and label style shared by both buttons; colours and the pill shape
/// come from the theme (`buildAppTheme`).
ButtonStyle _sizeStyle(bool compact) {
  final height = compact ? AppSizes.compactButtonHeight : AppSizes.buttonHeight;
  return ButtonStyle(
    // `fromHeight` asks for the full available width at a fixed height.
    minimumSize: WidgetStatePropertyAll(Size.fromHeight(height)),
    textStyle: WidgetStatePropertyAll(
      compact ? AppTextStyles.compactButton : AppTextStyles.button,
    ),
  );
}
