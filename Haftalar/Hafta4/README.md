# Hafta 4 — İstatistik, Cila ve Sunum Hazırlığı (Final)

Hafta 3'ün üzerine: jüriye sunulabilir final ürün. Ana proje (`StudioProjects/Sprout`) ile aynıdır.

## Bu haftada eklenenler
- Paket: `fl_chart` (dev: `flutter_launcher_icons`)
- `screens/stats/` + `providers/stats_provider.dart` — son 7/30 gün oran grafiği, en uzun seri, alışkanlık bazlı oranlar
- `screens/onboarding/` — 3 sayfalık ilk açılış
- Alt gezinme çubuğu (Bahçe / İstatistik)
- Uygulama ikonu (adaptive) ve splash ekranı — `tool/generate_icon.ps1`, `assets/icon/`
- Kenar durumlar: gün değişiminde yeniden hesaplama (`AppLifecycleListener`), **uygulamayı sıfırla**, boş durumlar
- Veritabanı şeması **v3** (`app_settings`) — migration ile
- Sunum: `docs/MIMARI.md` (mimari şema, algoritma, paket gerekçeleri), `docs/PROJE_PLANI.md`

## Testler (32)
- Tüm önceki testler + onboarding, istatistik ekranı, v1 → v3 migration

## Çalıştırma

```bash
flutter pub get
flutter test
flutter run
```
