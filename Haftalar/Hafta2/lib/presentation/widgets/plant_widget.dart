import 'package:flutter/material.dart';

import '../../core/constants/growth_constants.dart';
import '../../core/constants/plant_types.dart';

/// Hafta 2 placeholder: evreyi emoji ile gösterir, solunca gri/soluk olur.
///
/// API (score, type, isWilted, size) Hafta 3'teki çizimli bitkiyle aynıdır;
/// böylece yalnızca bu dosya değiştirilerek görsel yükseltilebilir.
class PlantWidget extends StatelessWidget {
  const PlantWidget({
    super.key,
    required this.score,
    required this.type,
    this.isWilted = false,
    this.size = 48,
  });

  final double score;
  final PlantType type;
  final bool isWilted;
  final double size;

  static String emojiFor(GrowthStage stage, PlantType type) => switch (stage) {
    GrowthStage.seed => '🌰',
    GrowthStage.sprout => '🌱',
    GrowthStage.sapling => '🪴',
    GrowthStage.blooming || GrowthStage.grown => switch (type) {
      PlantType.flower => '🌹',
      PlantType.sunflower => '🌻',
      PlantType.tree => stage == GrowthStage.grown ? '🍎' : '🌳',
      PlantType.cactus => '🌵',
    },
  };

  @override
  Widget build(BuildContext context) {
    final stage = GrowthStage.fromScore(score);
    Widget emoji = Text(
      emojiFor(stage, type),
      style: TextStyle(fontSize: size * 0.6),
    );
    if (isWilted) {
      emoji = Opacity(
        opacity: 0.5,
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.brown, BlendMode.modulate),
          child: emoji,
        ),
      );
    }
    return Semantics(
      label: '${type.label}, ${stage.label}${isWilted ? ', solmuş' : ''}',
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: a, child: child),
            child: KeyedSubtree(key: ValueKey((stage, isWilted)), child: emoji),
          ),
        ),
      ),
    );
  }
}
