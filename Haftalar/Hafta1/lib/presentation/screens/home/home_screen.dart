import 'package:flutter/material.dart';

import '../../../core/constants/plant_types.dart';
import '../../../data/models/habit.dart';
import '../../../data/repositories/habit_repository.dart';
import '../../../domain/date_utils.dart';
import '../add_habit/add_habit_screen.dart';

/// Hafta 1: sade liste. Ekle / bugünü işaretle / sil.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository, required this.clock});

  final HabitRepository repository;
  final DateTime Function() clock;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Habit> _habits = [];
  Map<int, Set<DateTime>> _completed = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final habits = await widget.repository.getHabits();
    final completed = await widget.repository.getAllCompletedDays();
    if (!mounted) return;
    setState(() {
      _habits = habits;
      _completed = completed;
      _loading = false;
    });
  }

  Future<void> _toggleToday(Habit habit) async {
    final today = dateOnly(widget.clock());
    final done = _completed[habit.id]?.contains(today) ?? false;
    await widget.repository.setCompleted(habit.id!, today, !done);
    await _load();
  }

  Future<void> _delete(Habit habit) async {
    await widget.repository.deleteHabit(habit.id!);
    await _load();
  }

  Future<void> _add() async {
    final habit = await Navigator.of(context).push<Habit>(
      MaterialPageRoute(builder: (_) => AddHabitScreen(clock: widget.clock)),
    );
    if (habit == null) return;
    await widget.repository.addHabit(habit);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(widget.clock());
    return Scaffold(
      appBar: AppBar(title: const Text('Alışkanlıklarım')),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: 'Alışkanlık ekle',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _habits.isEmpty
          ? const Center(child: Text('Henüz alışkanlık yok'))
          : ListView.builder(
              itemCount: _habits.length,
              itemBuilder: (context, i) {
                final habit = _habits[i];
                final days = _completed[habit.id] ?? {};
                return Dismissible(
                  key: ValueKey(habit.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _delete(habit),
                  child: CheckboxListTile(
                    title: Text(habit.name),
                    subtitle: Text(
                      '${habit.targetFrequency.label} · '
                      '${PlantType.fromName(habit.plantType).label} · '
                      '${days.length} kez tamamlandı',
                    ),
                    value: days.contains(today),
                    onChanged: (_) => _toggleToday(habit),
                  ),
                );
              },
            ),
    );
  }
}
