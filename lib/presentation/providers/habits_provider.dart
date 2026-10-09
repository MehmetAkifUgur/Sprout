import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/growth_constants.dart';
import '../../data/models/habit.dart';
import '../../domain/date_utils.dart';
import '../../domain/growth_engine.dart';
import '../../domain/habit_schedule.dart';
import 'providers.dart';

/// Bir alışkanlığın UI için hazırlanmış anlık görünümü.
class HabitView {
  const HabitView({
    required this.habit,
    required this.completedDays,
    required this.growth,
    required this.today,
  });

  final Habit habit;
  final Set<DateTime> completedDays;
  final GrowthResult growth;
  final DateTime today;

  int get id => habit.id!;
  GrowthStage get stage => growth.stage;

  bool get completedToday => completedDays.contains(today);

  bool get pausedToday => habit.schedule.isPausedOn(today);

  /// Bugün işaretlenebilir mi (plana göre). Tatilde de tamamlanabilir.
  bool get canToggleToday => habit.schedule.isDueOn(today);

  /// Bugün yapılması beklenen mi (tatildeyse hayır).
  bool get dueToday => canToggleToday && !pausedToday;

  /// Haftalık alışkanlıkta bu haftaki bloğun tamamlanan gün sayısı.
  int get completionsThisWeek =>
      GrowthEngine.completionsInWeek(habit.schedule, completedDays, today);

  /// Günlük/özel: bugün tamamlandı mı. Haftalık: bu hafta hedefe ulaşıldı mı.
  bool get doneThisPeriod {
    if (habit.targetFrequency != TargetFrequency.weekly) return completedToday;
    return completionsThisWeek >= habit.timesPerWeek;
  }

  /// Bu dönem zaten tamamlandıysa hatırlatmanın başlayacağı ilk gün.
  DateTime? get reminderNotBefore {
    if (!doneThisPeriod) return null;
    if (habit.targetFrequency == TargetFrequency.weekly) {
      return addDays(habit.schedule.weekPeriodStart(today), 7);
    }
    return addDays(today, 1);
  }

  static HabitView compute(Habit habit, Set<DateTime> days, DateTime now) {
    final today = dateOnly(now);
    final growth = GrowthEngine.evaluate(
      schedule: habit.schedule,
      completedDays: days,
      today: today,
    );
    return HabitView(
      habit: habit.copyWith(growthScore: growth.score),
      completedDays: days,
      growth: growth,
      today: today,
    );
  }
}

/// Bir günü işaretlemenin sonucu: yeni durum ve varsa evre değişimi.
class ToggleResult {
  const ToggleResult({
    required this.habitName,
    required this.completed,
    this.stageChange,
  });

  final String habitName;

  /// İşlemden sonra gün tamamlanmış mı.
  final bool completed;
  final StageChange? stageChange;
}

/// Toggle sonrası evre değiştiyse UI'ın kutlama/uyarı göstermesi için döner.
class StageChange {
  const StageChange(this.habitName, this.from, this.to);
  final String habitName;
  final GrowthStage from;
  final GrowthStage to;
  bool get isUp => to.index > from.index;
}

final habitsProvider = AsyncNotifierProvider<HabitsNotifier, List<HabitView>>(
  HabitsNotifier.new,
);

class HabitsNotifier extends AsyncNotifier<List<HabitView>> {
  late DateTime _loadedDay;

  @override
  Future<List<HabitView>> build() async {
    final repo = ref.watch(habitRepositoryProvider);
    final now = ref.watch(clockProvider)();
    _loadedDay = dateOnly(now);

    final habits = await repo.getHabits();
    final allDays = await repo.getAllCompletedDays();
    // Puan her seferinde log'lardan hesaplanır; growth_score önbelleği burada
    // güncellenmez (yalnızca kullanıcı bir günü işaretlediğinde yazılır).
    return [
      for (final habit in habits)
        HabitView.compute(habit, allDays[habit.id] ?? {}, now),
    ];
  }

  /// Uygulama ön plana döndüğünde gün değiştiyse puanları yeniden hesaplar.
  void refreshIfDayChanged() {
    if (dateOnly(ref.read(clockProvider)()) != _loadedDay) {
      ref.invalidateSelf();
    }
  }

  Future<Habit> addHabit(Habit habit) async {
    final saved = await ref.read(habitRepositoryProvider).addHabit(habit);
    await _reloadAndSync(saved.id!);
    return saved;
  }

  Future<void> updateHabit(Habit habit) async {
    await ref.read(habitRepositoryProvider).updateHabit(habit);
    await _reloadAndSync(habit.id!);
  }

  /// Bugünden itibaren tatile alır; kaçırılan günler ceza almaz.
  Future<void> pauseHabit(int id) async {
    await ref
        .read(habitRepositoryProvider)
        .pauseHabit(id, ref.read(clockProvider)());
    await _reloadAndSync(id);
  }

  /// Tatili bitirir; bugün yeniden normal gün sayılır.
  Future<void> resumeHabit(int id) async {
    await ref
        .read(habitRepositoryProvider)
        .resumeHabit(id, ref.read(clockProvider)());
    await _reloadAndSync(id);
  }

  Future<void> deleteHabit(int id) async {
    await ref.read(habitRepositoryProvider).deleteHabit(id);
    await _guard('Hatırlatma iptal edilemedi', () {
      return ref.read(notificationServiceProvider).cancelHabit(id);
    });
    final current = state.value;
    if (current != null) {
      state = AsyncData([...current.where((v) => v.id != id)]);
    }
  }

  Future<ToggleResult?> toggleToday(int habitId) {
    return toggleDay(habitId, ref.read(clockProvider)());
  }

  Future<ToggleResult?> toggleDay(int habitId, DateTime day) async {
    final current = await future;
    final index = current.indexWhere((v) => v.id == habitId);
    if (index < 0) return null;
    final old = current[index];
    final date = dateOnly(day);
    final now = ref.read(clockProvider)();
    if (date.isAfter(dateOnly(now)) ||
        date.isBefore(dateOnly(old.habit.createdAt))) {
      return null;
    }

    final nowCompleted = !old.completedDays.contains(date);
    final repo = ref.read(habitRepositoryProvider);
    await repo.setCompleted(habitId, date, nowCompleted);

    final days = {...old.completedDays};
    nowCompleted ? days.add(date) : days.remove(date);
    final updated = HabitView.compute(old.habit, days, now);
    await repo.updateScore(habitId, updated.growth.score);

    final next = [...current]..[index] = updated;
    state = AsyncData(next);
    // Bu dönem tamamlandıysa bugünün hatırlatması atlanır; geri alınırsa döner.
    if (old.doneThisPeriod != updated.doneThisPeriod) {
      await _syncReminder(updated);
    }

    return ToggleResult(
      habitName: old.habit.name,
      completed: nowCompleted,
      stageChange: old.stage == updated.stage
          ? null
          : StageChange(old.habit.name, old.stage, updated.stage),
    );
  }

  /// Tüm verileri siler; silmeden önce otomatik bir yedek saklanır.
  Future<void> resetAll() async {
    await ref.read(habitRepositoryProvider).resetAll();
    await _guard('Hatırlatmalar iptal edilemedi', () {
      return ref.read(notificationServiceProvider).cancelAll();
    });
    ref.invalidate(onboardingDoneProvider);
    ref.invalidate(resetBackupAvailableProvider);
    ref.invalidateSelf();
  }

  /// Son sıfırlamadan önce alınan yedeği geri getirir.
  Future<void> restoreResetBackup() async {
    await ref.read(habitRepositoryProvider).restoreResetBackup();
    await _afterBulkChange();
  }

  /// JSON yedeğini içe aktarır; mevcut alışkanlıkların yerini alır.
  /// Biçim bozuksa [FormatException] atar ve hiçbir şeyi değiştirmez.
  Future<int> importJson(String json) async {
    final count = await ref.read(habitRepositoryProvider).importJson(json);
    await _afterBulkChange();
    return count;
  }

  Future<String> exportJson() => ref.read(habitRepositoryProvider).exportJson();

  Future<void> _afterBulkChange() async {
    ref.invalidate(onboardingDoneProvider);
    ref.invalidateSelf();
    final views = await future;
    await _guard('Hatırlatmalar iptal edilemedi', () {
      return ref.read(notificationServiceProvider).cancelAll();
    });
    for (final v in views) {
      await _syncReminder(v);
    }
  }

  Future<void> _reloadAndSync(int id) async {
    ref.invalidateSelf();
    final views = await future;
    final view = views.where((v) => v.id == id).firstOrNull;
    if (view != null) await _syncReminder(view);
  }

  Future<void> _syncReminder(HabitView view) => _guard(
    'Hatırlatma planlanamadı',
    () => ref
        .read(notificationServiceProvider)
        .syncHabit(view.habit, notBefore: view.reminderNotBefore),
  );

  /// Bildirim hataları kaydı engellemez (ör. izin yok, test ortamı), ama
  /// sessizce yutulmaz: hata ayıklama çıktısına yazılır.
  static Future<void> _guard(
    String what,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e, st) {
      debugPrint('$what: $e');
      debugPrintStack(stackTrace: st, maxFrames: 5);
    }
  }
}
