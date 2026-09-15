/// Büyüme algoritmasının dengeleme (balancing) değerleri.
///
/// Tüm eşikler burada tutulur; oyun hissini değiştirmek için yalnızca bu
/// dosyayı düzenlemek yeterlidir.
class GrowthConstants {
  const GrowthConstants._();

  static const double minScore = 0;
  static const double maxScore = 100;

  /// Günlük/özel günlük alışkanlıkta tamamlanan her dönem için taban puan.
  static const double dailyBasePoints = 4;

  /// Haftalık alışkanlıkta tamamlanan her hafta için taban puan.
  static const double weeklyBasePoints = 15;

  /// Ardışık her tamamlanan dönem çarpana eklenen bonus (0.1 = %10).
  static const double streakBonusPerPeriod = 0.1;

  /// Streak çarpanının üst sınırı.
  static const double maxStreakMultiplier = 2.0;

  /// Ceza başlamadan önce tolere edilen ardışık kaçırılmış dönem sayısı.
  static const int gracePeriods = 1;

  /// Tolerans aşıldıktan sonraki ilk kaçırılan dönemin cezası.
  static const double decayBase = 5;

  /// Her ek kaçırılan dönemde cezaya eklenen artış.
  static const double decayIncrement = 2;

  /// Tek dönemdeki azami ceza.
  static const double maxDecayPerPeriod = 15;

  /// Bu kadar ardışık dönem kaçırılınca bitki solar (günlük / özel).
  static const int wiltAfterMissedDaily = 3;

  /// Bu kadar ardışık hafta kaçırılınca bitki solar (haftalık).
  static const int wiltAfterMissedWeekly = 2;
}

/// Bitki büyüme evreleri ve puan aralıkları (Bölüm 5).
enum GrowthStage {
  seed('Tohum', 0, 20),
  sprout('Filiz', 21, 45),
  sapling('Fidan', 46, 70),
  blooming('Çiçek', 71, 90),
  grown('Tam Büyümüş', 91, 100);

  const GrowthStage(this.label, this.minScore, this.maxScore);

  final String label;
  final int minScore;
  final int maxScore;

  static GrowthStage fromScore(double score) {
    final rounded = score.round();
    for (final stage in values) {
      if (rounded <= stage.maxScore) return stage;
    }
    return grown;
  }
}
