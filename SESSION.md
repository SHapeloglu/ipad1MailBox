# Oturum Devri

_Son güncelleme: 2026-09-17_

## Neredeyiz

Fiziksel iPad 1 artık hem modern taşıma hem de başlık çözme kilometre taşlarını geçti.

En son kanıtlanmış cihaz derlemesi:

```text
iPad1MailBox 0.4-alpha2
```

Sıradaki test derlemesi:

```text
iPad1MailBox 0.5-alpha1
```

## Fiziksel iPad'de kanıtlananlar

Normal Gelen Kutusu doğrulanmış Mbed TLS 3.6.7 üzerinden çalışıyor:

```text
TLS 1.2
-> LOGIN
-> SELECT INBOX
-> FETCH latest 25 headers
-> RFC 2047 decoding
-> readable Turkish message list
```

Eski SecureTransport `OSStatus -9844` normal çalışma hatası ortadan kalktı. UTF-8 ve ISO-8859-9 ile kodlanmış Konu/Gönderen alanları artık doğru görünüyor.

## Hazırlanan 0.5-alpha1 değişiklikleri

### Mesaj okuyucu

Yeni controller:

```text
Classes/IMBMessageReaderViewController.h
Classes/IMBMessageReaderViewController.m
```

Gelen Kutusu'ndaki bir satıra dokunmak artık Konu, Gönderen, Tarih ve istek üzerine yüklenen gövdeyi gösteren gerçek bir mesaj ekranı açıyor.

### Sınırlı gövde getirme

`IMBIMAPClient` artık şunu destekliyor:

```text
fetchMessageBodyForAccount:password:uid:
```

Akış:

```text
connect
-> LOGIN
-> SELECT INBOX
-> UID FETCH <uid> BODY.PEEK[]<0.262144>
-> extract IMAP literal
-> MIME plain-text extraction
-> LOGOUT
```

Seçilen mesaja sıra numarasıyla değil UID ile erişiliyor.

### MIME metin çıkarma

Yeni dosyalar:

```text
Classes/IMBMIMETextExtractor.h
Classes/IMBMIMETextExtractor.m
```

Güncel kapsam:

- ek olmayan ilk `text/plain` parçası
- sınırlı derinlikte çok parçalı (multipart) özyineleme
- quoted-printable çözme
- Base64 çözme
- CoreFoundation ile karakter seti dönüşümü
- ek parçaları atlanır
- HTML bilinçli olarak henüz görüntülenmiyor

Bellek/güvenlik sınırları:

```text
message prefix: 256 KB maximum
IMAP accumulated response: 512 KB maximum
command timeout: 20 seconds
```

(mesaj ön eki en fazla 256 KB · biriken IMAP yanıtı en fazla 512 KB · komut zaman aşımı 20 saniye)

## Derleme komutları

Mbed TLS yapılandırması değişmedi; mevcut yerel vendor ağacı güncelse bootstrap gerekmez.

```bash
cd ~/projects/ipad1MailBox
git pull origin main
find . -type f -exec touch {} +
make clean
make package FINALPACKAGE=1
```

Beklenen paket:

```text
packages/com.shapeloglu.ipad1mailbox_0.5-alpha1_iphoneos-arm.deb
```

Kopyalama:

```bash
scp -o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
packages/com.shapeloglu.ipad1mailbox_0.5-alpha1_iphoneos-arm.deb \
root@192.168.1.100:/var/mobile/
```

Kurulum:

```bash
dpkg -i /var/mobile/com.shapeloglu.ipad1mailbox_0.5-alpha1_iphoneos-arm.deb
su mobile -c 'HOME=/var/mobile /usr/bin/uicache'
killall SpringBoard
```

## Sırada test edilecekler

Gelen Kutusu'ndan birkaç mesaj aç. En az bir düz metin veya çok parçalı e-postanın okunabilir içerik gösterdiğini doğrula. Geri dönüp başka bir mesaj açmayı test et. Yalnızca HTML içeren mesajlar bu kilometre taşında bilinçli olarak "düz metin bulunamadı" yedek mesajını gösterebilir.

## Buradan devam et

`TASK.md`'yi oku. `0.5-alpha1`'i derle ve fiziksel olarak test et. HTML görüntüleme, ekler veya SMTP eklemeden önce derleme/çalışma zamanı/MIME sorunlarını düzelt.
