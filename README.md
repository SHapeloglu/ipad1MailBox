# iPad1MailBox

iPad1MailBox is a lightweight mail client for the original iPad (iOS 5.1.1, armv7, 256 MB RAM).

## Current milestone: v0.3-alpha2

- Native Objective-C / UIKit split-view UI
- Account metadata storage + Keychain-backed password storage
- Minimal IMAP header loader (`LOGIN` -> `SELECT INBOX` -> latest header fetch)
- SecureTransport diagnostics for the iPad's real cipher capabilities
- Mbed TLS 3.6.7 modern TLS 1.2 handshake probe
- TLS 1.2 ECDHE/ECDSA + AES-GCM support independent of the iOS 5 SecureTransport cipher set
- Server hostname/SNI validation path
- Required X.509 certificate verification path using bundled trust anchors
- ISRG Root X2 (ECDSA P-384) trust anchor for the current Let's Encrypt ECDSA hierarchy
- Minimal RSA PKCS#1 v1.5 certificate-signature support for cross-signed CA compatibility; RSA TLS key exchange remains disabled
- Non-ARC and Theos/iPhoneOS 6.1 SDK compatible

The existing CFNetwork/SecureTransport IMAP path is still present for comparison. `v0.3-alpha2` continues validating the modern TLS transport on the physical iPad before the full IMAP state machine is moved onto it.

See `TASK.md` for the exact active diagnostic gate.

## Project documents

- `ARCHITECTURE.md` - stable component boundaries, constraints, trust model, and transport design
- `DECISIONS.md` - architecture decision log and rationale
- `TASK.md` - the single active engineering task and definition of done
- `SESSION.md` - latest development handoff, device result, commands, and resume point
- `BACKLOG.md` - deferred features and future work

When resuming development after a break, read `TASK.md` and `SESSION.md` first.

## Build target

- Device: iPad 1
- OS: iOS 5.1.1
- Architecture: armv7
- Toolchain: Theos + clang
- SDK: iPhoneOS 6.1
- Memory management: non-ARC

## One-time TLS bootstrap

The Mbed TLS source and CA trust anchor are intentionally not committed. Bootstrap them once after cloning/pulling, and rerun bootstrap after changes to `Config/IMBMBEDTLSConfig.h`:

```bash
make bootstrap
```

This pins Mbed TLS to `mbedtls-3.6.7`, installs the project-specific low-memory TLS configuration, and downloads ISRG Root X2 from Let's Encrypt.

## Build

```bash
find . -type f -exec touch {} +
make clean
make package FINALPACKAGE=1
```

Expected package for this milestone:

```text
packages/com.shapeloglu.ipad1mailbox_0.3-alpha2_iphoneos-arm.deb
```

## TLS diagnostics

Open an account and tap `TLS` in the Inbox toolbar. The diagnostics view first prints the iOS 5 SecureTransport cipher list and then runs the Mbed TLS probe on a background thread.

The modern probe reports:

- RNG initialization
- CA trust-anchor loading
- TCP connection
- SNI / hostname setup
- TLS handshake result
- negotiated TLS version and cipher
- certificate verification result
- peer subject / issuer
- first Dovecot IMAP greeting line

No certificate-verification bypass is used.

## Planned suite integration

Attachments will be handed off rather than managed as a second file manager:

- PDF -> iPad1PDFReader
- ZIP / general files -> iPad1Files
- Media -> iPad1Player

Default future attachment storage root:

`/var/mobile/Media/iPad1Files/Mail/Attachments/`

## Security

Passwords must never be written to plist files, `NSUserDefaults`, logs, or SQLite. Account credentials are stored in Keychain; non-secret account metadata may be persisted separately. The modern TLS path requires X.509 verification and hostname/SNI checking.
