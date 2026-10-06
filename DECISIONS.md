# Mimari Kararlar

_Son güncelleme: 2026-09-17_

Bu hafif bir karar günlüğüdür. Orijinal kısıtlar hatırlanmadan kolayca yeniden tartışılabilecek seçimleri buraya kaydet.

## ADR-001 - Orijinal iPad'i açıkça hedefle

**Durum:** Kabul edildi

Proje iPad 1, iOS 5.1.1, armv7, 256 MB RAM, non-ARC Objective-C, Theos ve iPhoneOS 6.1 SDK'yı hedefler.

**Sonuçlar:**

- güncel Apple ağ API'lerinin var olduğu varsayılamaz
- bellek kullanımı sınırlı kalmalı
- bağımlılıklar eski SDK/toolchain ile derlenmeli
- fiziksel cihaz testi gerekli

## ADR-002 - E-posta şifrelerini yalnızca Keychain'de sakla

**Durum:** Kabul edildi

Hesap metadata'sı normal şekilde saklanabilir, ancak şifreler iOS Keychain'de saklanmalıdır.

Uygulama gerekli uygulama kimliği ve keychain erişim grubu yetkileriyle (entitlements) imzalanır.

**Reddedilen seçenekler:** plist, `NSUserDefaults`, SQLite, günlükler, özel şifreli dosyalar.

## ADR-003 - Uyumluluk için TLS doğrulamasını zayıflatma

**Durum:** Kabul edildi

Sertifika ve host adı doğrulaması zorunlu kalır.

Eski bir cihazı bağlayabilmek için her şeyi kabul eden doğrulama geri çağrıları, `AllowsAnyRoot`, kapatılmış karşı taraf doğrulaması veya eskimiş TLS sürümleri kullanma.

## ADR-004 - SecureTransport tanılama/eski yoldur, uzun vadeli modern TLS yolu değil

**Durum:** Kabul edildi

Fiziksel cihaz tanılamaları, iOS 5.1.1 SecureTransport'ta test posta sunucusunun şu an gerektirdiği ECDHE-ECDSA AES-GCM şifre takımlarının olmadığını gösterdi. Sunucu, iPad'de bulunan eski ECDHE-ECDSA CBC takımlarını da reddediyor.

**Karar:** Tanılamaları korumaya yetecek kadar SecureTransport'u tut, ancak modern sunucu bağlantısını pakete gömülü bir TLS uygulamasına taşı.

## ADR-005 - Modern TLS taşıması için Mbed TLS 3.6.7 kullan

**Durum:** Güncel geliştirme için kabul edildi

Mbed TLS 3.6.7 uygulamaya derlenir ve TLS 1.2, ECDHE-ECDSA, AES-GCM, SNI, X.509 doğrulaması ve güvenli RNG için yapılandırılır.

## ADR-006 - IMAP taşımasını değiştirmeden önce Mbed TLS'i bağımsız doğrula

**Durum:** Başarıyla tamamlandı

`IMBModernTLSProbe`, normal IMAP taşımasını değiştirmeden önce bilinçli bir entegrasyon kapısı olarak kullanıldı.

Fiziksel iPad artık şunları kanıtladı:

- RNG başlatma
- güven çapası ayrıştırma
- TCP bağlantısı
- TLS 1.2 el sıkışması
- ClientHello SNI
- host adı doğrulaması
- sertifika zinciri doğrulaması
- ECDHE-ECDSA AES-256-GCM anlaşması
- Dovecot IMAP karşılaması

Yoklama tanılama olarak işe yaramaya devam ediyor, ancak artık taşıma entegrasyonunu engellemiyor.

## ADR-007 - Monoton zamanı `mach_absolute_time()` ile sağla

**Durum:** Kabul edildi

Mbed TLS 3.6.7'nin varsayılan Unix benzeri milisaniye zamanlayıcı yolu, iOS 5 hedefinde bulunmayan `clock_gettime()`'ı seçiyordu. `MBEDTLS_PLATFORM_MS_TIME_ALT` ve `IMBMBEDTLSPlatform.c`, `mach_absolute_time()` kullanarak `mbedtls_ms_time()` sağlar.

## ADR-008 - E-posta uygulamasının sorumluluğunu dar tut

**Durum:** Kabul edildi

iPad1MailBox; e-posta hesapları, klasörler, mesajlar, yazma/gönderme, MIME yorumlama ve ek devrinden sorumludur. İkinci bir dosya yöneticisine veya medya oynatıcıya dönüşmez.

Planlanan devir:

- PDF -> iPad1PDFReader
- ZIP/genel dosyalar -> iPad1Files
- ses/video -> iPad1Player

## ADR-009 - Mbed TLS'i ancak gereken özellik seti çalıştıktan sonra optimize et

**Durum:** Kabul edildi

Devreye alma sırasında Makefile, nihai uygulamanın ihtiyacından daha geniş bir Mbed TLS kaynak kümesini derleyebilir. Uçtan uca TLS/IMAP doğrulaması başarıyla tamamlandıktan sonra geniş joker eklemeyi açık ve en küçük bir kaynak listesiyle değiştir ve ikili/RAM etkisini ölç.

## ADR-010 - ISRG Root X1'i koru ve RSA sertifika imzalarını destekle

**Durum:** Kabul edildi

İlk yoklama, ECC odaklı Mbed TLS profili ISRG Root X1'deki RSA imza OID'ini ayrıştıramadığı için başarısız oldu. Devreye alma sırasında güven modelini değiştirmek yerine proje ISRG Root X1'i güven çapası olarak tutar ve X.509 sertifika imzası doğrulaması için RSA PKCS#1 v1.5 desteğini açar.

ISRG Root X1 4096 bitlik bir RSA anahtarı kullandığı için `MBEDTLS_MPI_MAX_SIZE` 512 bayta çıkarıldı.

Bu, RSA TLS anahtar değişimini **açmaz**. Yapılandırılmış TLS şifre takımları yalnızca ECDHE-ECDSA + AES-GCM olarak kalır.

## ADR-011 - ClientHello SNI'yi açıkça etkinleştir

**Durum:** Kabul edildi ve doğrulandı

`0.3-alpha3` cihaz izi, projenin en küçük derlemesinde yalnızca `mbedtls_ssl_set_hostname()` çağırmanın yetmediğini kanıtladı. Host adı doğrulaması aktifti, ancak `MBEDTLS_SSL_SERVER_NAME_INDICATION` açık olmadığı için ClientHello `server_name` uzantısını taşımıyordu.

Bu yüzden sanal host'lu IMAP sunucusu varsayılan `da2.mirahosting.com` sertifikasını döndürdü.

`0.3-alpha4`, `mbedtls_ssl_set_hostname()`'i koruyarak `MBEDTLS_SSL_SERVER_NAME_INDICATION`'ı açtı.

Fiziksel iPad'de bu; beklenen `olap.com.tr` sertifikası, `mail.olap.com.tr` içeren SAN, sıfır doğrulama bayrağı, başarılı TLS 1.2 el sıkışması, `TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384` ve geçerli bir Dovecot IMAP karşılamasıyla sonuçlandı.

## ADR-012 - Şimdi IMAP, ileride SMTP için tek bir Mbed TLS taşımasını yeniden kullan

**Durum:** Kabul edildi

Kanıtlanmış Mbed TLS kurulumu, doğrudan `IMBIMAPClient`'a kopyalanmak yerine tanılama yoklamasından yeniden kullanılabilir bir taşıma soyutlamasına çıkarılmalıdır.

Taşımanın sorumlulukları:

- TCP bağlan/kapat
- TLS kurulumu ve el sıkışması
- güven çapası yapılandırması
- SNI ve host adı doğrulaması
- sınırlı şifreli okuma/yazma
- zaman aşımı/iptal işleme
- TLS hata raporlama

IMAP komutları ve ayrıştırma `IMBIMAPClient`'ta kalmalı. SMTP ileride TLS/güvenlik mantığını çoğaltmadan aynı taşımayı kullanabilir.

**Neden:** Protokol mantığını güvenlik/soket altyapısından ayrı tutmak, tekrarı azaltmak ve kısıtlı iPad 1 hedefinde gelecekteki SMTP entegrasyonunu daha güvenli yapmak.
