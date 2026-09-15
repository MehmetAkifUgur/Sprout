import 'package:flutter/material.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.strokeWidth = 7,
    this.child,
  });

  /// 0–1
  final double value;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: value.clamp(0, 1)),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          if (child != null) Center(child: child),
        ],
      ),
    );
  }
}
