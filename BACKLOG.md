# İş Havuzu

_Son güncelleme: 2026-09-17_

Bu dosya güncel aktif görevin parçası olmayan işleri içerir. `TASK.md`'yi tek bir acil hedefe odaklı tut.

## Taşıma ve protokol

- Ağ değişikliklerinden sonra yeniden bağlanma davranışı ekle.
- IMAP kararlı olunca SMTP taşıması ekle.
- SMTP örtük TLS (genelde 465) ile STARTTLS gönderimini (genelde 587) ayır.
- İşlevsel kilometre taşları oturunca geniş Mbed TLS kaynak joker eklemesini açık ve en küçük kaynak listesiyle değiştir.

## IMAP

- Klasör keşfi/listeleme.
- Gönderilen/Taslaklar/Çöp eşlemesi.
- İlk 25 mesajlık sayfanın ötesinde sayfalı başlık yükleme.
- İstek üzerine tam mesaj gövdesi yükleme.
- Okundu/okunmadı bayrakları.
- Yıldız/bayrak desteği.
- Silme/taşıma işlemleri.
- Gereksiz veriyi yeniden yüklemeden yenileme.
- Düşük bellekli posta kutusu yolu kararlı olunca temel arama.

## Mesaj ayrıştırma

- Çok parçalı MIME mesajlarını ayrıştır.
- Uygun olduğunda düz metni tercih et.
- iPad 1 için temkinli HTML görüntüleme ekle.
- Gerçek posta örnekleri gerektirdikçe karakter seti kapsamını genişlet.
- Ek verisini peşin yüklemeden ek metadata'sını ayrıştır.
- Gelen Kutusu listesi dışında çözülmüş başlık gereken her yerde `IMBRFC2047Decoder`'ı yeniden kullan.

## Yazma ve SMTP

- Gerçek SMTP gönderimi.
- Yanıtla.
- Tümünü yanıtla.
- İlet.
- CC/BCC.
- Taslak kalıcılığı.
- Sınırlı bellekle ek yükleme.
- Gönderilen klasörüne kopyalama/kaydetme.

## Ekler ve iPad1 uygulama ailesi entegrasyonu

- Ekleri `/var/mobile/Media/iPad1Files/Mail/Attachments/` altına kaydet.
- PDF -> iPad1PDFReader.
- ZIP/genel dosyalar -> iPad1Files.
- Ses/video -> iPad1Player.
- iPad1MailBox içinde dosya yöneticisi işlevlerini çoğaltmaktan kaçın.
- Güvenli dosya adları ve çakışma yönetimini tanımla.
- Büyük indirmelerden önce açık kullanıcı eylemi iste.

## Depolama ve önbellek

- Küçük bir metadata önbelleğini ancak taşıma/mesaj ayrıştırma kararlı olunca ekle.
- 256 MB RAM ve sınırlı cihaz depolamasına uygun önbellek sınırları tanımla.
- Posta kutularının tamamını değil, başlıkları ve posta kutusu metadata'sını önbelleğe al.
- Eski gövde/ek önbelleğini güvenle temizle.
- Şifreleri veya kimlik doğrulama sırlarını asla önbellekte saklama.

## TLS ve güvenlik

- Pakete gömülü güven çapalarını bakımı kolay ve belgelenmiş tut.
- iOS 5 güven deposuna güvenmek yerine gerekli birden fazla ISRG kökünü pakete eklemeyi düşün.
- Faydalı olduğu yerde anlaşılan eğri ve karşı taraf sertifika zinciri için tanılama çıktısı ekle.
- Sertifika ve host adı doğrulamasını zorunlu tut.
- Taşıma çalıştıktan sonra Mbed TLS yapılandırmasındaki kullanılmayan modülleri gözden geçirip ikili boyutunu küçült.
- Her sürümden önce Mbed TLS güvenlik güncellemelerini incele.

## Arayüz ve tanılama

- Kullanıcıya yönelik bağlantı hatalarını geliştirici tanılamalarından ayır.
- Küçük bir hesap durum göstergesi ekle.
- iPad 1'de yanıt vermeye devam eden yükleniyor/iptal durumu ekle.
- Boş posta kutusu ve çevrimdışı durumlarını iyileştir.

## Sağlayıcı uyumluluğu

- Önce genel Dovecot/cPanel tarzı IMAP/SMTP'yi test et.
- Genel IMAP/SMTP kararlı olunca Gmail uyumluluğunu değerlendir.
- Genel IMAP/SMTP kararlı olunca Outlook/Microsoft uyumluluğunu değerlendir.
- OAuth2'yi yalnızca iOS 5.1.1'de mümkün olduğu yerde araştır; temel standart e-posta desteğini OAuth çalışmasına bağlama.

## Sürüm hijyeni

- Anlamlı geliştirme oturumlarının sonunda `SESSION.md`'yi güncel tut.
- `TASK.md`'de tek bir aktif sorun olsun.
- Mimariyi değiştiren seçimleri `DECISIONS.md`'ye yaz.
- Bileşen sınırları değişince `ARCHITECTURE.md`'yi güncelle.
- Bağımlılıklar veya lisanslar değişince `THIRD_PARTY_NOTICES.md`'yi güncelle.
