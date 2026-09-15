/// Kullanıcının alışkanlığına atayabileceği bitki türleri.
/// (Hafta 2: placeholder görseller; çizimler Hafta 3'te.)
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
