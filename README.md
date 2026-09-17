# iPad1MailBox

iPad1MailBox is a lightweight mail client for the original iPad (iOS 5.1.1, armv7, 256 MB RAM).

## Current milestone: v0.4-alpha1

- Native Objective-C / UIKit split-view UI
- Account metadata storage + Keychain-backed password storage
- Mbed TLS 3.6.7 verified TLS 1.2 transport
- TLS 1.2 ECDHE/ECDSA + AES-GCM only for the current modern path
- ClientHello SNI for virtual-hosted mail endpoints
- hostname + X.509 certificate-chain verification
- ISRG Root X1 trust anchor
- RSA PKCS#1 v1.5 support for certificate-chain verification only; RSA TLS key exchange remains disabled
- reusable `IMBMBEDTLSTransport` for encrypted connect/read/write/cancel/close behavior
- normal Inbox IMAP flow moved off SecureTransport onto Mbed TLS
- latest 25 message headers via `LOGIN -> SELECT INBOX -> FETCH`
- SecureTransport and Mbed TLS diagnostics retained separately
- non-ARC and Theos/iPhoneOS 6.1 SDK compatible

The full Mbed TLS gate has already passed on the physical iPad 1 against `mail.olap.com.tr:993`: TLS 1.2 handshake, SNI, hostname verification, certificate-chain verification, AES-256-GCM cipher negotiation, and Dovecot greeting all succeeded.

`0.4-alpha1` is the first functional build that uses that verified transport for normal Inbox loading.

## Project documents

- `ARCHITECTURE.md` - component boundaries, constraints, trust model, and transport design
- `DECISIONS.md` - architecture decision log
- `TASK.md` - the single active engineering task and definition of done
- `SESSION.md` - latest development handoff and test commands
- `BACKLOG.md` - deferred features and future work

When resuming development, read `TASK.md` and `SESSION.md` first.

## Build target

- Device: iPad 1
- OS: iOS 5.1.1
- Architecture: armv7
- Toolchain: Theos + clang
- SDK: iPhoneOS 6.1
- Memory management: non-ARC

## Mbed TLS bootstrap

Mbed TLS sources and the current trust anchor are bootstrapped locally:

```bash
make bootstrap
```

This pins Mbed TLS to `mbedtls-3.6.7`, installs the project configuration, and downloads ISRG Root X1.

## Build

```bash
find . -type f -exec touch {} +
make clean
make package FINALPACKAGE=1
```

Expected package:

```text
packages/com.shapeloglu.ipad1mailbox_0.4-alpha1_iphoneos-arm.deb
```

## Normal Inbox transport

`IMBIMAPClient` performs its protocol work on a background thread and delegates encrypted network I/O to `IMBMBEDTLSTransport`.

Current flow:

```text
verified TLS connect
-> Dovecot greeting
-> LOGIN
-> SELECT INBOX
-> read EXISTS
-> FETCH latest 25 headers
-> LOGOUT
```

Current safety bounds:

- 20-second command deadline
- 512 KB maximum accumulated IMAP response
- generation-token cancellation so stale refresh results are ignored
- active socket shutdown on cancel

## TLS diagnostics

The `TLS` button remains available. It shows the legacy iOS 5 SecureTransport cipher set and the independent Mbed TLS probe used during bring-up.

Diagnostics do not bypass certificate or hostname verification.

## Planned suite integration

Attachments will be handed off rather than managed as a second file manager:

- PDF -> iPad1PDFReader
- ZIP / general files -> iPad1Files
- Media -> iPad1Player

Default future attachment storage root:

`/var/mobile/Media/iPad1Files/Mail/Attachments/`

## Security

Passwords must never be written to plist files, `NSUserDefaults`, logs, or SQLite. Account credentials remain in Keychain. The modern TLS path requires certificate-chain verification, hostname verification, SNI for virtual-hosted endpoints, and the configured TLS 1.2 ECDHE-ECDSA AES-GCM suites.
