# Güncel Görev

_Son güncelleme: 2026-09-17_

## Hedef

Artık çalışan Mbed TLS Gelen Kutusu ve RFC 2047 başlık çözmeyi koruyarak ilk istek üzerine çalışan mesaj okuyucuyu fiziksel iPad 1'de doğrulamak.

## Tamamlanan kapılar

`0.4-alpha1`, `IMBMBEDTLSTransport` üzerinden normal Gelen Kutusu yüklemesini kanıtladı:

```text
verified Mbed TLS 1.2
-> LOGIN
-> SELECT INBOX
-> FETCH latest headers
-> message list displayed
```

Ardından `0.4-alpha2` fiziksel iPad'de başarıyla test edildi. UTF-8 ve ISO-8859-9 RFC 2047 Konu/Gönderen değerleri artık okunabilir Türkçe metin olarak görünüyor.

## Hazırlanan 0.5-alpha1 uygulaması

Gelen Kutusu'nda bir satır seçmek artık eski yer tutucu uyarı yerine `IMBMessageReaderViewController`'ı açıyor.

Okuyucu seçilen mesajı aynı doğrulanmış Mbed TLS taşıması üzerinden IMAP UID ile istiyor:

```text
connect / LOGIN / SELECT INBOX
-> UID FETCH <uid> BODY.PEEK[]<0.262144>
-> extract IMAP literal
-> parse MIME
-> display first non-attachment text/plain part
```

Yeni MIME desteği bilinçli olarak sınırlı ve temkinli:

- getirilen ham mesaj ön eki en fazla 256 KB
- toplam IMAP yanıtı güvenlik sınırı 512 KB olarak kalıyor
- bu kilometre taşında yalnızca text/plain
- küçük derinlik sınırıyla çok parçalı özyineleme
- quoted-printable gövde çözme
- Base64 gövde çözme
- CoreFoundation ile karakter seti dönüşümü
- ek parçaları atlanıyor
- HTML görüntüleme henüz açık değil

## Sonraki adımlar

1. `0.5-alpha1`'i çek ve derle.
2. Mbed TLS bootstrap/yapılandırma değişikliği gerekmiyor.
3. Fiziksel iPad'e kur.
4. Gelen Kutusu'nu aç ve birkaç farklı mesaja dokun.
5. Konu / Gönderen / Tarih'in görünür kaldığını ve altında düz metin gövdenin yüklendiğini doğrula.
6. Varsa en az bir çok parçalı ve bir Türkçe mesajı test et.
7. İptal/yaşam döngüsü davranışını denemek için Gelen Kutusu'na dönüp başka bir mesaj aç.
8. Mesajda text/plain parçası yoksa okuyucu çökmek yerine açık bir yedek mesaj göstermeli.

## Kabul ölçütleri

- Gelen Kutusu normal yüklenmeye devam ediyor
- bir satıra dokunmak gerçek bir okuyucu ekranı açıyor
- seçilen mesaj sıra numarasıyla değil UID ile getiriliyor
- varsa text/plain gövde gösteriliyor
- quoted-printable ve Base64 metin gövdeleri doğru çözülüyor
- CoreFoundation'ın tanıdığı eski Türkçe karakter setleri dahil yaygın karakter setleri doğru görünüyor
- büyük mesajlar 256 KB önizlemeyle sınırlı
- yalnızca HTML içeren veya desteklenmeyen MIME mesajları nazikçe başarısız oluyor
- kimlik bilgileri yalnızca Keychain'de kalıyor
- TLS sertifika ve host adı doğrulaması zorunlu kalıyor

## Yapma

- TLS doğrulamasını zayıflatma.
- Sınırsız mesajların veya eklerin tamamını getirme.
- HTML'i henüz görüntüleme.
- Bu kilometre taşında SMTP, ek indirme veya çevrimdışı önbellek ekleme.

## "Bitti" tanımı

Görev, fiziksel iPad mevcut Gelen Kutusu yolunu bozmadan birkaç gerçek Gelen Kutusu mesajını açıp okunabilir text/plain gövdelerini istek üzerine gösterebildiğinde tamamlanır.
