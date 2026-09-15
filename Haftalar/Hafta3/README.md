# Hafta 3 — Görsel Cila ve Bildirimler

Hafta 2'nin üzerine: demo edilebilir, görsel olarak tatmin edici sürüm.

## Bu haftada eklenenler
- Paketler: `flutter_local_notifications`, `timezone`, `flutter_timezone`, `flutter_localizations`
- `widgets/plant_widget.dart` — CustomPainter ile 4 bitki türü × 5 evre; akıcı büyüme, evre geçişinde zıplama, **solma efekti**
  (Lottie dosyaları hazır olunca bu widget içinde değiştirilebilir)
- Ana ekran **bahçe** görünümü (`HabitCard`, `ProgressRing`)
- `core/theme/app_theme.dart` — açık/koyu tema
- `services/notification_service.dart` — alışkanlık başına günlük hatırlatma
- `screens/habit_detail/` — 6 haftalık geçmiş takvimi (geçmiş gün düzeltme), seri bilgileri, son kayıtlar, düzenle/sil
- Veritabanı şeması **v2** (`reminder_minutes`) — v1'den migration ile, veri kaybı yok
- Android: bildirim izinleri, receiver'lar, core library desugaring

## Testler (30)
- Hafta 2 testleri + `test/data/app_database_test.dart` (v1 → v2 migration)
- `test/app_flow_test.dart` — bahçe, sulama, evre, solma + detay uyarısı, silme

> Android derlemesi için SDK Manager'dan **NDK** kurulu olmalı.

## Çalıştırma

```bash
flutter pub get
flutter test
flutter run
```
