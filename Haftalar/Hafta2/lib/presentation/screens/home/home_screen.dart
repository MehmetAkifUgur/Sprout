import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/plant_types.dart';
import '../../providers/habits_provider.dart';
import '../../widgets/plant_widget.dart';
import '../add_habit/add_habit_screen.dart';

/// Hafta 2: liste + placeholder bitki + puan/evre/seri.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Alışkanlıklarım')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Alışkanlık ekle',
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AddHabitScreen())),
        child: const Icon(Icons.add),
      ),
      body: habits.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Veriler yüklenemedi: $e')),
        data: (views) => views.isEmpty
            ? const Center(child: Text('Henüz alışkanlık yok'))
            : ListView.builder(
                itemCount: views.length,
                itemBuilder: (context, i) => _HabitTile(view: views[i]),
              ),
      ),
    );
  }
}

class _HabitTile extends ConsumerWidget {
  const _HabitTile({required this.view});

  final HabitView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final growth = view.growth;
    final notifier = ref.read(habitsProvider.notifier);

    return Dismissible(
      key: ValueKey(view.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => notifier.deleteHabit(view.id),
      child: ListTile(
        leading: PlantWidget(
          score: growth.score,
          type: PlantType.fromName(view.habit.plantType),
          isWilted: growth.isWilted,
        ),
        title: Text(view.habit.name),
        subtitle: Text(
          '${growth.stage.label}${growth.isWilted ? ' (solmuş)' : ''} · '
          '${growth.score.round()} puan · seri ${growth.currentStreak}',
        ),
        trailing: Checkbox(
          value: view.completedToday,
          onChanged: view.dueToday
              ? (_) async {
                  final messenger = ScaffoldMessenger.of(context);
                  final change = await notifier.toggleToday(view.id);
                  if (change == null) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        change.isUp
                            ? '🎉 ${change.habitName} artık bir ${change.to.label}!'
                            : '${change.habitName} ${change.to.label} evresine geriledi.',
                      ),
                    ),
                  );
                }
              : null,
        ),
      ),
    );
  }
}
