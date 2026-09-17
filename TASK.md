# Current Task

_Last updated: 2026-09-17_

## Goal

Move the existing minimal IMAP flow from the legacy SecureTransport path onto the now-proven Mbed TLS 3.6.7 transport on the physical iPad 1.

## TLS gate: PASSED on physical iPad

`iPad1MailBox 0.3-alpha4` successfully completed the modern TLS probe against:

```text
mail.olap.com.tr:993
implicit TLS / IMAPS
```

Confirmed on-device:

```text
RNG seed: OK
CA trust anchor: ISRG Root X1 loaded
TCP connect: OK
SNI ClientHello extension: ENABLED
SNI/hostname: mail.olap.com.tr
Verify callback: depth=4 flags=0x00000000
Verify callback: depth=3 flags=0x00000000
Verify callback: depth=2 flags=0x00000000
Verify callback: depth=1 flags=0x00000000
Verify callback: depth=0 flags=0x00000000
TLS handshake: OK
Protocol: TLSv1.2
Cipher: TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384
Certificate verification: OK
IMAP greeting: * OK [CAPABILITY IMAP4rev1 SASL-IR LOGIN-REFERRALS ID ENABLE IDLE LITERAL+ AUTH=PLAIN] Dovecot DA ready.
```

The server now presents the expected `olap.com.tr` certificate and its SAN list includes `mail.olap.com.tr`.

## Current task

Introduce a reusable Mbed TLS transport and route the existing IMAP state machine through it.

The first functional target is deliberately narrow:

```text
TCP/TLS connect
-> verified TLS 1.2 session
-> read Dovecot greeting
-> LOGIN
-> SELECT INBOX
-> UID/header fetch for latest messages
-> close cleanly
```

The existing `IMBIMAPClient` parsing behavior should be preserved where possible. The transport layer should own encrypted read/write/connect/close behavior so SMTP can later reuse it without duplicating TLS code.

## Implementation plan

1. Extract the proven Mbed TLS setup from `IMBModernTLSProbe` into a reusable transport class/module.
2. Keep `IMBModernTLSProbe` as diagnostics, but have it reuse the same transport primitives where practical.
3. Replace the legacy CFNetwork/SecureTransport socket path in `IMBIMAPClient` with the Mbed TLS transport.
4. Preserve the existing IMAP command sequence and parser first; avoid adding MIME/body/SMTP work in the same change.
5. Add bounded read buffers and explicit timeouts suitable for the 256 MB iPad 1.
6. Keep certificate verification, hostname verification, SNI, TLS 1.2, and the approved ECDHE-ECDSA AES-GCM suites mandatory.
7. Test on the physical iPad with the existing `info@olap.com.tr` account.

## Acceptance criteria

The Inbox screen must load message headers without the old SecureTransport `OSStatus -9844` error.

Required behavior:

- password still comes only from Keychain
- TLS certificate and hostname verification are mandatory
- IMAP `LOGIN` succeeds
- `SELECT INBOX` succeeds
- latest message headers are returned to the existing table view
- cancellation/refresh does not leave a live socket behind
- connection and TLS errors are surfaced clearly
- no credential data is written to logs

## Do not

- Do not disable certificate verification.
- Do not weaken the mail server cipher configuration.
- Do not enable RSA key-exchange suites.
- Do not store credentials outside Keychain.
- Do not add SMTP, MIME body parsing, attachments, or offline cache until the Mbed TLS IMAP transport is stable.
- Do not remove TLS diagnostics yet; they are useful while the new transport is being integrated.

## Definition of done

The active task is complete when the physical iPad opens Inbox and successfully displays the latest IMAP message headers over the verified Mbed TLS transport, with the legacy SecureTransport path no longer required for normal IMAP operation.
