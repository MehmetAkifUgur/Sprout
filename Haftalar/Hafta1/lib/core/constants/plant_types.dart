/// Kullanıcının alışkanlığına atayabileceği bitki türleri.
/// (Görseller Hafta 2–3'te eklenecek; şimdilik yalnızca ad.)
enum PlantType {
  flower('Gül'),
  sunflower('Ayçiçeği'),
  tree('Elma Ağacı'),
  cactus('Kaktüs');

  const PlantType(this.label);

  final String label;

  static PlantType fromName(String name) =>
      values.firstWhere((t) => t.name == name, orElse: () => flower);
}
