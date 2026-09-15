import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/plant_types.dart';
import '../../providers/providers.dart';
import '../../widgets/plant_widget.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      score: 10.0,
      wilted: false,
      title: 'Her alışkanlık bir tohum',
      body: 'Edinmek istediğin her alışkanlık için bahçene yeni bir bitki ek.',
    ),
    (
      score: 80.0,
      wilted: false,
      title: 'Tamamladıkça büyür',
      body:
          'Her gün alışkanlığını tamamlayarak bitkini sula. Seri yaptıkça daha '
          'hızlı büyür: tohum, filiz, fidan, çiçek...',
    ),
    (
      score: 55.0,
      wilted: true,
      title: 'İhmal edersen solar',
      body:
          'Birkaç gün üst üste unutursan bitkin solmaya başlar. Merak etme, '
          'tekrar sularsan canlanır.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(habitRepositoryProvider).setOnboardingDone();
    try {
      await ref.read(notificationServiceProvider).requestPermission();
    } catch (_) {}
    ref.invalidate(onboardingDoneProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _page == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: const Text('Geç')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PlantWidget(
                          score: p.score,
                          isWilted: p.wilted,
                          type: PlantType.flower,
                          size: 240,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          p.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.all(4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: last
                    ? _finish
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                child: Text(last ? 'Bahçemi oluştur' : 'Devam'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
