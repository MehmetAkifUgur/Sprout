import 'package:flutter/material.dart';

/// Kullanıcının alışkanlığına atayabileceği bitki türleri.
enum PlantType {
  flower('Gül', Color(0xFFE85D75)),
  sunflower('Ayçiçeği', Color(0xFFFFC53D)),
  tree('Elma Ağacı', Color(0xFFD64545)),
  cactus('Kaktüs', Color(0xFFFF8FB1));

  const PlantType(this.label, this.accent);

  final String label;

  /// Çiçek / meyve rengi.
  final Color accent;

  static PlantType fromName(String name) =>
      values.firstWhere((t) => t.name == name, orElse: () => flower);
}
