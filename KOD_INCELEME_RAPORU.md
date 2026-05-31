# Better Life — Kod İnceleme Raporu

> Tarih: 31 Mayıs 2026 · Kapsam: `lib/`, `supabase/functions/`, `assets/translations/`, `pubspec.yaml`, config
> Amaç: Mevcut durumla proje spec'i (`BETTER_LIFE_FULL_PROMPT.md`) arasındaki farkları ve eksikleri tek tek listelemek. **Bu rapor sadece tespittir; hiçbir değişiklik yapılmadı.**

---

## Özet (TL;DR)

Projede aslında **birbiriyle konuşmayan üç ayrı katman** var:

1. **Canlı çalışan UI** → Sadece **sigara**ya özel bir sayaç + tasarruf + akciğer skoru. Veriyi `profiles` tablosu + `SharedPreferences` ile tutuyor.
2. **`habit_repository.dart`** (797 satır) → Spec'teki gelişmiş çok-alışkanlıklı "HabitArena" sistemi (habits, program_type, daily_logs, combo, milestone, RPC'ler). **Hiçbir ekran tarafından kullanılmıyor — tamamen ölü kod.**
3. **Edge Functions** (Gemini + pgvector) → `habit_repository` dışında hiçbir yerden çağrılmıyor; yazdığı tablolar için migration yok.

Yani backend tasarımı (spec) ile ekranlar (Alp'in UI'ı) **entegre edilmemiş**. UI güzel ve tutarlı (yeşil palet), ama spec'in vaat ettiği özelliklerin çoğu UI'da yok.

Bulgular önem sırasına göre aşağıda. Her bulgunun yanında **[Önem]** ve önerilen çözüm var.

---

## A. Mimari Kopukluklar (KRİTİK)

### A1. `habit_repository.dart` tamamen ölü kod  `[Kritik]`
- **Nerede:** `lib/services/habit_repository.dart` (797 satır)
- **Durum:** `HabitRepository` sınıfı, 12 model sınıfı ve `ProgramType` enum'u tanımlı ama `grep` ile baktığımda dosyanın kendisi dışında **hiçbir yerde import/kullanım yok.**
- **Etki:** Spec'in kalbi olan çok-alışkanlıklı sistem, puanlama, combo, dashboard, leaderboard RPC'leri yazılmış ama bağlanmamış. Derlemeye dahil ama çalışmaya değil.
- **Öneri:** Ya bağlayalım (büyük iş), ya da ders sunumunda karışıklık yaratmaması için arşivleyelim. Karar size ait.

### A2. `supabase_service.dart` boş dosya (0 byte)  `[Orta]`
- **Nerede:** `lib/services/supabase_service.dart`
- **Durum:** Spec'te ana servis katmanı olarak geçiyor ama dosya tamamen boş, kimse kullanmıyor.
- **Öneri:** Silinmeli (kafa karıştırıcı).

### A3. Uygulama sadece sigaraya özel, oysa konsept çok-alışkanlık  `[Kritik]`
- **Nerede:** `home_screen.dart`, `lungs_screen.dart`
- **Durum:** Onboarding'de Alkol / Junk Food / Screen Time / "Other" seçilebiliyor (`habit_selection_screen.dart`), ama ana ekran **paket fiyatı, paket adedi, günlük sigara sayısı, ₺ tasarruf ve akciğer skoru** üzerine kurulu. Alkolü bırakmak isteyen biri bile "kaç sigara içtin?" sayacı ve akciğer ekranı görüyor.
- **Kanıt:** `home_screen.dart` içinde `habit.toLowerCase().contains('cigarette')` kontrolleri; sigara değilse tasarruf kartı hiç görünmüyor, geriye sadece çıplak bir sayaç kalıyor.
- **Öneri:** En azından metinleri/etiketleri seçilen alışkanlığa göre genelleştirmek; akciğer ekranını sigaraya özel olduğu için koşullu göstermek.

### A4. Veritabanı şeması repoda yok (migration eksik)  `[Kritik]`
- **Nerede:** `supabase/` altında `functions/` var ama `migrations/` **yok.** Hiçbir `.sql` dosyası bulunamadı.
- **Durum:** `profiles` kolonları (habit, goal, quit_date, total_saved, lung_score, pack_price, pack_size, daily_baseline, avatar_url), `friendships`, edge function'ların yazdığı `habits` / `habit_embeddings` tabloları, RPC'ler ve RLS politikaları **hiçbir yerde versiyonlanmamış.**
- **Etki:** Projeyi başka biri klonlasa DB'yi kuramaz. Hocaya "şema nerede?" sorusuna cevap yok. Spec'in bahsettiği `001_initial_schema.sql` mevcut değil.
- **Öneri:** Canlı şemadan bir `001_initial_schema.sql` çıkarıp repoya ekleyelim.

### A5. Edge Functions yetim (orphaned)  `[Yüksek]`
- **Nerede:** `supabase/functions/{search-similar-habit, calculate-daily-score, check-combo-bonus}`
- **Durum:** `habits`, `habit_embeddings` tablolarına ve `match_habit_by_embedding` RPC'sine bağımlılar; bunların migration'ı yok. Flutter tarafında sadece ölü `habit_repository` çağırıyor.
- **Ek:** `search-similar-habit` modeli `gemini-2.5-flash-preview-05-20` kullanıyor, spec ise `gemini-2.0-flash` diyor — tutarsızlık. Spec'teki 4. fonksiyon `generate-seed-embeddings` hiç yok.
- **Öneri:** Şimdilik kapsam dışı bırakmanızı öneririm (ders için fazla karmaşık). İsterseniz sadece belgeleyelim.

---

## B. i18n / Çoklu Dil (İşlevsiz İskele)

### B1. `easy_localization` yok, `.tr()` hiç kullanılmıyor  `[Yüksek]`
- **Durum:** `pubspec.yaml` bağımlılıkları sadece `supabase_flutter`, `shared_preferences`, `image_picker`. `easy_localization` **yok.** `.tr()` çağrıları sadece `habit_repository.dart` yorumlarında geçiyor.
- **Sonuç:** Çeviri sistemi hiç kurulmamış.

### B2. Çeviri dosyaları asset olarak tanımlı değil  `[Yüksek]`
- **Nerede:** `pubspec.yaml` → `assets:` bölümü **tamamen yorum satırı.** `assets/translations/` klasörü uygulamaya gömülmüyor.
- **Ek:** `es.json` boş (0 byte). `tr.json`/`en.json` ise canlı UI'a değil, ölü `habit_repository` modeline göre yazılmış (program_types, combo, scoring vb.).

### B3. Tüm UI metinleri hardcoded İngilizce  `[Orta]`
- **Durum:** "Daily Check-In", "Cigarette Info", "WELCOME BACK", "TOTAL SAVED" vb. doğrudan koda gömülü. Kod yorumları Türkçe, arayüz İngilizce — tutarsız.
- **Öneri:** Ya tam `easy_localization` kuralım, ya da dili tek bir yere (sabitler dosyası) toplayalım. Ders için ikincisi daha basit ve savunması kolay.

---

## C. UI / Tema Tutarlılığı (Sizin özellikle önem verdiğiniz konu)

### C1. Onboarding ekranları temayı hiç kullanmıyor — kırmızı vurgu  `[Yüksek]`
- **Nerede:** `habit_selection_screen.dart`, `goal_selection_screen.dart`, `username_selection_screen.dart`
- **Durum:** Bu üç ekran `Colors.white` arka plan, `Colors.black87` metin ve **`Colors.red`** vurgu kullanıyor. Uygulamanın geri kalanı yeşil palet (`#22C55E` / `#16A34A`) ve `context.appAccent` extension'ı kullanıyor.
- **Etki:** Tema paletinden açıkça çıkılmış; dark mode bu ekranlarda hiç çalışmıyor (her zaman beyaz). Giriş akışı uygulamanın geri kalanından kopuk görünüyor.
- **Öneri:** Bu ekranları `app_theme.dart` paletine taşımak (kırmızı → yeşil accent, beyaz/siyah → `context.appBg/appText`). **Net bir kazanım, düşük risk.**

### C2. AuthGate yükleme ekranı sabit beyaz + siyah spinner  `[Düşük]`
- **Nerede:** `auth_gate.dart` (`backgroundColor: Colors.white`, `CircularProgressIndicator(color: Colors.black)`)
- **Öneri:** Temaya uygun (`context.appBg` + yeşil spinner) hale getirmek.

### C3. Artık (dead) BoxDecoration kalıntıları  `[Kozmetik]`
- **Nerede:** `friends_screen.dart` ve `settings_screen.dart` içinde boş satırlı, içi boşaltılmış `decoration: BoxDecoration( ... )` blokları (kaldırılmış border'lardan kalma).
- **Öneri:** Temizlik.

---

## D. Ölü / Placeholder Kod

### D1. `DummyNextScreen` ve `DummyFinalScreen`  `[Düşük]`
- **Nerede:** `habit_selection_screen.dart` (satır ~210), `goal_selection_screen.dart` (satır ~222)
- **Durum:** "Harika! Bir sonraki sayfaya geçtin" yazan geçici test widget'ları hâlâ duruyor, kullanılmıyor.
- **Öneri:** Silinmeli.

---

## E. Konsepte Göre Fonksiyonel Boşluklar

### E1. Leaderboard / rekabet yok  `[Yüksek]`
- **Durum:** Projenin ana fikri "arkadaşlar arası rekabet / sıralama". `friends_screen.dart` sadece arkadaşları listeliyor ve (yalnızca sigara içenler için) ₺ tasarrufu gösteriyor. **Sıralama/puan tablosu yok.**
- **Öneri:** Mevcut arkadaş listesini "tasarrufa/skora göre sıralı" basit bir leaderboard'a çevirmek — düşük efor, yüksek görünür değer. (Ders için karmaşık RPC'ye gerek yok, client'ta sıralama yeter.)

### E2. Çoklu alışkanlık seçimi sahte  `[Orta]`
- **Nerede:** `habit_selection_screen.dart`
- **Durum:** Checkbox'lar birden çok seçim izlenimi veriyor ama sadece `firstWhere` ile **ilk** seçilen alışkanlık ileri taşınıyor. "Other" serbest metni doğrulanmıyor.
- **Öneri:** Ya tek seçim (radio) yapalım ya da çoklu seçimi gerçekten destekleyelim. Ders için tek seçim daha basit.

### E3. Hedef (goal) yapısal değil, serbest İngilizce metin  `[Orta]`
- **Nerede:** `goal_selection_screen.dart` → `profiles.goal` alanına "Reduce by 30%" gibi string yazılıyor.
- **Durum:** Hiçbir hesaplamada kullanılmıyor, çevrilemez, enum değil.

### E4. Pozitif aktiviteler (yürüyüş, meditasyon...) UI'da yok  `[Bilgi]`
- **Durum:** Spec'te aktivite loglama ve bonus puan var; canlı UI'da hiç yok. (Kapsam kararı sizin.)

---

## F. Veri Bütünlüğü / Mantık

### F1. Puanlama tamamen client + SharedPreferences  `[Yüksek]`
- **Nerede:** `home_screen.dart` (`_updateTotalSaved`, `_updateLungScore`, `_loadDailyCount`)
- **Durum:** `total_saved` ve `lung_score` cihazda hesaplanıp `profiles`'a yazılıyor. Spec ise "puan asla client'ta hesaplanmaz, DB trigger hesaplar" diyor.
- **Etki:** Çoklu cihaz senkronu bozulur (SharedPreferences lokal). `past_total_saved` / `past_lung_score` türetme mantığı kırılgan ve hata yapmaya açık.

### F2. Akciğer skoru formülü keyfi  `[Düşük]`
- **Nerede:** `home_screen.dart` → günde `+1.11`, içilen her sigara `-25.0`, sonra `clamp(0,100)`.
- **Durum:** Tek bir sigara skoru %25 düşürüyor; tıbbi temeli yok ve sezgiye aykırı sonuçlar üretebiliyor. Ders için kabul edilebilir ama not düşülmeli.

### F3. `friendships.status` büyük/küçük harf riski  `[Orta — doğrulanmalı]`
- **Durum:** Canlı kod `'PENDING'` / `'ACCEPTED'` (büyük harf) kullanıyor. Spec'teki şema ise `'pending'` / `'accepted'` (küçük harf) + CHECK constraint öngörüyor. Migration olmadığı için gerçek DB'nin hangisini kullandığını **doğrulayamadım.** Eğer DB küçük harf + CHECK ise insert/update sessizce patlar.
- **Öneri:** Supabase'deki gerçek tabloyu kontrol edelim.

### F4. Kayıt sırasında profil oluşturulmuyor  `[Orta]`
- **Nerede:** `auth_screen.dart` → `signUp(email, password)` sadece auth user yaratıyor; `profiles` satırı yalnızca username adımında (`username_selection_screen.dart`) upsert ediliyor.
- **Etki:** Kullanıcı e-posta doğrulama ile username adımı arasında çıkarsa auth user var ama profili yok. Ayrıca spec'in beklediği `display_name` hiç set edilmiyor.

### F5. N+1 sorgu  `[Düşük]`
- **Nerede:** `friends_screen.dart` (`_fetchMyFriends`, `_fetchRequests`) — her arkadaş için ayrı `profiles` sorgusu döngüde.
- **Öneri:** Tek join'le çekmek. Ders ölçeğinde kritik değil.

---

## G. Güvenlik / Konfigürasyon (İyi durumda)

### G1. Sırlar doğru şekilde gitignore'lu  `[Bilgi — sorun yok]`
- `.env` (içinde `GEMINI_API_KEY`) ve `lib/supabase_options.dart` git tarafından izlenmiyor (`.gitignore`: `.env*`, `lib/supabase_options.dart`). Anon key zaten `sb_publishable_...` (herkese açık olması normal).
- **Tek not:** Flutter uygulaması `.env`'i okumuyor (`flutter_dotenv` yok). Yani `.env`'deki `GEMINI_API_KEY` uygulamada kullanılmıyor; sadece edge function secret'ları kullanıyor. Bu da A1/A5 (ölü kod) ile tutarlı.

---

## Önerilen Öncelik Sıralaması

| # | Bulgu | Önem | Efor | Risk |
|---|-------|------|------|------|
| C1 | Onboarding ekranlarını temaya/yeşil palete taşı | Yüksek | Düşük | Düşük |
| C2 | AuthGate yükleme ekranını temaya uydur | Düşük | Çok düşük | Düşük |
| D1 | Dummy ekranları sil | Düşük | Çok düşük | Yok |
| A2 | Boş `supabase_service.dart`'ı sil | Orta | Çok düşük | Yok |
| E1 | Arkadaşları basit leaderboard'a çevir | Yüksek | Orta | Düşük |
| E2 | Çoklu seçim yanılgısını düzelt (tek seçim) | Orta | Düşük | Düşük |
| A3 | Ana ekranı seçilen alışkanlığa göre genelleştir | Kritik | Yüksek | Orta |
| B1–B3 | Gerçek i18n veya merkezî metin | Orta | Orta-Yüksek | Orta |
| F4 | Kayıtta profil + display_name | Orta | Düşük | Düşük |
| F3 | friendships.status harf kontrolü | Orta | Düşük | — |
| A4 | DB şemasını migration olarak repoya ekle | Kritik | Orta | Düşük |
| A1/A5 | Ölü repository + edge function kararı | — | — | — |

> Not: UI tarafında her şey mevcut yeşil palet ve `context.appAccent` extension'ı ile, ders projesine uygun sade bileşenlerle yapılacak. Karmaşık animasyon/özel widget eklenmeyecek.
