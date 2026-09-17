# Current Task

_Last updated: 2026-09-17_

## Goal

Validate the first normal Inbox load over the reusable Mbed TLS transport on the physical iPad 1.

## TLS gate: PASSED

`0.3-alpha4` proved the full modern TLS path on-device against `mail.olap.com.tr:993`:

```text
RNG seed: OK
CA trust anchor: ISRG Root X1 loaded
TCP connect: OK
SNI ClientHello extension: ENABLED
SNI/hostname: mail.olap.com.tr
all verification depths: flags=0x00000000
TLS handshake: OK
Protocol: TLSv1.2
Cipher: TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384
Certificate verification: OK
IMAP greeting: * OK ... Dovecot DA ready.
```

## 0.4-alpha1 implementation prepared

Normal IMAP traffic is now routed through a new reusable class:

```text
IMBIMAPClient
    -> IMBMBEDTLSTransport
        -> Mbed TLS 3.6.7
        -> TCP/TLS
```

`IMBMBEDTLSTransport` owns:

- verified TLS 1.2 connection setup
- ISRG Root X1 loading
- SNI + hostname verification
- X.509 verification
- encrypted read/write
- read/write/handshake timeouts
- cancellation/socket shutdown
- clean TLS close

`IMBIMAPClient` now runs the protocol flow on a background thread and preserves the existing command/parser behavior:

```text
greeting
-> LOGIN
-> SELECT INBOX
-> latest 25 header FETCH
-> LOGOUT
```

Safety bounds:

- 20-second command timeout
- 512 KB maximum accumulated response
- stale/cancelled worker results are discarded using a generation token
- credentials are never logged or persisted outside Keychain

## Next actions

1. Pull `0.4-alpha1`.
2. No new Mbed TLS config change was made after the already-tested `0.3-alpha4` config, but running `make bootstrap` is safe and recommended if the local vendor config may be stale.
3. Build the package.
4. Install on the physical iPad.
5. Open the existing `info@olap.com.tr` account.
6. Confirm that Inbox loads without `OSStatus -9844`.
7. Confirm that up to 25 latest headers appear.
8. Test refresh once to exercise cancellation/reconnect.
9. If build/runtime errors occur, fix only the transport/IMAP integration before starting body/MIME/SMTP work.

## Acceptance criteria

- normal Inbox no longer uses SecureTransport
- verified Mbed TLS connection succeeds
- `LOGIN` succeeds
- `SELECT INBOX` succeeds
- latest message headers are displayed
- refresh does not leave a stale result/socket
- TLS/IMAP errors surface to the UI without credentials
- TLS diagnostics remain available separately

## Do not

- Do not disable certificate verification.
- Do not weaken the server cipher configuration.
- Do not enable RSA key-exchange suites.
- Do not store credentials outside Keychain.
- Do not add SMTP, MIME body parsing, attachments, or offline cache until this Inbox path is stable.

## Definition of done

The task is complete when the physical iPad opens Inbox and displays the latest IMAP message headers over `IMBMBEDTLSTransport`, then refreshes successfully, with no legacy SecureTransport error in normal operation.
