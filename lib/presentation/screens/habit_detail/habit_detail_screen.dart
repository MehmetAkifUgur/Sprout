import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/growth_constants.dart';
import '../../../core/constants/plant_types.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/date_utils.dart';
import '../../../domain/growth_engine.dart';
import '../../../domain/habit_schedule.dart';
import '../../providers/habits_provider.dart';
import '../../widgets/plant_widget.dart';
import '../add_habit/add_habit_screen.dart';
import '../home/home_screen.dart';

class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final int habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref
        .watch(habitsProvider)
        .value
        ?.where((v) => v.id == habitId)
        .firstOrNull;

    if (view == null) {
      return Scaffold(appBar: AppBar());
    }

    final theme = Theme.of(context);
    final habit = view.habit;
    final growth = view.growth;
    final rate30 = GrowthEngine.completionRate(
      schedule: habit.schedule,
      completedDays: view.completedDays,
      from: addDays(view.today, -29),
      to: view.today,
      today: view.today,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name),
        actions: [
          IconButton(
            tooltip: 'Düzenle',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddHabitScreen(existing: habit),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Sil',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref, view),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Center(
            child: Hero(
              tag: 'plant-${view.id}',
              child: PlantWidget(
                score: growth.score,
                type: PlantType.fromName(habit.plantType),
                isWilted: growth.isWilted,
                size: 220,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              growth.isWilted
                  ? '${growth.stage.label} · solmuş'
                  : growth.stage.label,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: growth.isWilted ? AppColors.wilted : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _StageBar(score: growth.score),
          if (growth.isWilted) ...[
            const SizedBox(height: 12),
            Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.local_florist_outlined),
                title: const Text('Bitkin soluyor'),
                subtitle: Text(
                  'Son ${growth.missedInARow} dönemi kaçırdın. '
                  'Bugün tamamlayarak canlandır!',
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _StatTile(
                label: 'Güncel seri',
                value: '${growth.currentStreak}',
                icon: Icons.local_fire_department_outlined,
              ),
              const SizedBox(width: 8),
              _StatTile(
                label: 'En uzun seri',
                value: '${growth.longestStreak}',
                icon: Icons.emoji_events_outlined,
              ),
              const SizedBox(width: 8),
              _StatTile(
                label: 'Son 30 gün',
                value: rate30 == null ? '–' : '%${(rate30 * 100).round()}',
                icon: Icons.insights_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Geçmiş', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${habit.targetFrequency.label} · '
            'Geçmiş bir günü düzeltmek için üzerine dokun.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _HistoryCalendar(
            view: view,
            onToggle: (day) =>
                toggleAndCelebrate(context, ref, view.id, day: day),
          ),
          const SizedBox(height: 20),
          Text('Son kayıtlar', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          ..._recentLogs(view, theme),
        ],
      ),
    );
  }

  List<Widget> _recentLogs(HabitView view, ThemeData theme) {
    final days = view.completedDays.toList()..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Henüz kayıt yok.', style: theme.textTheme.bodyMedium),
        ),
      ];
    }
    final fmt = DateFormat('d MMMM y, EEEE');
    return [
      for (final d in days.take(10))
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.check_circle, color: AppColors.leaf),
          title: Text(fmt.format(d)),
        ),
    ];
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    HabitView view,
  ) async {
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('"${view.habit.name}" silinsin mi?'),
        content: const Text('Bitki ve tüm geçmiş kayıtlar silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    navigator.pop();
    await ref.read(habitsProvider.notifier).deleteHabit(view.id);
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stage = GrowthStage.fromScore(score);
    final isLast = stage == GrowthStage.grown;
    final next = isLast ? null : GrowthStage.values[stage.index + 1];
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: score / 100),
            duration: const Duration(milliseconds: 600),
            builder: (context, v, _) =>
                LinearProgressIndicator(value: v, minHeight: 10),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          next == null
              ? '${score.round()} / 100 puan · en üst evre'
              : '${score.round()} / 100 puan · '
                    '${next.label} için ${next.minScore - score.round()} puan',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Son 6 haftanın gün gün görünümü (Pazartesi başlangıçlı).
class _HistoryCalendar extends StatelessWidget {
  const _HistoryCalendar({required this.view, required this.onToggle});

  final HabitView view;
  final ValueChanged<DateTime> onToggle;

  static const _weeks = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = view.today;
    final start = addDays(today, -(today.weekday - 1) - 7 * (_weeks - 1));
    final created = dateOnly(view.habit.createdAt);
    final schedule = view.habit.schedule;
    final weekly = view.habit.targetFrequency == TargetFrequency.weekly;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                for (final label in weekdayLabelsMonFirst)
                  Expanded(
                    child: Center(
                      child: Text(label, style: theme.textTheme.labelSmall),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var w = 0; w < _weeks; w++)
              Row(
                children: [
                  for (var d = 0; d < 7; d++)
                    Expanded(
                      child: _cell(
                        context,
                        addDays(start, w * 7 + d),
                        today: today,
                        created: created,
                        schedule: schedule,
                        weekly: weekly,
                        scheme: scheme,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime day, {
    required DateTime today,
    required DateTime created,
    required HabitSchedule schedule,
    required bool weekly,
    required ColorScheme scheme,
  }) {
    final inRange = !day.isAfter(today) && !day.isBefore(created);
    final done = view.completedDays.contains(day);
    final due = schedule.isDueOn(day);
    final missed = inRange && !done && due && !weekly && day != today;

    final Color bg;
    final Color fg;
    if (done) {
      bg = AppColors.leaf;
      fg = Colors.white;
    } else if (missed) {
      bg = AppColors.missed.withValues(alpha: 0.25);
      fg = scheme.onSurface;
    } else {
      bg = Colors.transparent;
      fg = inRange && due
          ? scheme.onSurface
          : scheme.onSurface.withValues(alpha: 0.3);
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: bg,
          shape: CircleBorder(
            side: day == today
                ? BorderSide(color: scheme.primary, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: inRange ? () => onToggle(day) : null,
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(color: fg, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
