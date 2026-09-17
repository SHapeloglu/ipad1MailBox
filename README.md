# iPad1MailBox

iPad1MailBox is a lightweight mail client for the original iPad (iOS 5.1.1, armv7, 256 MB RAM).

## Current milestone: v0.3-alpha4

- Native Objective-C / UIKit split-view UI
- Account metadata storage + Keychain-backed password storage
- Minimal IMAP header loader (`LOGIN` -> `SELECT INBOX` -> latest header fetch)
- SecureTransport diagnostics for the iPad's real cipher capabilities
- Mbed TLS 3.6.7 modern TLS 1.2 handshake probe
- TLS 1.2 ECDHE/ECDSA + AES-GCM support independent of the iOS 5 SecureTransport cipher set
- Client-side SNI (`server_name`) support for virtual-hosted mail endpoints
- Server hostname validation through `mbedtls_ssl_set_hostname()`
- Required X.509 certificate verification path
- ISRG Root X1 trust anchor
- RSA PKCS#1 v1.5 support for certificate-chain verification only; RSA TLS key exchange remains disabled
- Read-only certificate verification trace for peer subject/SAN diagnostics
- Non-ARC and Theos/iPhoneOS 6.1 SDK compatible

The existing CFNetwork/SecureTransport IMAP path is still present for comparison. `v0.3-alpha4` continues validating the modern TLS transport on the physical iPad before the full IMAP state machine is moved onto it.

The `0.3-alpha3` physical-device trace showed that the iPad received the hosting provider default certificate (`CN=da2.mirahosting.com`, SAN `da2.mirahosting.com`). The application was already validating against `mail.olap.com.tr`, but the minimal Mbed TLS configuration had not enabled the ClientHello SNI extension. `0.3-alpha4` enables `MBEDTLS_SSL_SERVER_NAME_INDICATION` so the virtual-hosted IMAP server can select the correct certificate without weakening any verification rule.

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

This pins Mbed TLS to `mbedtls-3.6.7`, installs the project-specific TLS configuration, and downloads ISRG Root X1 from Let's Encrypt.

## Build

```bash
find . -type f -exec touch {} +
make clean
make package FINALPACKAGE=1
```

Expected package for this milestone:

```text
packages/com.shapeloglu.ipad1mailbox_0.3-alpha4_iphoneos-arm.deb
```

## TLS diagnostics

Open an account and tap `TLS` in the Inbox toolbar. The diagnostics view first prints the iOS 5 SecureTransport cipher list and then runs the Mbed TLS probe on a background thread. When the modern probe finishes, the view scrolls to its result automatically.

The modern probe reports:

- RNG initialization
- CA trust-anchor loading
- TCP connection
- ClientHello SNI compile status
- SNI / hostname setup
- TLS handshake result
- certificate verification depth/flags
- peer certificate information as parsed by Mbed TLS, including SAN data
- negotiated TLS version and cipher when the handshake succeeds
- first Dovecot IMAP greeting line after full verification succeeds

No certificate-verification bypass is used.

## Planned suite integration

Attachments will be handed off rather than managed as a second file manager:

- PDF -> iPad1PDFReader
- ZIP / general files -> iPad1Files
- Media -> iPad1Player

Default future attachment storage root:

`/var/mobile/Media/iPad1Files/Mail/Attachments/`

## Security

Passwords must never be written to plist files, `NSUserDefaults`, logs, or SQLite. Account credentials are stored in Keychain; non-secret account metadata may be persisted separately. The modern TLS path requires X.509 verification, hostname checking, and SNI for virtual-hosted endpoints.
