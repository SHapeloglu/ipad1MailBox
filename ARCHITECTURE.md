# iPad1MailBox Architecture

## Purpose

iPad1MailBox is a lightweight mail client for the original iPad. The project favors predictable memory use, explicit ownership, small dependencies, and compatibility with iOS 5.1.1 over modern-platform convenience APIs.

## Hard constraints

- Device: original iPad
- OS: iOS 5.1.1
- Architecture: armv7
- RAM: 256 MB
- Objective-C / UIKit
- non-ARC memory management
- Theos + iPhoneOS 6.1 SDK
- no dependency on modern iOS APIs

## Architectural rules

1. UI code must not own protocol or cryptographic details.
2. Passwords belong in Keychain only. Never store passwords in plist, `NSUserDefaults`, SQLite, logs, or diagnostics.
3. Certificate verification must remain enabled. Do not use `AllowsAnyRoot`, accept-all verification callbacks, or other trust bypasses.
4. Fetch mailbox content incrementally. Do not load a whole mailbox, large message body, or attachment into memory unnecessarily.
5. iPad1MailBox owns mail functionality only. General file management belongs to iPad1Files and media/document rendering is handed to the appropriate suite application.

## Layers

### UI

- `IMBAppDelegate` - application bootstrap and split-view setup
- `IMBInboxViewController` - account/mailbox sidebar
- `IMBAccountSetupViewController` - account configuration
- `IMBMessageListViewController` - Inbox state, header list, refresh, TLS diagnostics
- `IMBComposeViewController` - compose shell

### Account and credential storage

- `IMBAccount` - non-secret IMAP/SMTP configuration
- `IMBAccountStore` - metadata persistence and Keychain credential storage
- `entitlements.plist` - application/keychain access group required by iOS 5 code signing

### IMAP protocol

`IMBIMAPClient` currently implements the minimum IMAP flow required for the first mailbox milestone:

1. connect
2. wait for server greeting
3. `LOGIN`
4. `SELECT INBOX`
5. read `EXISTS`
6. fetch the latest message headers in a bounded page

The current implementation uses the legacy CFStream/SecureTransport path. That path is retained while the replacement TLS transport is validated, but it is not expected to remain the primary TLS implementation for modern servers.

### TLS transport

Two TLS paths currently exist for different purposes.

#### Apple SecureTransport

- used by the original IMAP transport
- exposed through `IMBTLSDiagnostics` for device cipher inspection
- confirmed on iOS 5.1.1 to lack the modern ECDHE-ECDSA AES-GCM suites required by the current test server
- must not be weakened by disabling certificate validation

#### Mbed TLS 3.6.7

- vendored at build time under `Vendor/mbedtls`
- configured by `Config/IMBMBEDTLSConfig.h`
- bootstrapped by `scripts/bootstrap_mbedtls.sh`
- iOS 5 monotonic time supplied by `Classes/IMBMBEDTLSPlatform.c`
- probed by `IMBModernTLSProbe`
- target capability: TLS 1.2, ECDHE-ECDSA, AES-GCM, SNI, X.509 verification

The Mbed TLS probe is intentionally separate from `IMBIMAPClient` until TCP, handshake, certificate verification, and IMAP greeting all pass on the physical iPad. After that gate passes, `IMBIMAPClient` will be moved onto the modern TLS transport.

## Trust model

The application must authenticate the server hostname and certificate chain.

Current test trust bootstrap includes an ISRG root certificate in `Resources`. Trust anchors may be expanded when required by real certificate chains, but unknown or unsupported signature algorithms must be fixed by enabling the necessary cryptographic/X.509 support rather than bypassing verification.

## Memory policy

- page message headers; initial target is approximately 25 messages
- fetch full body only when a message is opened
- fetch attachments only on explicit user action
- release body and attachment buffers aggressively
- keep TLS buffers deliberately bounded for the 256 MB device
- avoid heavyweight HTML/MIME processing until plain-text and transport stability are proven

## Suite ownership and hand-off

`iPad1MailBox` owns accounts, folders, messages, compose/send, MIME interpretation, and attachment hand-off.

It must not become a general file manager.

Planned hand-off targets:

- PDF -> iPad1PDFReader
- ZIP and general files -> iPad1Files
- video/audio -> iPad1Player

Planned shared attachment root:

`/var/mobile/Media/iPad1Files/Mail/Attachments/`

## Build flow

First-time or Mbed TLS configuration refresh:

```bash
make bootstrap
```

Build package:

```bash
find . -type f -exec touch {} +
make clean
make package FINALPACKAGE=1
```

## Milestone direction

### v0.1

Application shell, split view, account setup, Keychain, compose shell.

### v0.2

Minimal IMAP client, Inbox headers, connection diagnostics, SecureTransport capability investigation.

### v0.3

Modern TLS transport validation on physical iPad, then migration of IMAP onto Mbed TLS.

### After transport stability

- full message body loading
- RFC 2047 header decoding
- MIME parsing
- SMTP send
- reply/forward
- Sent/Drafts/Trash
- flags
- attachments and suite routing
- bounded metadata cache
