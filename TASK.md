# Current Task

_Last updated: 2026-09-17_

## Goal

Establish a fully verified TLS 1.2 IMAP connection from the physical iPad 1 to `mail.olap.com.tr:993` using Mbed TLS 3.6.7, then move the existing minimal IMAP flow from SecureTransport to that transport.

## Current state

The physical iPad is running `iPad1MailBox 0.3-alpha1`.

Confirmed:

- Mbed TLS 3.6.7 builds for armv7 with the iPhoneOS 6.1 SDK.
- The iOS 5 `clock_gettime()` incompatibility is handled through `IMBMBEDTLSPlatform.c` and `mach_absolute_time()`.
- The Mbed TLS probe runs on the physical iPad.
- RNG initialization succeeds.
- SecureTransport diagnostics confirmed that iOS 5.1.1 does not support the server's required ECDHE-ECDSA AES-GCM suites.
- Certificate verification has not been disabled.

Current Mbed TLS probe failure:

```text
RNG seed: OK
CA trust anchor: FAILED
X509 - Signature algorithm (oid) is unsupported
OID - OID is not found
```

The failure happens while parsing the bundled trust anchor, before the TCP/TLS handshake stage of the probe.

## Working hypothesis

The minimal Mbed TLS configuration supports ECDHE-ECDSA for the TLS session but does not yet include the RSA signature/X.509 capability needed to parse and verify an RSA-signed trust anchor such as ISRG Root X1.

This is separate from TLS key exchange: enabling RSA certificate signature verification does **not** mean enabling RSA key exchange.

## Next actions

1. Add only the RSA/X.509 signature support required to parse and verify the trust chain.
2. Keep TLS key exchange restricted to ECDHE-ECDSA and AES-GCM.
3. Rebuild `0.3-alpha1` or bump to the next alpha if behavior changes materially.
4. Run the Mbed TLS probe on the physical iPad.
5. Require all of the following before integrating with `IMBIMAPClient`:
   - CA trust anchor loads
   - TCP connect succeeds
   - TLS handshake succeeds
   - negotiated protocol is TLS 1.2
   - negotiated cipher is an approved ECDHE-ECDSA AES-GCM suite
   - certificate verification succeeds
   - hostname verification succeeds
   - Dovecot IMAP greeting is received
6. After the gate passes, introduce a transport abstraction and move `LOGIN -> SELECT INBOX -> FETCH` onto Mbed TLS.

## Do not

- Do not disable certificate verification.
- Do not accept all roots/certificates.
- Do not re-enable obsolete TLS versions to make the server compatible.
- Do not weaken the mail server cipher configuration for the iPad.
- Do not store credentials outside Keychain.
- Do not mix SMTP work into this task until IMAP transport is stable.

## Definition of done

The task is complete when the physical iPad can display a diagnostic result equivalent to:

```text
RNG seed: OK
CA trust anchor: OK
TCP connect: OK
SNI/hostname: mail.olap.com.tr
TLS handshake: OK
Protocol: TLSv1.2
Cipher: TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384
Certificate verification: OK
IMAP greeting: * OK ... Dovecot ...
```

The exact AES-GCM suite may differ if the server selects the approved 128-bit variant.
