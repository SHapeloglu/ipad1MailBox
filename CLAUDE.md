# CLAUDE.md

Bu dosya, bu proje üzerinde çalışırken Claude'un (Claude Code dahil) izlemesi gereken bağlamı ve kuralları içerir.

## Proje

**iPad1MailBox** — iPad1MailBox is a lightweight mail client for the original iPad (iOS 5.1.1, armv7, 256 MB RAM).

- GitHub: https://github.com/SHapeloglu/ipad1MailBox

## Teknoloji Yığını

- Objective-C / UIKit (iOS, Theos ile derleniyor)
- Bash betikleri

## Önemli Dosyalar

- `Makefile`
- `Resources/Info.plist`
- `main.m`

Mimari ayrıntılar için bkz. `ARCHITECTURE.md`.

## Sık Kullanılan Komutlar

```bash
make bootstrap
make after-install
```

## Kurallar

- Proje eski iOS sürümlerini (iPad 1 / iOS 5.1.1 dahil) hedefliyor olabilir — yeni API kullanmadan önce deployment target'ı kontrol et.
- Derleme ortamını (Xcode veya Theos `Makefile`) değiştirmeden önce mevcut yapı dosyalarını incele; yeni kaynak dosyalarını derleme listesine (`project.pbxproj` / Makefile `*_FILES`) eklemeyi unutma.
- `.env`, parola, token ve API anahtarlarını asla commit etme.
- Her çalışma oturumunun sonunda `session.md`ye kısa kayıt düş; görev durumunu `task.md`de güncelle.
- Önceliklendirilmemiş fikirleri `backlog.md`ye yaz; somutlaşınca `task.md`ye taşı.

## Çalışma Dosyaları

| Dosya | Amaç |
|---|---|
| `ARCHITECTURE.md` | Mimari ve dizin yapısı referansı |
| `TASK.md` | Aktif / devam eden / tamamlanan görevler |
| `BACKLOG.md` | Önceliklendirilmemiş fikir ve teknik borç havuzu |
| `SESSION.md` | Oturum günlüğü — her oturum sonunda güncellenir |
