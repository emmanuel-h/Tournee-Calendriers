import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// A ring in the come-back blue that pulses around [child] for [duration],
/// then goes (PLAN §5.17, StreetRing mockup): the house or the door opened
/// from « À repasser » or a reminder, so the eye finds it. It draws
/// outside [child] and takes no tap.
final class RingPulse extends StatefulWidget {
  const RingPulse({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 2),
  });

  final Widget child;
  final Duration duration;

  /// How many times the ring swells in [duration].
  static const pulses = 3;

  @override
  State<RingPulse> createState() => _RingPulseState();
}

/// A `State` with `SingleTickerProviderStateMixin`: the mixin gives the
/// animation its clock (one tick per frame, paused off screen).
final class _RingPulseState extends State<RingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Stack(
      // The ring sits around the child, past its edges.
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                if (_pulse.isCompleted) return const SizedBox.shrink();
                // 0 → 1 → 0, [RingPulse.pulses] times.
                final swell =
                    (1 -
                        math.cos(
                          _pulse.value * 2 * math.pi * RingPulse.pulses,
                        )) /
                    2;
                return Transform.scale(
                  scale: 1 + 0.04 * swell,
                  child: DecoratedBox(
                    key: const Key('ringPulse.ring'),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSizes.tileRadius),
                      border: Border.all(
                        color: colors.onComeBack,
                        width: AppSizes.ringWidth,
                        strokeAlign: BorderSide.strokeAlignOutside,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.onComeBack.withValues(alpha: 0.18),
                          spreadRadius: AppSizes.ringHalo * swell,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
