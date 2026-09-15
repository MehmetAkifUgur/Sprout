# Bitki Büyüt — Haftalık Gelişim

Her klasör, o haftanın **sonundaki** projenin tam ve tek başına çalışan bir kopyasıdır
(birikimli: Hafta 2 = Hafta 1 + Hafta 2 işleri). Her birini Android Studio'da ayrı proje
olarak açıp `flutter run` ile çalıştırabilirsin.

| Klasör | İçerik | Şema | Test |
|---|---|---|---|
| [Hafta1](Hafta1/README.md) | Veri katmanı + sade liste arayüzü | v1 | 4 |
| [Hafta2](Hafta2/README.md) | + Growth engine, Riverpod, placeholder bitki | v1 | 28 |
| [Hafta3](Hafta3/README.md) | + Bahçe, çizimli/animasyonlu bitki, bildirimler, detay ekranı | v2 | 30 |
| [Hafta4](Hafta4/README.md) | + İstatistik, onboarding, ikon/splash, sıfırlama (final) | v3 | 32 |

Hepsi aynı uygulama kimliğini (`com.example.sprout`) kullanır; aynı cihaza sırayla
kurulduğunda veritabanı migration ile yükseltilir, veriler korunur.
