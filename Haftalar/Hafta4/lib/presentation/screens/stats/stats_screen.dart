import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/plant_types.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/plant_widget.dart';
import '../../widgets/progress_ring.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

enum _Range { week, month }

class _StatsScreenState extends ConsumerState<StatsScreen> {
  _Range _range = _Range.week;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('İstatistikler')),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) => data.habits.isEmpty
            ? const Center(
                child: Text('İstatistik için önce bir alışkanlık ekle.'),
              )
            : _content(context, data),
      ),
    );
  }

  Widget _content(BuildContext context, StatsData data) {
    final theme = Theme.of(context);
    final n = _range == _Range.week ? 7 : 30;
    final rate = data.rateFor(n);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Row(
          children: [
            _Summary(
              label: '${n == 7 ? 'Haftalık' : 'Aylık'} oran',
              value: rate == null ? '–' : '%${(rate * 100).round()}',
            ),
            const SizedBox(width: 8),
            _Summary(label: 'En uzun seri', value: '${data.bestStreak}'),
            const SizedBox(width: 8),
            _Summary(label: 'Toplam sulama', value: '${data.totalCompletions}'),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<_Range>(
          segments: const [
            ButtonSegment(value: _Range.week, label: Text('Son 7 gün')),
            ButtonSegment(value: _Range.month, label: Text('Son 30 gün')),
          ],
          selected: {_range},
          onSelectionChanged: (s) => setState(() => _range = s.first),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 12),
                  child: Text(
                    'Günlük tamamlanma oranı',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: _RateChart(days: data.days.sublist(30 - n)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Alışkanlıklar', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final h in data.habits) _HabitStatTile(stat: h, days: n),
      ],
    );
  }
}

class _RateChart extends StatelessWidget {
  const _RateChart({required this.days});

  final List<DayStat> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final short = days.length <= 7;
    final dayFmt = short ? DateFormat.E() : DateFormat('d/M');

    return BarChart(
      BarChartData(
        maxY: 100,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: scheme.outlineVariant, strokeWidth: 0.6),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) {
              final d = days[group.x];
              return BarTooltipItem(
                '${DateFormat('d MMM').format(d.day)}\n'
                '${d.completed}/${d.due}',
                TextStyle(color: scheme.onInverseSurface),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 25,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  '%${v.toInt()}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (!short && i % 5 != 4) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    dayFmt.format(days[i].day),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: (days[i].rate ?? 0) * 100,
                  width: short ? 22 : 6,
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(short ? 6 : 3),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 2),
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

class _HabitStatTile extends StatelessWidget {
  const _HabitStatTile({required this.stat, required this.days});

  final HabitStat stat;
  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = stat.view;
    final rate = days == 7 ? stat.rate7 : stat.rate30;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: PlantWidget(
          score: v.growth.score,
          type: PlantType.fromName(v.habit.plantType),
          isWilted: v.growth.isWilted,
          size: 44,
        ),
        title: Text(v.habit.name),
        subtitle: Text(
          '${v.habit.targetFrequency.label} · seri ${v.growth.currentStreak} · '
          'en uzun ${v.growth.longestStreak}',
        ),
        trailing: ProgressRing(
          value: rate ?? 0,
          size: 44,
          strokeWidth: 5,
          child: Text(
            rate == null ? '–' : '${(rate * 100).round()}',
            style: theme.textTheme.labelSmall,
          ),
        ),
      ),
    );
  }
}
