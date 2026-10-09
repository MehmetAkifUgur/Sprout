import 'package:flutter/material.dart';

import '../../core/constants/plant_types.dart';
import '../../domain/habit_schedule.dart';
import '../providers/habits_provider.dart';
import 'plant_widget.dart';

/// Bahçedeki tek bir saksı: bitki, ad, streak ve bugünkü tamamlama düğmesi.
class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.view,
    required this.onToggle,
    required this.onTap,
  });

  final HabitView view;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final habit = view.habit;
    final canToggle = view.canToggleToday;
    final done = view.completedToday;
    final weekly = habit.targetFrequency == TargetFrequency.weekly;

    final String status;
    if (view.pausedToday) {
      status = 'Tatilde 🌴';
    } else if (view.growth.isWilted) {
      status = 'Soluyor! ${view.growth.missedInARow} kez kaçırıldı';
    } else if (!canToggle) {
      status = 'Bugün planlı değil';
    } else if (weekly && view.doneThisPeriod && !done) {
      status = 'Bu hafta tamamlandı';
    } else if (weekly && habit.timesPerWeek > 1) {
      status =
          'Bu hafta ${view.completionsThisWeek}/${habit.timesPerWeek} · '
          '🔥 ${view.growth.currentStreak}';
    } else {
      status = '${view.stage.label} · 🔥 ${view.growth.currentStreak}';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            children: [
              Expanded(
                child: Semantics(
                  label:
                      '${habit.name}. $status. '
                      '${done ? 'Bugün tamamlandı' : 'Bugün tamamlanmadı'}. '
                      'Ayrıntılar için dokun.',
                  excludeSemantics: true,
                  child: Hero(
                    tag: 'plant-${view.id}',
                    child: LayoutBuilder(
                      builder: (context, c) => PlantWidget(
                        score: view.growth.score,
                        type: PlantType.fromName(habit.plantType),
                        isWilted: view.growth.isWilted,
                        size: c.biggest.shortestSide,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                habit.name,
                semanticsLabel: '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                status,
                semanticsLabel: '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: view.growth.isWilted
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: done
                    ? FilledButton.icon(
                        onPressed: onToggle,
                        icon: const Icon(Icons.check_circle),
                        label: Text(
                          'Tamamlandı',
                          semanticsLabel: '${habit.name}: tamamlandı, geri al',
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: canToggle ? onToggle : null,
                        icon: const Icon(Icons.water_drop_outlined),
                        label: Text(
                          'Sula',
                          semanticsLabel: '${habit.name}: sula',
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
