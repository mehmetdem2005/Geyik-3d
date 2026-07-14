# Teknik Mimari

Hedef platform Android/iOS yatay ekran, hedef renderer Godot Mobile'dır. PC girişleri yalnızca editör QA yedeğidir.

## Katmanlar

```text
UI / Sahne Sunumu
       ↓ olaylar
Oynanış Alanları (Player, Weapons, Animals, Missions, World)
       ↓ saf veri ve bileşenler
Çekirdek (Damage, Health, Ballistics, Contracts)
       ↓
Servisler (Save, Settings, Audio, EventBus, GameState)
```

Sahne düğümleri yalnızca kendi yaşam döngülerini yönetir. Alanlar arası iletişim doğrudan düğüm yolu aramak yerine sinyal tabanlı `EventBus` ile yapılır. Bu kural, sahne akışını değiştirmeyi ve çoklu av bölgeleri eklemeyi güvenli tutar.

## Sorumluluklar

- `scripts/autoload`: Sahne değişse bile yaşayan uygulama servisleri. Kaydetme işlemi geçici dosyaya yazıp atomik yeniden adlandırma kullanır.
- `scripts/core`: Motor sahnesine en az bağımlı, test edilebilir hesap ve bileşenler.
- `scripts/data`: Ayarlanabilir `Resource` sözleşmeleri. Denge değerleri kod akışından ayrıdır.
- `scripts/gameplay/player`: Girdi, hareket, kamera, dayanıklılık ve oyuncu gürültüsü.
- `scripts/gameplay/weapons`: Silah durumu, balistik örnekleme, geri tepme ve hasar gönderimi.
- `scripts/gameplay/animals`: Algı, karar, lokomasyon, vuruş bölgeleri ve av doğrulama.
- `scripts/gameplay/missions`: Hedefler, etik puan ve sonuç durumu.
- `scripts/gameplay/world`: Deterministik biyom üretimi, gün ışığı ve performans bütçesi.
- `scripts/ui`: Oyun durumunu sunar; oyun kurallarına sahip değildir.

## Performans bütçeleri

| Alan | Bütçe / strateji |
|---|---|
| Dünya | Oyuncu çevresinde 5×5 hücre; kare başına en fazla bir yeni hücre üretimi |
| Arazi | Yakın hücre 16×16, uzak hücre 10×10 topoloji; hücre ayrılınca bellekten çıkar |
| Bitki | Hücre başına tekil düğümler yerine iki GPU `MultiMesh` çağrısı |
| Çarpışma | Hücre başına yalnızca seçilmiş sekiz ağaç gövdesi |
| Yaban hayatı | 14 geyik, 4 kurt, 2 ayı aktif bütçesi; 230 m dışında geri dönüşüm |
| Algı | Her fizik karesi yerine hayvan başına 220–420 ms aralıklı dağıtılmış sorgu |
| Balistik | Sonsuz hitscan yerine 12 ms analitik yörünge segmentleri, 520 m üst sınır |
| UI | Değerler olay geldiğinde güncellenir; oyun kuralı çalıştırmaz |
| Renderer | Mobile/Vulkan-Metal, 2× MSAA, HDR 2D kapalı, düşük sayıda gerçek zamanlı ışık |

Mobil profil ölçümü gerçek düşük/orta seviye Android cihazda Godot Profiler ve GPU araçlarıyla yapılmalıdır; editör FPS'i cihaz bütçesi kabul edilmez.

## Genişletme noktaları

- Yeni silah: `WeaponDefinition` kaynağı oluşturup `RifleController` sözleşmesini uygulayın.
- Yeni hayvan: `AnimalDefinition`, görsel fabrika ve mevcut algı bileşenini kullanan alan denetleyicisi ekleyin.
- Yeni görev: `HuntMission` hedef sözleşmesini genişletin; UI görev olaylarını otomatik dinler.
- Yeni biyom: `ForestWorld` içindeki üretim profillerini ayrı `Resource` haline getirip aynı tohum akışını koruyun.

## Kayıt sözleşmesi

Kayıt şeması sürümlüdür. Bilinmeyen alanlar güvenli biçimde yok sayılır; eski sürümler `SaveService._migrate()` içinde yükseltilir. Kullanıcı ayarları ilerlemeden ayrı tutulur.
