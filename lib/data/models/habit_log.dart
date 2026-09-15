import '../../domain/date_utils.dart';

class HabitLog {
  const HabitLog({
    this.id,
    required this.habitId,
    required this.date,
    required this.completed,
  });

  final int? id;
  final int habitId;

  /// Yalnızca gün bilgisi anlamlıdır (saat 00:00, yerel).
  final DateTime date;
  final bool completed;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'habit_id': habitId,
    'date': dayKey(date),
    'completed': completed ? 1 : 0,
  };

  factory HabitLog.fromMap(Map<String, Object?> map) => HabitLog(
    id: map['id'] as int?,
    habitId: map['habit_id'] as int,
    date: parseDayKey(map['date'] as String),
    completed: map['completed'] == 1,
  );
}
