enum TargetFrequency {
  daily('Her gün'),
  weekly('Haftada bir'),
  custom('Belirli günler');

  const TargetFrequency(this.label);
  final String label;
}
