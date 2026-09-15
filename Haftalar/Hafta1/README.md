# Hafta 1 — Temel Yapı ve Veri Katmanı

Veri kaybetmeyen, işlevsel ama çıplak bir uygulama.

## Bu haftada yapılanlar
- Paketler: `sqflite`, `path`, `intl` (test: `sqflite_common_ffi`)
- Klasör mimarisi (`core/`, `data/`, `domain/`, `presentation/`)
- `Habit` ve `HabitLog` modelleri
- `AppDatabase` (şema **v1**), `HabitDao`, `HabitLogDao`, `HabitRepository`
- Sade liste arayüzü: ekle, bugünü işaretle (checkbox), sola kaydırarak sil
- Durum yönetimi bilinçli olarak `setState` (Riverpod Hafta 2'de)

## Testler (4)
- `test/data/habit_repository_test.dart` — CRUD, gün başına tek log, cascade silme
- `test/app_flow_test.dart` — ekle → işaretle → **kapat/aç (kalıcılık)** → sil

## Çalıştırma

```bash
flutter pub get
flutter test
flutter run
```
