# Session Handoff

_Last updated: 2026-09-17_

## Where we are

The modern TLS bring-up phase is complete on the physical iPad 1. `iPad1MailBox 0.3-alpha4` successfully established and verified a TLS 1.2 IMAPS connection to the production-style endpoint.

Latest tested build:

```text
iPad1MailBox 0.3-alpha4
```

Target server:

```text
mail.olap.com.tr:993
implicit TLS / IMAPS
```

## What is now proven on the physical iPad

### Keychain

The earlier `errSecInteractionNotAllowed (-25308)` issue was fixed with application identifier and keychain access group entitlements. Keychain storage works.

### SecureTransport limitation

The physical iPad's iOS 5.1.1 SecureTransport cannot negotiate the modern ECDHE-ECDSA AES-GCM suites required by the server. Older CBC suites supported by the device are rejected by the server.

### Mbed TLS 3.6.7

Mbed TLS compiles into the armv7 application with the iPhoneOS 6.1 SDK. iOS 5 timer compatibility is provided through `MBEDTLS_PLATFORM_MS_TIME_ALT`, `MBEDTLS_PLATFORM_C`, and `mach_absolute_time()`.

### Trust chain

ISRG Root X1 parses and verifies after enabling RSA PKCS#1 v1.5 certificate-signature support and raising `MBEDTLS_MPI_MAX_SIZE` to 512 for the 4096-bit root key. RSA TLS key exchange remains disabled.

### SNI / hostname

`0.3-alpha3` showed that without `MBEDTLS_SSL_SERVER_NAME_INDICATION`, the server returned its default `da2.mirahosting.com` certificate. `0.3-alpha4` enabled ClientHello SNI and retained `mbedtls_ssl_set_hostname()` for hostname verification.

The server then presented the expected certificate:

```text
subject name: CN=olap.com.tr
subject alt name includes:
  olap.com.tr
  pop.olap.com.tr
  smtp.olap.com.tr
  mail.olap.com.tr
  www.olap.com.tr
```

All verification depths now report zero flags.

## Successful 0.3-alpha4 device result

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

This completes the TLS validation gate defined for `IMBModernTLSProbe`.

## Next engineering step

Move the existing minimal IMAP flow from SecureTransport to a reusable Mbed TLS transport:

```text
connect/TLS
-> greeting
-> LOGIN
-> SELECT INBOX
-> latest UID/header fetch
```

Preserve the existing IMAP parser where practical. Do not add SMTP/MIME/attachments in the same integration step.

## Important code locations

- `Classes/IMBIMAPClient.m` - current legacy IMAP command/parser flow
- `Classes/IMBTLSDiagnostics.m` - SecureTransport diagnostics
- `Classes/IMBModernTLSProbe.m` - proven Mbed TLS device probe
- `Classes/IMBMBEDTLSPlatform.c` - iOS 5 timer compatibility
- `Config/IMBMBEDTLSConfig.h` - Mbed TLS feature set including ClientHello SNI
- `scripts/bootstrap_mbedtls.sh` - Mbed TLS + ISRG Root X1 bootstrap
- `Makefile` - armv7 build

## Resume here

Read `TASK.md` first. The active task is no longer TLS diagnosis; it is Mbed TLS IMAP transport integration. The physical TLS gate has passed, so normal Inbox traffic can now be moved off SecureTransport.
