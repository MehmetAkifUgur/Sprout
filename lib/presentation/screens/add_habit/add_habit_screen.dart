import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/plant_types.dart';
import '../../../data/models/habit.dart';
import '../../../domain/date_utils.dart';
import '../../../domain/habit_schedule.dart';
import '../../providers/habits_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/plant_widget.dart';

/// Yeni alışkanlık ekler; [existing] verilirse düzenler.
class AddHabitScreen extends ConsumerStatefulWidget {
  const AddHabitScreen({super.key, this.existing});

  final Habit? existing;

  @override
  ConsumerState<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends ConsumerState<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late TargetFrequency _frequency;
  late Set<int> _customDays;
  late PlantType _plant;
  TimeOfDay? _reminder;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _frequency = e?.targetFrequency ?? TargetFrequency.daily;
    _customDays = {...?e?.customDays};
    _plant = e == null ? PlantType.flower : PlantType.fromName(e.plantType);
    final m = e?.reminderMinutes;
    _reminder = m == null ? null : TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayNames = weekdayLabelsMonFirst;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Alışkanlığı düzenle' : 'Yeni alışkanlık'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Alışkanlık adı',
                hintText: 'Örn. 20 sayfa kitap oku',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Bir ad gir' : null,
            ),
            const SizedBox(height: 12),
            Text('Sıklık', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<TargetFrequency>(
              segments: [
                for (final f in TargetFrequency.values)
                  ButtonSegment(value: f, label: Text(f.label)),
              ],
              selected: {_frequency},
              onSelectionChanged: (s) => setState(() => _frequency = s.first),
            ),
            if (_frequency == TargetFrequency.custom) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
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
            ],
            const SizedBox(height: 20),
            Text('Bitki', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: PlantType.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final type = PlantType.values[i];
                  final selected = type == _plant;
                  return ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _plant = type),
                    label: Column(
                      children: [
                        PlantWidget(score: 100, type: type, size: 76),
                        const SizedBox(height: 4),
                        Text(type.label),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: SwitchListTile(
                title: const Text('Günlük hatırlatma'),
                subtitle: Text(
                  _reminder == null
                      ? 'Kapalı'
                      : 'Her gün ${_reminder!.format(context)}',
                ),
                value: _reminder != null,
                onChanged: (on) async {
                  if (!on) return setState(() => _reminder = null);
                  await _pickTime();
                },
              ),
            ),
            if (_reminder != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule),
                  label: const Text('Saati değiştir'),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(_isEdit ? 'Kaydet' : 'Tohumu ek'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _reminder ?? const TimeOfDay(hour: 20, minute: 0),
    );
    if (t == null) return;
    setState(() => _reminder = t);
    await ref
        .read(notificationServiceProvider)
        .requestPermission()
        .catchError((_) => false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_frequency == TargetFrequency.custom && _customDays.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('En az bir gün seç')));
      return;
    }
    setState(() => _saving = true);

    final reminder = _reminder == null
        ? null
        : _reminder!.hour * 60 + _reminder!.minute;
    final notifier = ref.read(habitsProvider.notifier);
    final navigator = Navigator.of(context);
    final e = widget.existing;

    if (e == null) {
      await notifier.addHabit(
        Habit(
          name: _name.text.trim(),
          targetFrequency: _frequency,
          customDays: _frequency == TargetFrequency.custom ? _customDays : {},
          createdAt: ref.read(clockProvider)(),
          plantType: _plant.name,
          reminderMinutes: reminder,
        ),
      );
    } else {
      await notifier.updateHabit(
        e.copyWith(
          name: _name.text.trim(),
          targetFrequency: _frequency,
          customDays: _frequency == TargetFrequency.custom ? _customDays : {},
          plantType: _plant.name,
          reminderMinutes: () => reminder,
        ),
      );
    }
    navigator.pop();
  }
}
