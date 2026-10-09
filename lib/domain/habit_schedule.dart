import 'date_utils.dart';

enum TargetFrequency {
  daily('Her gün'),
  weekly('Haftalık'),
  custom('Belirli günler');

  const TargetFrequency(this.label);
  final String label;
}

/// Alışkanlığın duraklatıldığı (tatil) gün aralığı. [end] null ise hâlâ sürüyor.
class PauseRange {
  const PauseRange({required this.start, this.end});

  /// Dahil.
  final DateTime start;

  /// Dahil; null = açık uçlu.
  final DateTime? end;

  bool contains(DateTime day) {
    final d = dateOnly(day);
    return !d.isBefore(dateOnly(start)) &&
        (end == null || !d.isAfter(dateOnly(end!)));
  }
}

/// Bir alışkanlığın hangi günlerin "dönem" sayıldığını tanımlar.
///
/// - daily: her gün bir dönemdir.
/// - custom: yalnızca seçili hafta günleri birer dönemdir.
/// - weekly: başlangıç gününden itibaren 7 günlük bloklar birer dönemdir; blokta
///   [timesPerWeek] farklı gün tamamlanınca dönem tamamlanmış sayılır.
class HabitSchedule {
  const HabitSchedule({
    required this.frequency,
    this.customDays = const {},
    required this.startDate,
    this.timesPerWeek = 1,
    this.pauses = const [],
  });

  final TargetFrequency frequency;
  final Set<int> customDays;
  final DateTime startDate;
  final int timesPerWeek;

  /// Duraklatılmış aralıklar: içine düşen ve tamamlanmamış dönemler ceza almaz.
  final List<PauseRange> pauses;

  /// Verilen gün, tamamlanması beklenen bir gün mü? (weekly için her gün true;
  /// hafta içinde herhangi bir gün tamamlanabilir.) Duraklatmayı hesaba katmaz.
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

  bool isPausedOn(DateTime day) => pauses.any((p) => p.contains(day));

  /// Haftalık alışkanlıkta günün ait olduğu 7 günlük bloğun başlangıcı.
  DateTime weekPeriodStart(DateTime day) {
    final offset = daysBetween(startDate, day);
    return addDays(dateOnly(startDate), offset - offset % 7);
  }

  /// "Her gün", "Haftada 3 kez", "Belirli günler" gibi kısa açıklama.
  String get label => switch (frequency) {
    TargetFrequency.weekly =>
      timesPerWeek == 1 ? 'Haftada bir' : 'Haftada $timesPerWeek kez',
    _ => frequency.label,
  };
}
