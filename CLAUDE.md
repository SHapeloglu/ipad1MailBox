# CLAUDE.md — iPad1MailBox

Orijinal **iPad 1 (iOS 5.1.1, armv7, 256 MB RAM)** için hafif IMAP e-posta istemcisi — Objective-C/UIKit bölünmüş görünüm, **non-ARC**, Theos + iPhoneOS 6.1 SDK. iOS 5 SecureTransport güncel posta sunucularıyla konuşamadığı için modern TLS, pakete gömülü **Mbed TLS 3.6.7** taşımasından gelir (TLS 1.2, ECDHE/ECDSA + AES-GCM, SNI, host adı + X.509 zincir doğrulaması). Paket `com.shapeloglu.ipad1mailbox` **0.5-alpha1** (`control`).

- GitHub: https://github.com/SHapeloglu/ipad1MailBox
- Önce oku: `TASK.md` (tek aktif görev + "bitti" tanımı) → `SESSION.md` (son devir, test komutları) → `ARCHITECTURE.md` (katmanlar, güven modeli, taşıma) → `DECISIONS.md` (ADR-001…012) → `BACKLOG.md`. Üçüncü taraf lisansları: `THIRD_PARTY_NOTICES.md`.

## Durum

- 0.4-alpha1 ✅ cihazda: `IMBMBEDTLSTransport` üzerinden Gelen Kutusu (LOGIN → SELECT INBOX → en son 25 başlığı FETCH).
- 0.4-alpha2 ✅ cihazda: UTF-8 ve ISO-8859-9 dahil RFC 2047 Konu/Gönderen çözme.
- **0.5-alpha1 (aktif):** mesaj okuyucu — `UID FETCH <uid> BODY.PEEK[]<0.262144>` → MIME ayrıştırma → ek olmayan ilk `text/plain` parçası (QP/Base64, CoreFoundation karakter setleri). Fiziksel cihaz doğrulaması gerekiyor (bkz. `TASK.md` "Sonraki adımlar").

## Derleme

```bash
./scripts/bootstrap_mbedtls.sh                 # mbedtls-3.6.7'yi Vendor/mbedtls'e klonlar, Config/IMBMBEDTLSConfig.h'yi kurar, ISRG Root X1'i Resources/'a indirir
make clean && make package FINALPACKAGE=1      # ARCHS=armv7, TARGET=iphone:clang:6.1:5.1
```

`Vendor/` bootstrap betiğiyle üretilir (commit edilmez). Eski `ssh-rsa` seçenekleriyle SSH üzerinden kurulur.

## Kod haritası (`Classes/`)

`IMBAccount*` (metadata + Keychain şifreleri) · `IMBIMAPClient` · `IMBMBEDTLSTransport` + `IMBMBEDTLSPlatform.c` (`mach_absolute_time` ile monoton zaman) · `IMBRFC2047Decoder` · `IMBMIMETextExtractor` · `IMBInbox/MessageList/MessageReader/Compose/AccountSetup ViewController` · `IMBTLSDiagnostics`, `IMBModernTLSProbe` (tanılama; SecureTransport yalnız karşılaştırma için tutuluyor).

## Kurallar (TASK.md / DECISIONS.md'den)

- **TLS doğrulamasını asla zayıflatma** (ADR-003); SecureTransport yalnızca tanılama içindir (ADR-004).
- Şifreler yalnızca Keychain'de (ADR-002).
- Sınırlı getirme: 256 KB mesaj ön eki, toplam 512 KB IMAP yanıtı; mesajların/eklerin tamamını sınırsız getirme.
- Güncel kilometre taşı HTML görüntüleme, SMTP, ek indirme veya çevrimdışı önbellek **eklemez**.
- Uygulama sahipliğini dar tut (ADR-008): dosya yöneticisi/PDF/medya özelliği yok — kardeş uygulamalara devret.
- Mbed TLS'i ancak özellik seti çalıştıktan sonra optimize et (ADR-009). IMAP'in bugün, SMTP'nin ileride paylaştığı tek taşıma (ADR-012).
- Fiziksel cihaz sonuçları `SESSION.md`'ye yazılır; `TASK.md` tam olarak bir aktif görev tutar.
- Tüm `.md` dokümanları Türkçe yazılır.
