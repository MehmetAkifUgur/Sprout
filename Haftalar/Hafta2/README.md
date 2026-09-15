# Hafta 2 — Büyüme Mantığı (Growth Engine)

Hafta 1'in üzerine: alışkanlık tamamlandıkça bitkinin evre değiştirdiği sistem.

## Bu haftada eklenenler
- Paket: `flutter_riverpod`
- `core/constants/growth_constants.dart` — evreler ve tüm eşik değerleri
- `domain/growth_engine.dart` — saf Dart puan/streak/solma algoritması
- `domain/habit_schedule.dart` — günlük / haftalık / belirli günler dönemleri
- Riverpod: `providers.dart`, `habits_provider.dart` (UI artık `setState` değil provider kullanıyor)
- `presentation/widgets/plant_widget.dart` — **placeholder** (emoji) bitki; Hafta 3'te aynı API ile çizime dönüşüyor
- Evre atlanınca kutlama mesajı

## Testler (28)
- `test/domain/growth_engine_test.dart` — 22 test: streak, ihmal, solma, özel gün, haftalık, yaz saati
- Veri katmanı testleri (Hafta 1)
- `test/app_flow_test.dart` — puan kalıcılığı, evre değişimi, solma

## Çalıştırma

```bash
flutter pub get
flutter test
flutter run
```
