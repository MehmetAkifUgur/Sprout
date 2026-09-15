import '../../domain/habit_schedule.dart';

class Habit {
  const Habit({
    this.id,
    required this.name,
    required this.targetFrequency,
    this.customDays = const {},
    required this.createdAt,
    required this.plantType,
    this.growthScore = 0,
  });

  final int? id;
  final String name;
  final TargetFrequency targetFrequency;

  /// [TargetFrequency.custom] için seçili haftanın günleri (DateTime.monday..sunday).
  final Set<int> customDays;
  final DateTime createdAt;
  final String plantType;

  /// Anlık büyüme puanı (0–100). Hesaplama Hafta 2'de eklenecek.
  final double growthScore;

  Habit copyWith({
    int? id,
    String? name,
    TargetFrequency? targetFrequency,
    Set<int>? customDays,
    DateTime? createdAt,
    String? plantType,
    double? growthScore,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      targetFrequency: targetFrequency ?? this.targetFrequency,
      customDays: customDays ?? this.customDays,
      createdAt: createdAt ?? this.createdAt,
      plantType: plantType ?? this.plantType,
      growthScore: growthScore ?? this.growthScore,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'target_frequency': targetFrequency.name,
    'custom_days': (customDays.toList()..sort()).join(','),
    'created_at': createdAt.toIso8601String(),
    'plant_type': plantType,
    'growth_score': growthScore,
  };

  factory Habit.fromMap(Map<String, Object?> map) {
    final days = (map['custom_days'] as String?) ?? '';
    return Habit(
      id: map['id'] as int?,
      name: map['name'] as String,
      targetFrequency: TargetFrequency.values.byName(
        map['target_frequency'] as String,
      ),
      customDays: days.isEmpty ? {} : days.split(',').map(int.parse).toSet(),
      createdAt: DateTime.parse(map['created_at'] as String),
      plantType: map['plant_type'] as String,
      growthScore: (map['growth_score'] as num).toDouble(),
    );
  }
}
