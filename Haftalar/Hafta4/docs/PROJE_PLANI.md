# Bitki Büyüt: Alışkanlık Takip Uygulaması — Proje Dökümantasyonu

Bu doküman, projenin Claude Code ile geliştirilmesi sırasında referans alınacak
genel yapı, aşamalar ve teknik kararları içerir. Her yeni oturumda bu dosya
okunarak projenin neresinde kalındığı takip edilebilir.

---

## 1. Proje Özeti

**Ad:** Bitki Büyüt (çalışma adı)
**Platform:** Flutter (öncelikli hedef: Android)
**Tip:** Alışkanlık takip uygulaması — gamification mekaniği olarak
her alışkanlık kullanıcının "büyüttüğü" bir sanal bitkiye bağlanır.
Alışkanlık düzenli tamamlanırsa bitki büyür, ihmal edilirse solar.

**Temel felsefe:** Backend'siz, tamamen cihaz üzerinde (offline-first)
çalışan bir mimari. Maliyet sıfır, internet bağımlılığı yok.

---

## 2. Teknoloji Yığını (Tech Stack)

| Katman | Paket / Araç | Amaç |
|---|---|---|
| Dil / Framework | Flutter (Dart) | Cross-platform UI |
| State Management | `flutter_riverpod` | Uygulama durumu yönetimi |
| Local Database | `sqflite` | Alışkanlık ve log verilerinin kalıcı saklanması |
| Tarih işlemleri | `intl` | Tarih formatlama, yerelleştirme |
| Bildirimler | `flutter_local_notifications` | Günlük hatırlatmalar |
| Grafik/İstatistik | `fl_chart` | Haftalık/aylık tamamlanma grafikleri |
| Animasyon | `lottie` | Bitki büyüme animasyonları |
| İkonlar | `flutter_launcher_icons` | Uygulama ikonu üretimi |

> Not: Riverpod, Provider'a göre daha modern ve test edilebilir bir
> alternatif olduğu için tercih edildi; Claude Code paket kurulumunda
> bunu esas alsın.

---

## 3. Klasör / Mimari Yapısı

```
lib/
├── main.dart
├── core/
│   ├── constants/          # Renk paleti, sabitler, growth stage eşikleri
│   └── theme/              # AppTheme (light/dark)
├── data/
│   ├── models/              # Habit, HabitLog modelleri
│   ├── local/                # sqflite DB helper, DAO'lar
│   └── repositories/       # HabitRepository (DB erişimini soyutlar)
├── domain/
│   └── growth_engine.dart  # Büyüme/solma puan hesaplama mantığı (saf Dart, test edilebilir)
├── presentation/
│   ├── screens/
│   │   ├── home/            # Bugünün alışkanlıkları + bahçe görünümü
│   │   ├── add_habit/
│   │   ├── habit_detail/
│   │   └── stats/
│   ├── widgets/             # PlantWidget, HabitCard, ProgressRing vs.
│   └── providers/           # Riverpod provider'ları
└── services/
    └── notification_service.dart
```

**Neden bu yapı:** `domain/growth_engine.dart` katmanı UI'dan ve
veritabanından tamamen bağımsız olacak şekilde tasarlanmalı — bu sayede
büyüme algoritması unit test ile izole test edilebilir.

---

## 4. Veri Modeli

### Habit
| Alan | Tip | Açıklama |
|---|---|---|
| id | int (PK) | |
| name | String | Alışkanlık adı |
| targetFrequency | enum (daily/weekly/custom) | Hedef sıklık |
| createdAt | DateTime | |
| plantType | String | Hangi bitki görseli kullanılacak |
| growthScore | double | Anlık büyüme puanı (0–100) |

### HabitLog
| Alan | Tip | Açıklama |
|---|---|---|
| id | int (PK) | |
| habitId | int (FK) | |
| date | DateTime | |
| completed | bool | |

**Büyüme mantığı (özet):** Her `completed=true` log günlük puanı artırır,
ardışık günler (streak) çarpan etkisi yaratır; N gün ihmal `growthScore`'u
düşürmeye başlar. Eşik değerler `core/constants` içinde tutulur, böylece
dengeleme (balancing) kolay değiştirilebilir.

---

## 5. Bitki Büyüme Evreleri

1. Tohum (0–20 puan)
2. Filiz (21–45 puan)
3. Fidan (46–70 puan)
4. Çiçek/Meyve (71–90 puan)
5. Tam Büyümüş (91–100 puan)
6. Solmuş durum — herhangi bir evrede N gün ihmal sonrası ayrı bir görsel/renk tonu

---

## 6. Geliştirme Aşamaları (4 Hafta)

### Hafta 1 — Temel Yapı ve Veri Katmanı
- [x] Flutter projesi kurulumu, paketlerin eklenmesi (`pubspec.yaml`)
- [x] Klasör mimarisinin oluşturulması (bkz. Bölüm 3)
- [x] `Habit` ve `HabitLog` modellerinin yazılması
- [x] `sqflite` bağlantısı ve DAO'lar (create/read/update/delete)
- [x] Alışkanlık ekleme/silme/listeleme — sade UI, tasarım önemsiz
- [x] Kalıcılık testi: uygulama kapatılıp açıldığında veri duruyor mu?
  > Otomatik test: `test/app_flow_test.dart`. Cihazda elle doğrulanmalı.

**Çıktı:** Veri kaybetmeyen, işlevsel ama çıplak bir uygulama.

### Hafta 2 — Büyüme Mantığı (Growth Engine)
- [x] Büyüme evrelerinin ve eşik değerlerinin `constants` içinde tanımlanması
- [x] `growth_engine.dart`: puan artırma/azaltma algoritması (saf fonksiyon, DB'den bağımsız)
- [x] Unit testler: streak senaryoları, ihmal senaryoları
- [x] Riverpod provider'ları ile UI'a bağlama
- [x] Statik PNG/placeholder görsellerle evre geçişlerinin test edilmesi

**Çıktı:** Alışkanlık tamamlandıkça bitkinin (görsel olarak basit de olsa) evre değiştirdiği bir sistem.

### Hafta 3 — Görsel Cila ve Bildirimler
- [~] Lottie animasyonlarının entegrasyonu (evreler arası geçiş animasyonu)
  > Şimdilik `PlantWidget` (CustomPainter) ile puana göre akıcı büyüme, evre
  > geçişinde zıplama ve solma animasyonu var. Lottie JSON dosyaları hazır
  > olunca `lottie` paketi eklenip `PlantWidget` içinde değiştirilebilir.
- [x] Ana ekran: "bahçe" görünümü — her alışkanlığın kendi bitkisi
- [x] `flutter_local_notifications` kurulumu ve günlük hatırlatma
- [x] Solma (ihmal) görsel efektinin uygulanması
- [x] Habit detail ekranı (geçmiş log'ların görüntülenmesi)

**Çıktı:** Demo edilebilir, görsel olarak tatmin edici versiyon.

### Hafta 4 — İstatistik, Cila ve Sunum Hazırlığı
- [x] `fl_chart` ile istatistik ekranı (haftalık/aylık oran, en uzun streak)
- [x] Onboarding / ilk açılış ekranı
- [x] Uygulama ikonu ve splash screen
- [x] Kenar durum testleri (tarih değişimi, uygulama sıfırlama, boş liste vs.)
- [x] Kod temizliği, isimlendirme tutarlılığı
- [~] Sunum materyali: mimari şema, paket listesi ve seçim gerekçeleri, kısa demo videosu
  > Mimari şema ve paket gerekçeleri: `docs/MIMARI.md`. Demo videosu cihazda çekilmeli.

**Çıktı:** Jüriye sunulabilir final ürün.

---

## 7. Claude Code için Çalışma Notları

- Her aşamaya başlamadan önce ilgili haftanın checklist'ini bu dosyadan oku,
  tamamlanan maddeleri işaretleyerek ilerle.
- `domain/growth_engine.dart` UI ve DB katmanlarından bağımsız kalmalı;
  değişiklik yaparken bu sınırı bozma.
- Yeni bir paket eklemeden önce Bölüm 2'deki listeyi kontrol et, gereksiz
  bağımlılık ekleme (proje bilinçli olarak backend'siz/hafif tutuluyor).
- Görsel/animasyon işlerinde önce placeholder ile mantığı doğrula, sonra
  Lottie/SVG ile cilala (Hafta 1–2'de tasarıma zaman harcama).
- Test edilebilirlik önceliklidir: büyüme algoritması gibi iş mantığı
  fonksiyonları saf Dart fonksiyonları olarak yazılmalı.

---

## 8. Kapsam Dışı (Bilinçli Olarak Eklenmeyenler)

- Firebase / bulut senkronizasyonu (proje offline-first)
- Kullanıcı hesap sistemi / login
- iOS build (opsiyonel, zaman kalırsa değerlendirilir)
- Sosyal özellikler (arkadaş ekleme, paylaşım vb.)

Bu maddeler ileride "gelecek geliştirmeler" bölümünde sunumda bahsedilebilir
ama mevcut 4 haftalık kapsamın dışındadır.
