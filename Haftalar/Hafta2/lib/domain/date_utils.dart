/// Saf Dart tarih yardımcıları. Tüm gün hesapları yerel takvim günü üzerinden
/// yapılır; gün eklemek için `DateTime(y, m, d + n)` kullanılır, böylece yaz
/// saati geçişlerinde 23/25 saatlik günler sorun çıkarmaz.
library;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// İki tarih arasındaki takvim günü farkı (b - a).
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}
