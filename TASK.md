# Current Task

_Last updated: 2026-09-17_

## Goal

Establish a fully verified TLS 1.2 IMAP connection from the physical iPad 1 to `mail.olap.com.tr:993` using Mbed TLS 3.6.7, then move the existing minimal IMAP flow from SecureTransport to that transport.

## Current state

The physical iPad has now tested `iPad1MailBox 0.3-alpha3`. The next build is `0.3-alpha4`.

Confirmed on the physical device:

- Mbed TLS 3.6.7 builds for armv7 with the iPhoneOS 6.1 SDK.
- RNG initialization succeeds.
- ISRG Root X1 parses successfully.
- TCP connection to `mail.olap.com.tr:993` succeeds.
- Certificate-chain verification for depths 1-4 reports no flags.
- The only failure in `0.3-alpha3` is hostname mismatch at leaf depth 0.
- Certificate and hostname verification remain mandatory.

## Root cause identified from 0.3-alpha3

The leaf certificate actually received by Mbed TLS on the iPad is the hosting provider default certificate, not the certificate previously observed with OpenSSL when SNI was sent.

Physical-device trace:

```text
Verify callback: depth=4 flags=0x00000000
Verify callback: depth=3 flags=0x00000000
Verify callback: depth=2 flags=0x00000000
Verify callback: depth=1 flags=0x00000000
Verify callback: depth=0 flags=0x00000004

Peer certificate as parsed by Mbed TLS:
  subject name  : CN=da2.mirahosting.com
  subject alt name:
      dNSName : da2.mirahosting.com
```

This explains `MBEDTLS_X509_BADCERT_CN_MISMATCH`: the received certificate genuinely does not contain `mail.olap.com.tr`.

The application already called:

```text
mbedtls_ssl_set_hostname(..., "mail.olap.com.tr")
```

but the project configuration did not define:

```text
MBEDTLS_SSL_SERVER_NAME_INDICATION
```

In Mbed TLS 3.6.7, the TLS ClientHello `server_name` extension is emitted only when `MBEDTLS_SSL_SERVER_NAME_INDICATION` is enabled. Therefore hostname verification was configured, but SNI was not actually transmitted to the virtual-hosted mail server. The server consequently returned its default `da2.mirahosting.com` certificate.

## 0.3-alpha4 change

Enable:

```text
MBEDTLS_SSL_SERVER_NAME_INDICATION
```

Keep:

- `MBEDTLS_SSL_VERIFY_REQUIRED`
- hostname verification through `mbedtls_ssl_set_hostname()`
- ECDHE-ECDSA + AES-GCM only
- ISRG Root X1 trust anchor
- RSA only for X.509 chain verification, not RSA key exchange

The TLS probe now explicitly reports whether ClientHello SNI support is compiled in:

```text
SNI ClientHello extension: ENABLED
```

## Next actions

1. Pull `0.3-alpha4`.
2. Run `make bootstrap` because `Config/IMBMBEDTLSConfig.h` changed.
3. Rebuild and install on the physical iPad.
4. Run `Inbox -> TLS`.
5. Confirm:
   - `SNI ClientHello extension: ENABLED`
   - leaf certificate is for `olap.com.tr` / includes `mail.olap.com.tr` SAN
   - all verification depths have zero flags
   - TLS handshake succeeds
   - protocol is TLS 1.2
   - cipher is an approved ECDHE-ECDSA AES-GCM suite
   - certificate verification succeeds
   - Dovecot greeting is received
6. Only after that gate passes, move `LOGIN -> SELECT INBOX -> FETCH` onto the Mbed TLS transport.

## Do not

- Do not disable certificate verification.
- Do not clear `MBEDTLS_X509_BADCERT_CN_MISMATCH`.
- Do not accept the provider default certificate.
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
SNI ClientHello extension: ENABLED
SNI/hostname: mail.olap.com.tr
TLS handshake: OK
Protocol: TLSv1.2
Cipher: TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384
Certificate verification: OK
IMAP greeting: * OK ... Dovecot ...
```

The exact AES-GCM suite may differ if the server selects the approved 128-bit variant.
