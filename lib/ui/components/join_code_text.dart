import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/components/copy_code_button.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';

/// A tournée's join code and its ⧉ (PLAN §5.2, §5.8), in Équipe and on
/// « Nouvelle tournée ». The code shrinks rather than overflow when the
/// screen is narrow or the phone's text is set large, so the copy button
/// always stays beside it.
final class JoinCodeText extends StatelessWidget {
  const JoinCodeText({
    super.key,
    required this.code,
    required this.style,
    this.codeKey,
    this.copyKey,
  });

  /// The code as shown, dash included (`K7P-2QX`).
  final String code;

  /// The text style of the code; drawn in the ink colour.
  final TextStyle style;

  /// The keys of the code and of its button, for the widget tests.
  final Key? codeKey;
  final Key? copyKey;

  @override
  Widget build(BuildContext context) => Row(
    // As wide as the code and its button, so it also sits in a `Wrap`.
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            code,
            key: codeKey,
            style: style.copyWith(color: AppColors.of(context).ink),
          ),
        ),
      ),
      CopyCodeButton(key: copyKey, code: code),
    ],
  );
}
