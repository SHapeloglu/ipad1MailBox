# iPad1MailBox

iPad1MailBox is a lightweight mail client for the original iPad (iOS 5.1.1, armv7, 256 MB RAM).

## v0.1-alpha1 goals

- Native Objective-C / UIKit UI
- iPad-first split layout
- Add and store mail account settings
- Credentials stored in iOS Keychain, never in plist/NSUserDefaults
- Inbox shell ready for IMAP integration
- Compose shell ready for SMTP integration
- Non-ARC and Theos/iPhoneOS 6.1 SDK compatible
- Low-memory design: message headers are paged; message bodies and attachments will be loaded on demand

## Build target

- Device: iPad 1
- OS: iOS 5.1.1
- Architecture: armv7
- Toolchain: Theos + clang
- SDK: iPhoneOS 6.1
- Memory management: non-ARC

## Build

```bash
make clean
make package FINALPACKAGE=1
```

## Current status

`v0.1-alpha1` is the bootstrap milestone. It provides the native application structure, account setup UI, Keychain-backed account storage, inbox placeholder, and compose placeholder. Real IMAP/SMTP transport is intentionally isolated for the next milestone so UI/device stability can be verified first.

## Planned suite integration

Attachments will be handed off rather than managed as a second file manager:

- PDF -> iPad1PDFReader
- ZIP / general files -> iPad1Files
- Media -> iPad1Player

Default future attachment storage root:

`/var/mobile/Media/iPad1Files/Mail/Attachments/`

## Security

Passwords must never be written to plist files, `NSUserDefaults`, logs, or SQLite. Account credentials are stored in Keychain; non-secret account metadata may be persisted separately.
