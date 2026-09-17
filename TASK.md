# Current Task

_Last updated: 2026-09-17_

## Goal

Establish a fully verified TLS 1.2 IMAP connection from the physical iPad 1 to `mail.olap.com.tr:993` using Mbed TLS 3.6.7, then move the existing minimal IMAP flow from SecureTransport to that transport.

## Current state

The physical iPad is running `iPad1MailBox 0.3-alpha1`. The next build is `0.3-alpha2`.

Confirmed:

- Mbed TLS 3.6.7 builds for armv7 with the iPhoneOS 6.1 SDK.
- The iOS 5 `clock_gettime()` incompatibility is handled through `IMBMBEDTLSPlatform.c` and `mach_absolute_time()`.
- The Mbed TLS probe runs on the physical iPad.
- RNG initialization succeeds.
- SecureTransport cannot negotiate the server's required ECDHE-ECDSA AES-GCM suites.
- Certificate and hostname verification remain mandatory.

Previous probe failure:

```text
RNG seed: OK
CA trust anchor: FAILED
X509 - Signature algorithm (oid) is unsupported
OID - OID is not found
```

The failure occurred while parsing the bundled ISRG Root X1 certificate before TCP/TLS handshake.

## Current implementation change

`0.3-alpha2` keeps **ISRG Root X1** as the trust anchor and adds the minimum RSA PKCS#1 v1.5 X.509 capability needed to parse and validate the current Let's Encrypt chain.

The root uses a 4096-bit RSA key, so `MBEDTLS_MPI_MAX_SIZE` is raised from the earlier ECC-only 48-byte limit to 512 bytes.

Important distinction:

- TLS key exchange remains **ECDHE-ECDSA only**.
- Allowed TLS ciphers remain **AES-GCM ECDHE-ECDSA only**.
- RSA support is for X.509 certificate signatures/trust-chain validation, not RSA key exchange.
- Certificate and hostname verification remain mandatory.

## Next actions

1. Pull `0.3-alpha2`.
2. Run `make bootstrap` so the updated Mbed TLS config is installed.
3. Rebuild and install on the physical iPad.
4. Run the Mbed TLS probe.
5. Require all of the following before integrating with `IMBIMAPClient`:
   - ISRG Root X1 loads
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
- Do not re-enable obsolete TLS versions.
- Do not weaken the mail server cipher configuration.
- Do not enable RSA key-exchange suites.
- Do not store credentials outside Keychain.
- Do not mix SMTP work into this task until IMAP transport is stable.

## Definition of done

```text
RNG seed: OK
CA trust anchor: ISRG Root X1 loaded
TCP connect: OK
SNI/hostname: mail.olap.com.tr
TLS handshake: OK
Protocol: TLSv1.2
Cipher: TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384
Certificate verification: OK
IMAP greeting: * OK ... Dovecot ...
```

The exact AES-GCM suite may differ if the server selects the approved 128-bit variant.
