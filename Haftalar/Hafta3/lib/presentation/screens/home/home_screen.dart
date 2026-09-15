import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/growth_constants.dart';
import '../../providers/habits_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/habit_card.dart';
import '../../widgets/plant_widget.dart';
import '../../../core/constants/plant_types.dart';
import '../../widgets/progress_ring.dart';
import '../add_habit/add_habit_screen.dart';
import '../habit_detail/habit_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bahçem'),
        actions: [
          IconButton(
            tooltip: 'Bildirim iznini ver',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _enableNotifications(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AddHabitScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Tohum ek'),
      ),
      body: habits.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Veriler yüklenemedi: $e')),
        data: (views) =>
            views.isEmpty ? const _EmptyGarden() : _Garden(views: views),
      ),
    );
  }

  Future<void> _enableNotifications(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermission();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          granted ? 'Bildirimler açık 🌱' : 'Bildirim izni verilmedi',
        ),
      ),
    );
  }
}

class _Garden extends ConsumerWidget {
  const _Garden({required this.views});

  final List<HabitView> views;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final due = views.where((v) => v.dueToday).toList();
    final done = due.where((v) => v.completedToday).length;
    final today = DateFormat('d MMMM EEEE').format(DateTime.now());

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ProgressRing(
                      value: due.isEmpty ? 1 : done / due.length,
                      child: Text(
                        '$done/${due.length}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(today, style: theme.textTheme.labelLarge),
                          const SizedBox(height: 4),
                          Text(
                            _headline(done, due.length),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.66,
            ),
            itemCount: views.length,
            itemBuilder: (context, i) {
              final view = views[i];
              return HabitCard(
                key: ValueKey(view.id),
                view: view,
                onToggle: () => toggleAndCelebrate(context, ref, view.id),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HabitDetailScreen(habitId: view.id),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _headline(int done, int total) {
    if (total == 0) return 'Bugün planlı alışkanlık yok. Bahçen dinleniyor.';
    if (done == total) return 'Harika! Bugün tüm bitkilerini suladın 🌿';
    return '${total - done} bitkin bugün su bekliyor.';
  }
}

/// Bugünü işaretler; evre değiştiyse kullanıcıya bildirir.
Future<void> toggleAndCelebrate(
  BuildContext context,
  WidgetRef ref,
  int habitId, {
  DateTime? day,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(habitsProvider.notifier);
  final change = day == null
      ? await notifier.toggleToday(habitId)
      : await notifier.toggleDay(habitId, day);
  if (change == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          change.isUp
              ? '🎉 ${change.habitName} artık bir ${change.to.label}!'
              : '${change.habitName} ${change.to.label} evresine geriledi.',
        ),
      ),
    );
}

class _EmptyGarden extends StatelessWidget {
  const _EmptyGarden();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PlantWidget(score: 0, type: PlantType.flower, size: 160),
            const SizedBox(height: 16),
            Text('Bahçen henüz boş', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'İlk alışkanlığını ekle, ${GrowthStage.seed.label.toLowerCase()} '
              'olarak başlasın. Her gün tamamladıkça büyüsün.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
