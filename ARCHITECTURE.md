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

`IMBIMAPClient` owns the minimum IMAP state flow required for the current mailbox milestone:

1. connect through the transport
2. wait for server greeting
3. `LOGIN`
4. `SELECT INBOX`
5. read `EXISTS`
6. fetch the latest 25 message headers
7. close cleanly

Starting with `0.4-alpha1`, normal IMAP operation no longer uses CFStream/SecureTransport. It executes on a background thread and delegates encrypted network I/O to `IMBMBEDTLSTransport`.

The IMAP parser remains separate from TLS so SMTP can later reuse the same transport without duplicating cryptographic/network code.

### TLS transport

#### `IMBMBEDTLSTransport`

Reusable verified TLS transport for normal mail traffic.

Responsibilities:

- TCP connect
- Mbed TLS context/RNG/trust-anchor setup
- TLS 1.2 handshake
- ClientHello SNI
- hostname verification
- X.509 chain verification
- encrypted read/write
- bounded timeouts
- cancellation by shutting down the active socket
- clean close

The transport does not know about IMAP commands, usernames, passwords, mailboxes, MIME, or SMTP semantics.

#### Mbed TLS 3.6.7

- vendored at build time under `Vendor/mbedtls`
- configured by `Config/IMBMBEDTLSConfig.h`
- bootstrapped by `scripts/bootstrap_mbedtls.sh`
- iOS 5 monotonic time supplied by `Classes/IMBMBEDTLSPlatform.c`
- TLS 1.2 only for the current modern transport
- approved suites limited to ECDHE-ECDSA + AES-GCM
- RSA enabled only for X.509 chain-signature verification
- ClientHello SNI enabled explicitly

The modern TLS path has been proven on the physical iPad 1 against `mail.olap.com.tr:993` with full certificate/hostname verification and a Dovecot greeting.

#### Diagnostics

- `IMBTLSDiagnostics` remains for observing the legacy iOS 5 SecureTransport cipher set.
- `IMBModernTLSProbe` remains as a physical-device Mbed TLS diagnostic while transport integration stabilizes.

SecureTransport is no longer the intended normal IMAP transport for modern servers.

## Trust model

The application authenticates the server hostname and certificate chain. The current bootstrap includes ISRG Root X1 in `Resources` for the validated test server chain.

Trust anchors can be expanded for additional providers, but unsupported chains must be solved by adding the required trusted roots/algorithms rather than bypassing verification.

## Concurrency and cancellation

`IMBIMAPClient` performs a fetch operation on a background thread. Each operation receives a generation token. Refresh/cancel increments the generation and cancels the currently active transport.

A stale worker result is discarded on the main thread. The active Mbed TLS socket is shut down on cancellation so a blocked read can unwind quickly.

## Memory and response limits

- initial Inbox page: latest 25 messages
- IMAP command timeout: 20 seconds
- maximum accumulated IMAP response for this milestone: 512 KB
- Mbed TLS record buffers remain bounded in project configuration
- full bodies/attachments are not fetched during Inbox listing

## Suite ownership and hand-off

`iPad1MailBox` owns accounts, folders, messages, compose/send, MIME interpretation, and attachment hand-off. It must not become a general file manager.

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

## Milestones

### v0.1

Application shell, split view, account setup, Keychain, compose shell.

### v0.2

Minimal IMAP parser, Inbox headers, connection diagnostics, SecureTransport capability investigation.

### v0.3

Modern Mbed TLS transport validation on the physical iPad.

### v0.4

Reusable verified Mbed TLS transport and migration of normal IMAP header loading away from SecureTransport.

### After transport stability

- full message body loading
- RFC 2047 header decoding
- MIME parsing
- SMTP send using the reusable transport
- reply/forward
- Sent/Drafts/Trash
- flags
- attachments and suite routing
- bounded metadata cache
