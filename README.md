# iPad1MailBox

iPad1MailBox, orijinal iPad (iOS 5.1.1, armv7, 256 MB RAM) için hafif bir e-posta istemcisidir.

## Güncel kilometre taşı: v0.4-alpha2

- Yerel (native) Objective-C / UIKit bölünmüş görünüm (split-view) arayüzü
- Hesap metadata'sı saklama + Keychain tabanlı şifre saklama
- Mbed TLS 3.6.7 ile doğrulanmış TLS 1.2 taşıması
- Güncel modern yol için yalnızca TLS 1.2 ECDHE/ECDSA + AES-GCM
- Sanal host'lu posta sunucuları için ClientHello SNI
- host adı + X.509 sertifika zinciri doğrulaması
- şifreli bağlan/oku/yaz/iptal/kapat davranışı için yeniden kullanılabilir `IMBMBEDTLSTransport`
- normal Gelen Kutusu IMAP akışı SecureTransport'tan Mbed TLS'e taşındı
- `LOGIN -> SELECT INBOX -> FETCH` ile en son 25 mesaj başlığı
- Q ve Base64 kodlanmış sözcükler için RFC 2047 Konu/Gönderen çözme
- CoreFoundation üzerinden UTF-8 ve eski IANA karakter seti dönüşümü (mevcutsa Türkçe ISO-8859-9 dahil)
- SecureTransport ve Mbed TLS tanılamaları ayrı ayrı korundu
- non-ARC ve Theos/iPhoneOS 6.1 SDK uyumlu

`0.4-alpha1` orijinal iPad'de fiziksel olarak doğrulandı: gerçek Gelen Kutusu yeniden kullanılabilir Mbed TLS taşımasıyla başarıyla yüklendi ve eski normal çalışmadaki `OSStatus -9844` engeli ortadan kalktı. `0.4-alpha2`, gerçek dünyadaki kodlanmış Konu ve Gönderen başlıklarını okunabilir yapmaya odaklanıyor.

## Proje dokümanları

- `ARCHITECTURE.md` - bileşen sınırları, kısıtlar, güven modeli ve taşıma tasarımı
- `DECISIONS.md` - mimari karar günlüğü
- `TASK.md` - tek aktif mühendislik görevi ve "bitti" tanımı
- `SESSION.md` - son geliştirme devri ve test komutları
- `BACKLOG.md` - ertelenen özellikler ve gelecek işler

Geliştirmeye devam ederken önce `TASK.md` ve `SESSION.md`'yi oku.

## Derleme hedefi

- Cihaz: iPad 1
- İşletim sistemi: iOS 5.1.1
- Mimari: armv7
- Toolchain: Theos + clang
- SDK: iPhoneOS 6.1
- Bellek yönetimi: non-ARC

## Mbed TLS ilk kurulumu

Mbed TLS kaynakları ve güncel güven çapası (trust anchor) yerel olarak kurulur:

```bash
make bootstrap
```

Bu, Mbed TLS'i `mbedtls-3.6.7`'ye sabitler, proje yapılandırmasını kurar ve ISRG Root X1'i indirir.

## Derleme

`0.4-alpha1` ile `0.4-alpha2` arasında Mbed TLS yapılandırması değişmedi; bu yüzden zaten çalışan yerel vendor ağacı yeniden bootstrap gerektirmez.

```bash
find . -type f -exec touch {} +
make clean
make package FINALPACKAGE=1
```

Beklenen paket:

```text
packages/com.shapeloglu.ipad1mailbox_0.4-alpha2_iphoneos-arm.deb
```

## Normal Gelen Kutusu taşıması

`IMBIMAPClient` protokol işini arka plan iş parçacığında yapar ve şifreli ağ G/Ç'sini `IMBMBEDTLSTransport`'a devreder.

Güncel akış:

```text
verified TLS connect
-> Dovecot greeting
-> LOGIN
-> SELECT INBOX
-> read EXISTS
-> FETCH latest 25 headers
-> LOGOUT
```

Güncel güvenlik sınırları:

- 20 saniyelik komut süresi sınırı
- en fazla 512 KB biriken IMAP yanıtı
- eski yenileme sonuçlarının yok sayılması için nesil (generation) belirteciyle iptal
- iptalde aktif soketin kapatılması

## RFC 2047 başlık çözme

`IMBRFC2047Decoder`, gerçek posta başlıklarında kullanılan yaygın kodlanmış sözcük biçimlerini işler:

```text
=?UTF-8?Q?Yeni_Oturum_Kayd=C4=B1?=
=?UTF-8?B?...?=
=?iso-8859-9?Q?...?=
```

Çözücü bitişik kodlanmış sözcükleri destekler ve bozuk/desteklenmeyen içeriği atmak yerine korur. iOS 5.1.1'de bulunmayan yeni NSData API'leri yerine küçük, özel bir Base64 çözücü kullanır.

## TLS tanılamaları

`TLS` düğmesi kullanılabilir durumda kalıyor. Eski iOS 5 SecureTransport şifre setini ve devreye alma sırasında kullanılan bağımsız Mbed TLS yoklamasını gösterir. Normal Gelen Kutusu yüklemesi artık SecureTransport'a bağlı değil.

## Planlanan uygulama ailesi entegrasyonu

Ekler ikinci bir dosya yöneticisi gibi yönetilmek yerine devredilecek:

- PDF -> iPad1PDFReader
- ZIP / genel dosyalar -> iPad1Files
- Medya -> iPad1Player

Gelecekteki varsayılan ek saklama kökü:

`/var/mobile/Media/iPad1Files/Mail/Attachments/`

## Güvenlik

Şifreler asla plist dosyalarına, `NSUserDefaults`'a, günlüklere veya SQLite'a yazılmamalıdır. Hesap kimlik bilgileri Keychain'de kalır. Modern TLS yolu sertifika zinciri doğrulaması, host adı doğrulaması, sanal host'lu sunucular için SNI ve yapılandırılmış TLS 1.2 ECDHE-ECDSA AES-GCM şifre takımlarını gerektirir.
