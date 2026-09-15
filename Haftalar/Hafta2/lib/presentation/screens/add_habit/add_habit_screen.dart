import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/plant_types.dart';
import '../../../data/models/habit.dart';
import '../../../domain/habit_schedule.dart';
import '../../providers/habits_provider.dart';
import '../../providers/providers.dart';

class AddHabitScreen extends ConsumerStatefulWidget {
  const AddHabitScreen({super.key});

  @override
  ConsumerState<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends ConsumerState<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  TargetFrequency _frequency = TargetFrequency.daily;
  final Set<int> _customDays = {};
  PlantType _plant = PlantType.flower;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_frequency == TargetFrequency.custom && _customDays.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('En az bir gün seç')));
      return;
    }
    final navigator = Navigator.of(context);
    await ref
        .read(habitsProvider.notifier)
        .addHabit(
          Habit(
            name: _name.text.trim(),
            targetFrequency: _frequency,
            customDays: _frequency == TargetFrequency.custom ? _customDays : {},
            createdAt: ref.read(clockProvider)(),
            plantType: _plant.name,
          ),
        );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final dayNames = [
      for (var i = 0; i < 7; i++)
        DateFormat.E().format(DateTime(2024, 1, 1 + i)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni alışkanlık')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Alışkanlık adı'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Bir ad gir' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TargetFrequency>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Sıklık'),
              items: [
                for (final f in TargetFrequency.values)
                  DropdownMenuItem(value: f, child: Text(f.label)),
              ],
              onChanged: (f) => setState(() => _frequency = f!),
            ),
            if (_frequency == TargetFrequency.custom)
              Wrap(
                spacing: 6,
                children: [
                  for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                    FilterChip(
                      label: Text(dayNames[d - 1]),
                      selected: _customDays.contains(d),
                      onSelected: (on) => setState(
                        () => on ? _customDays.add(d) : _customDays.remove(d),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PlantType>(
              initialValue: _plant,
              decoration: const InputDecoration(labelText: 'Bitki'),
              items: [
                for (final t in PlantType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (t) => setState(() => _plant = t!),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Kaydet')),
          ],
        ),
      ),
    );
  }
}
