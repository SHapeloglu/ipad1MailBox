# iPad1MailBox Mimarisi

## Amaç

iPad1MailBox, orijinal iPad için hafif bir e-posta istemcisidir. Proje, güncel platformların kolaylık API'leri yerine öngörülebilir bellek kullanımını, açık sahipliği, küçük bağımlılıkları ve iOS 5.1.1 uyumluluğunu tercih eder.

## Kesin kısıtlar

- Cihaz: orijinal iPad
- İşletim sistemi: iOS 5.1.1
- Mimari: armv7
- RAM: 256 MB
- Objective-C / UIKit
- non-ARC bellek yönetimi
- Theos + iPhoneOS 6.1 SDK
- güncel iOS API'lerine bağımlılık yok

## Mimari kurallar

1. Arayüz kodu protokol veya kriptografi ayrıntılarına sahip olmamalı.
2. Şifreler yalnızca Keychain'e aittir. Şifreleri asla plist, `NSUserDefaults`, SQLite, günlükler veya tanılamalarda saklama.
3. Sertifika doğrulaması açık kalmalı. `AllowsAnyRoot`, her şeyi kabul eden doğrulama geri çağrıları veya başka güven atlatmaları kullanma.
4. Posta kutusu içeriğini kademeli getir. Gereksiz yere tüm posta kutusunu, büyük mesaj gövdesini veya eki belleğe yükleme.
5. iPad1MailBox yalnızca e-posta işlevinin sahibidir. Genel dosya yönetimi iPad1Files'a aittir; medya/belge görüntüleme uygun uygulamaya devredilir.

## Katmanlar

### Arayüz

- `IMBAppDelegate` - uygulama başlatma ve bölünmüş görünüm kurulumu
- `IMBInboxViewController` - hesap/posta kutusu kenar çubuğu
- `IMBAccountSetupViewController` - hesap yapılandırması
- `IMBMessageListViewController` - Gelen Kutusu durumu, başlık listesi, yenileme, TLS tanılamaları
- `IMBComposeViewController` - mesaj yazma ekranı iskeleti

### Hesap ve kimlik bilgisi saklama

- `IMBAccount` - gizli olmayan IMAP/SMTP yapılandırması
- `IMBAccountStore` - metadata kalıcılığı ve Keychain kimlik bilgisi saklama
- `entitlements.plist` - iOS 5 kod imzalaması için gereken uygulama/keychain erişim grubu

### IMAP protokolü

`IMBIMAPClient`, güncel posta kutusu kilometre taşı için gereken en küçük IMAP durum akışından sorumludur:

1. taşıma üzerinden bağlan
2. sunucu karşılamasını bekle
3. `LOGIN`
4. `SELECT INBOX`
5. `EXISTS`'i oku
6. en son 25 mesaj başlığını getir
7. temiz şekilde kapat

`0.4-alpha1`'den itibaren normal IMAP çalışması artık CFStream/SecureTransport kullanmıyor. Arka plan iş parçacığında çalışır ve şifreli ağ G/Ç'sini `IMBMBEDTLSTransport`'a devreder.

IMAP ayrıştırıcı TLS'ten ayrı kalır; böylece SMTP ileride kriptografi/ağ kodunu çoğaltmadan aynı taşımayı kullanabilir.

### TLS taşıması

#### `IMBMBEDTLSTransport`

Normal posta trafiği için yeniden kullanılabilir, doğrulanmış TLS taşıması.

Sorumlulukları:

- TCP bağlantısı
- Mbed TLS bağlam/RNG/güven çapası kurulumu
- TLS 1.2 el sıkışması
- ClientHello SNI
- host adı doğrulaması
- X.509 zincir doğrulaması
- şifreli okuma/yazma
- sınırlı zaman aşımları
- aktif soketi kapatarak iptal
- temiz kapanış

Taşıma IMAP komutlarını, kullanıcı adlarını, şifreleri, posta kutularını, MIME'ı veya SMTP anlamlarını bilmez.

#### Mbed TLS 3.6.7

- derleme zamanında `Vendor/mbedtls` altına eklenir
- `Config/IMBMBEDTLSConfig.h` ile yapılandırılır
- `scripts/bootstrap_mbedtls.sh` ile kurulur
- iOS 5 monoton zamanını `Classes/IMBMBEDTLSPlatform.c` sağlar
- güncel modern taşıma için yalnızca TLS 1.2
- onaylı şifre takımları ECDHE-ECDSA + AES-GCM ile sınırlı
- RSA yalnızca X.509 zincir imzası doğrulaması için açık
- ClientHello SNI açıkça etkin

Modern TLS yolu fiziksel iPad 1'de `mail.olap.com.tr:993`'e karşı tam sertifika/host adı doğrulaması ve Dovecot karşılamasıyla kanıtlandı.

#### Tanılamalar

- `IMBTLSDiagnostics`, eski iOS 5 SecureTransport şifre setini gözlemlemek için duruyor.
- `IMBModernTLSProbe`, taşıma entegrasyonu oturana kadar fiziksel cihazda Mbed TLS tanılaması olarak duruyor.

SecureTransport artık modern sunucular için hedeflenen normal IMAP taşıması değil.

## Güven modeli

Uygulama sunucu host adını ve sertifika zincirini doğrular. Güncel kurulum, doğrulanan test sunucusu zinciri için `Resources` içinde ISRG Root X1'i içerir.

Güven çapaları ek sağlayıcılar için genişletilebilir, ancak desteklenmeyen zincirler doğrulamayı atlatarak değil, gereken güvenilir kökleri/algoritmaları ekleyerek çözülmelidir.

## Eşzamanlılık ve iptal

`IMBIMAPClient` getirme işlemini arka plan iş parçacığında yapar. Her işlem bir nesil belirteci alır. Yenile/iptal nesli artırır ve o an aktif olan taşımayı iptal eder.

Eski bir işçi sonucu ana iş parçacığında atılır. İptalde aktif Mbed TLS soketi kapatılır, böylece bloklanmış bir okuma hızla çözülür.

## Bellek ve yanıt sınırları

- ilk Gelen Kutusu sayfası: en son 25 mesaj
- IMAP komut zaman aşımı: 20 saniye
- bu kilometre taşı için en fazla biriken IMAP yanıtı: 512 KB
- Mbed TLS kayıt tamponları proje yapılandırmasında sınırlı kalır
- Gelen Kutusu listelenirken tam gövdeler/ekler getirilmez

## Uygulama ailesi sahipliği ve devir

`iPad1MailBox` hesaplar, klasörler, mesajlar, yazma/gönderme, MIME yorumlama ve ek devrinden sorumludur. Genel bir dosya yöneticisine dönüşmemelidir.

Planlanan devir hedefleri:

- PDF -> iPad1PDFReader
- ZIP ve genel dosyalar -> iPad1Files
- video/ses -> iPad1Player

Planlanan ortak ek kökü:

`/var/mobile/Media/iPad1Files/Mail/Attachments/`

## Derleme akışı

İlk kurulum veya Mbed TLS yapılandırmasını yenileme:

```bash
make bootstrap
```

Paket derleme:

```bash
find . -type f -exec touch {} +
make clean
make package FINALPACKAGE=1
```

## Kilometre taşları

### v0.1

Uygulama iskeleti, bölünmüş görünüm, hesap kurulumu, Keychain, mesaj yazma iskeleti.

### v0.2

En küçük IMAP ayrıştırıcı, Gelen Kutusu başlıkları, bağlantı tanılamaları, SecureTransport yetenek araştırması.

### v0.3

Fiziksel iPad'de modern Mbed TLS taşıma doğrulaması.

### v0.4

Yeniden kullanılabilir doğrulanmış Mbed TLS taşıması ve normal IMAP başlık yüklemesinin SecureTransport'tan taşınması.

### Taşıma kararlı olduktan sonra

- tam mesaj gövdesi yükleme
- RFC 2047 başlık çözme
- MIME ayrıştırma
- yeniden kullanılabilir taşımayla SMTP gönderimi
- yanıtla/ilet
- Gönderilen/Taslaklar/Çöp
- bayraklar
- ekler ve uygulama ailesi yönlendirmesi
- sınırlı metadata önbelleği
