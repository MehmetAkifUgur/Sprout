import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/growth_constants.dart';
import '../../../core/constants/plant_types.dart';
import '../../providers/habits_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/habit_card.dart';
import '../../widgets/plant_widget.dart';
import '../../widgets/progress_ring.dart';
import '../add_habit/add_habit_screen.dart';
import '../habit_detail/habit_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final hasBackup = ref.watch(resetBackupAvailableProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bahçem'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'notify' => _enableNotifications(context, ref),
              'export' => _export(context, ref),
              'import' => _import(context, ref),
              'restore' => _restore(context, ref),
              'reset' => _confirmReset(context, ref),
              _ => null,
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'notify',
                child: Text('Bildirim iznini ver'),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Text('Yedeği dışa aktar'),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Text('Yedeği içe aktar'),
              ),
              if (hasBackup)
                const PopupMenuItem(
                  value: 'restore',
                  child: Text('Sıfırlamayı geri al'),
                ),
              const PopupMenuItem(
                value: 'reset',
                child: Text('Uygulamayı sıfırla'),
              ),
            ],
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

  /// Tüm veriyi bir JSON dosyasına yazar. Konumu kullanıcı sistemin kendi
  /// dosya ekranında seçer (Android'de Storage Access Framework); uygulama
  /// hiçbir depolama izni istemez.
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final json = await ref.read(habitsProvider.notifier).exportJson();
    final day = DateFormat('yyyy-MM-dd').format(ref.read(clockProvider)());
    try {
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Yedeği kaydet',
        fileName: 'sprout-yedek-$day.json',
        bytes: utf8.encode(json),
        mimeType: 'application/json',
      );
      if (saved == null) return; // Kullanıcı vazgeçti.
      messenger.showSnackBar(
        const SnackBar(content: Text('Yedek kaydedildi 🌱')),
      );
    } on Exception catch (e) {
      debugPrint('Yedek kaydedilemedi: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('Yedek kaydedilemedi.')),
      );
    }
  }

  /// Sistem dosya seçicisinden bir yedek dosyası alıp içe aktarır.
  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final String json;
    try {
      // Android'de .json için güvenilir bir MIME türü yok; her dosya
      // seçilebilir, içerik aşağıda doğrulanır.
      final file = await FilePicker.pickFile(dialogTitle: 'Yedek dosyası seç');
      if (file == null) return;
      if ((await file.length() ?? 0) > _maxBackupBytes) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Bu dosya bir yedek için çok büyük.')),
        );
        return;
      }
      json = utf8.decode(await file.readAsBytes());
    } on Exception catch (e) {
      debugPrint('Yedek okunamadı: $e');
      messenger.showSnackBar(const SnackBar(content: Text('Dosya okunamadı.')));
      return;
    }
    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedek geri yüklensin mi?'),
        content: const Text(
          'Yedekteki alışkanlıklar şu anki bahçenin yerini alır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Geri yükle'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final count = await ref.read(habitsProvider.notifier).importJson(json);
      messenger.showSnackBar(
        SnackBar(content: Text('$count alışkanlık geri yüklendi 🌱')),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Yıllarca kayıt bile birkaç yüz KB tutar; bunun üstü yanlış dosyadır.
  static const _maxBackupBytes = 5 * 1024 * 1024;

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sıfırlama geri alınsın mı?'),
        content: const Text(
          'Son sıfırlamadan önceki bahçen geri gelir. Şu anki alışkanlıkların '
          'yerini alır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Geri yükle'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(habitsProvider.notifier).restoreResetBackup();
    messenger.showSnackBar(
      const SnackBar(content: Text('Bahçen geri geldi 🌿')),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uygulama sıfırlansın mı?'),
        content: const Text(
          'Tüm alışkanlıklar, geçmiş kayıtlar ve bitkiler silinir. Fikrini '
          'değiştirirsen menüden "Sıfırlamayı geri al" ile geri getirebilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(habitsProvider.notifier).resetAll();
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
    final today = DateFormat('d MMMM EEEE').format(ref.watch(clockProvider)());

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

/// Günü işaretler; sonucu "Geri al" seçeneğiyle gösterir, evre değiştiyse
/// kutlar ya da uyarır.
Future<void> toggleAndCelebrate(
  BuildContext context,
  WidgetRef ref,
  int habitId, {
  DateTime? day,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(habitsProvider.notifier);
  final target = day ?? ref.read(clockProvider)();
  final result = await notifier.toggleDay(habitId, target);
  if (result == null) return;

  final change = result.stageChange;
  if (change != null && change.isUp) {
    unawaited(HapticFeedback.heavyImpact());
  } else {
    unawaited(HapticFeedback.selectionClick());
  }

  final name = result.habitName;
  final String message;
  if (change != null) {
    message = change.isUp
        ? '🎉 $name artık bir ${change.to.label}!'
        : '$name ${change.to.label} evresine geriledi.';
  } else {
    message = result.completed
        ? '$name sulandı 💧'
        : '$name işareti kaldırıldı';
  }

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Geri al',
          onPressed: () => notifier.toggleDay(habitId, target),
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
