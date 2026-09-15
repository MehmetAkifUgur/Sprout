import 'date_utils.dart';

enum TargetFrequency {
  daily('Her gün'),
  weekly('Haftada bir'),
  custom('Belirli günler');

  const TargetFrequency(this.label);
  final String label;
}

/// Bir alışkanlığın hangi günlerin "dönem" sayıldığını tanımlar.
///
/// - daily: her gün bir dönemdir.
/// - custom: yalnızca seçili hafta günleri birer dönemdir.
/// - weekly: başlangıç gününden itibaren 7 günlük bloklar birer dönemdir.
class HabitSchedule {
  const HabitSchedule({
    required this.frequency,
    this.customDays = const {},
    required this.startDate,
  });

  final TargetFrequency frequency;
  final Set<int> customDays;
  final DateTime startDate;

  /// Verilen gün, tamamlanması beklenen bir gün mü? (weekly için her gün true;
  /// hafta içinde herhangi bir gün tamamlanabilir.)
  bool isDueOn(DateTime day) {
    if (dateOnly(day).isBefore(dateOnly(startDate))) return false;
    switch (frequency) {
      case TargetFrequency.daily:
      case TargetFrequency.weekly:
        return true;
      case TargetFrequency.custom:
        return customDays.contains(day.weekday);
    }
  }

  /// Haftalık alışkanlıkta günün ait olduğu 7 günlük bloğun başlangıcı.
  DateTime weekPeriodStart(DateTime day) {
    final offset = daysBetween(startDate, day);
    return addDays(dateOnly(startDate), offset - offset % 7);
  }
}
