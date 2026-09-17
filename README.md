# iPad1MailBox

iPad1MailBox is a lightweight mail client for the original iPad (iOS 5.1.1, armv7, 256 MB RAM).

## Current milestone: v0.4-alpha2

- Native Objective-C / UIKit split-view UI
- Account metadata storage + Keychain-backed password storage
- Mbed TLS 3.6.7 verified TLS 1.2 transport
- TLS 1.2 ECDHE/ECDSA + AES-GCM only for the current modern path
- ClientHello SNI for virtual-hosted mail endpoints
- hostname + X.509 certificate-chain verification
- reusable `IMBMBEDTLSTransport` for encrypted connect/read/write/cancel/close behavior
- normal Inbox IMAP flow moved off SecureTransport onto Mbed TLS
- latest 25 message headers via `LOGIN -> SELECT INBOX -> FETCH`
- RFC 2047 Subject/From decoding for Q and Base64 encoded words
- UTF-8 and legacy IANA charset conversion through CoreFoundation, including Turkish ISO-8859-9 when available
- SecureTransport and Mbed TLS diagnostics retained separately
- non-ARC and Theos/iPhoneOS 6.1 SDK compatible

`0.4-alpha1` was physically verified on the original iPad: the real Inbox loaded successfully over the reusable Mbed TLS transport, removing the old normal-operation `OSStatus -9844` blocker. `0.4-alpha2` focuses on making real-world encoded Subject and From headers readable.

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

No Mbed TLS config changed between `0.4-alpha1` and `0.4-alpha2`, so an already-working local vendor tree does not require another bootstrap.

```bash
find . -type f -exec touch {} +
make clean
make package FINALPACKAGE=1
```

Expected package:

```text
packages/com.shapeloglu.ipad1mailbox_0.4-alpha2_iphoneos-arm.deb
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

## RFC 2047 header decoding

`IMBRFC2047Decoder` handles common encoded-word forms used by real mail headers:

```text
=?UTF-8?Q?Yeni_Oturum_Kayd=C4=B1?=
=?UTF-8?B?...?=
=?iso-8859-9?Q?...?=
```

The decoder supports adjacent encoded words and preserves malformed/unsupported content instead of dropping it. It uses a small custom Base64 decoder rather than newer NSData APIs unavailable on iOS 5.1.1.

## TLS diagnostics

The `TLS` button remains available. It shows the legacy iOS 5 SecureTransport cipher set and the independent Mbed TLS probe used during bring-up. Normal Inbox loading no longer depends on SecureTransport.

## Planned suite integration

Attachments will be handed off rather than managed as a second file manager:

- PDF -> iPad1PDFReader
- ZIP / general files -> iPad1Files
- Media -> iPad1Player

Default future attachment storage root:

`/var/mobile/Media/iPad1Files/Mail/Attachments/`

## Security

Passwords must never be written to plist files, `NSUserDefaults`, logs, or SQLite. Account credentials remain in Keychain. The modern TLS path requires certificate-chain verification, hostname verification, SNI for virtual-hosted endpoints, and the configured TLS 1.2 ECDHE-ECDSA AES-GCM suites.
