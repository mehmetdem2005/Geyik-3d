# Geyik 3D

Geyik 3D, Godot 4.7 ile geliştirilen **mobil öncelikli, açık dünya birinci şahıs av oyunudur**. Android ve iOS yatay ekran düzeni için tasarlanmıştır; hareket sabit sol-alt joystick, kamera sağ dokunmatik alan ve bağlama duyarlı eylem düğmeleriyle yönetilir.

## Oyunda neler var?

- Oyuncu ilerledikçe 72 metrelik hücreleri zaman dilimli yükleyip geride kalanları boşaltan deterministik açık dünya.
- Kıvrımlı nehir, yüzme, fiziksel köprü, orman karakolu, tepeler ve biyom renkleri.
- `MultiMesh` tabanlı PBR çam, çim ve taranmış kaya kümeleri; yakın çevrede seçilmiş gövde çarpışmaları.
- Otlayan/dolaşan, sesi ve görüşü kullanan, şüphelenip kaçan kızıl geyikler.
- Oyuncuyu fark edip takip eden kurt ve ayılar; saldırı, can ve ölüm döngüsü.
- Mesafe, yerçekimi, sürüklenme, rüzgâr ve kinetik enerji kullanan .308 balistiği.
- Beyin, omurga, kalp-akciğer, gövde ve uzuv vuruş bölgeleri; etik av ve kupa puanı.
- Cephane ve sağlık toplama, görev, av doğrulama, kalıcı en iyi skor ve atomik kayıt.
- Prosedürel ses ipuçları; mobil boyutlu CC0 orman HDRI, zemin, çam, kaya ve gerçek sürgülü tüfek PBR varlıkları.

## Mobil kontroller

| Bölge / düğme | İşlev |
|---|---|
| Sol alt | Konumu değişmeyen sabit hareket joystick'i |
| Sağ ekran | Parmağı sürükleyerek bakış |
| `ATEŞ` | Tüfeği ateşle |
| `NİŞAN` | Dürbünü aç/kapat |
| `DOLDUR` | Şarjörü doldur |
| `KOŞ` | Basılı tutarak koş |
| `EĞİL` | Çömelmeyi aç/kapat |
| `ZIPLA` | Zıpla |
| `EYLEM` | Avı doğrula veya karakolu kullan; yalnızca uygun hedefte görünür |

Editörde hızlı test için `WASD`, fare, sol/sağ tık, `R`, `E`, `Shift`, `C` ve `Space` yedek girişleri korunur. Ürün hedefi PC değildir.

## Açma ve Android'e aktarma

1. Godot 4.7 stable sürümünde `project.godot` dosyasını içe aktarın.
2. Projeyi yatay pencerede çalıştırın; dokunma kontrolleri fareyle de sınanabilir.
3. Android Build Template ve Android SDK/JDK kurulumunu Godot Editor Settings'te tamamlayın.
4. `Project > Export > Android` üzerinden debug APK üretin.

`export_presets.cfg`, ARM64, tam ekran ve sensöre göre yatay yön için hazırdır. Release imzası depoya konmaz; mağaza anahtarını yerel/CI secret olarak bağlayın.

## Doğrulama

```bash
godot --headless --path . --editor --quit-after 5
godot --headless --path . --script res://tests/run_tests.gd
```

GitHub Actions her PR'da Godot 4.7 ile proje içe aktarma ve deterministik çekirdek testlerini çalıştırır.

## Görsel varlık lisansları

Zemin, çam PBR haritaları, yosunlu kaya seti ve sürgülü tüfek modeli [Poly Haven](https://polyhaven.com/) kaynaklıdır ve CC0 1.0 kapsamındadır. Her varlığın kaynak bağlantısı kendi `LICENSE.txt` dosyasında bulunur. Tam çözünürlüklü sinema varlıkları yerine mobil için 1K haritalar kullanılır.

## Mimari

Oyun tek dosyalı bir döngü değildir. Dokunmatik giriş, dünya akışı, AI, silah, sağlık, görev, kayıt, ses ve UI kendi alanlarında bulunur; iletişim olay sözleşmeleriyle yapılır. Bağımlılık kuralları ve mobil performans bütçeleri [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) dosyasındadır.
