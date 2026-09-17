# Architecture Decisions

_Last updated: 2026-09-17_

This is a lightweight decision log. Record choices that would otherwise be easy to revisit without remembering the original constraints.

## ADR-001 - Target the original iPad explicitly

**Status:** Accepted

The project targets iPad 1, iOS 5.1.1, armv7, 256 MB RAM, non-ARC Objective-C, Theos, and the iPhoneOS 6.1 SDK.

**Consequences:**

- modern Apple networking APIs cannot be assumed
- memory use must stay bounded
- dependencies must compile with the old SDK/toolchain
- physical-device testing is required

## ADR-002 - Store mail passwords in Keychain only

**Status:** Accepted

Account metadata may be persisted normally, but passwords must be stored in iOS Keychain.

The application is signed with the required application identifier and keychain access group entitlements.

**Rejected alternatives:** plist, `NSUserDefaults`, SQLite, logs, custom encrypted files.

## ADR-003 - Do not weaken TLS verification for compatibility

**Status:** Accepted

Certificate and hostname verification remain mandatory.

Do not use accept-all verification callbacks, `AllowsAnyRoot`, disabled peer verification, or obsolete TLS versions merely to make an old device connect.

## ADR-004 - SecureTransport is diagnostic/legacy, not the long-term modern TLS path

**Status:** Accepted

Physical-device diagnostics showed that iOS 5.1.1 SecureTransport lacks the ECDHE-ECDSA AES-GCM cipher suites currently required by the test mail server. The server also rejects the older ECDHE-ECDSA CBC suites available on the iPad.

**Decision:** Keep SecureTransport long enough to preserve diagnostics, but move modern server connectivity to a bundled TLS implementation.

## ADR-005 - Use Mbed TLS 3.6.7 for the modern TLS transport

**Status:** Accepted for current development

Mbed TLS 3.6.7 is compiled into the application and configured for TLS 1.2, ECDHE-ECDSA, AES-GCM, SNI, X.509 verification, and a secure RNG.

## ADR-006 - Validate Mbed TLS independently before replacing IMAP transport

**Status:** Accepted

`IMBModernTLSProbe` is a deliberate integration gate. The replacement transport is not connected to `IMBIMAPClient` until the physical iPad proves RNG, trust-anchor parsing, TCP, TLS handshake, hostname verification, certificate verification, approved cipher negotiation, and the IMAP greeting.

## ADR-007 - Supply monotonic time with `mach_absolute_time()`

**Status:** Accepted

Mbed TLS 3.6.7's default Unix-like millisecond timer path selected `clock_gettime()`, which is unavailable for the iOS 5 target. `MBEDTLS_PLATFORM_MS_TIME_ALT` plus `IMBMBEDTLSPlatform.c` provides `mbedtls_ms_time()` using `mach_absolute_time()`.

## ADR-008 - Keep mail application ownership narrow

**Status:** Accepted

iPad1MailBox owns mail accounts, folders, messages, compose/send, MIME interpretation, and attachment hand-off. It does not become a second file manager or media player.

Planned hand-off:

- PDF -> iPad1PDFReader
- ZIP/general files -> iPad1Files
- audio/video -> iPad1Player

## ADR-009 - Optimize Mbed TLS only after the required feature set works

**Status:** Accepted

During bring-up, the Makefile may compile a broader set of Mbed TLS library sources than the final application needs. After successful end-to-end TLS/IMAP validation, replace broad wildcard inclusion with an explicit minimal source list and measure binary/RAM impact.

## ADR-010 - Keep ISRG Root X1 and support RSA certificate signatures

**Status:** Accepted

The first probe failed because the ECC-focused Mbed TLS profile could not parse the RSA signature OID in ISRG Root X1. Rather than change the trust model during bring-up, the project keeps ISRG Root X1 as the trust anchor and enables RSA PKCS#1 v1.5 support for X.509 certificate-signature verification.

ISRG Root X1 uses a 4096-bit RSA key, so `MBEDTLS_MPI_MAX_SIZE` is raised to 512 bytes.

This does **not** enable RSA TLS key exchange. The configured TLS cipher suites remain ECDHE-ECDSA + AES-GCM only.

**Reason:** Validate the server's normal public chain first, then optimize memory or trust-anchor choices only after the end-to-end transport is proven on the physical iPad.

## ADR-011 - Enable ClientHello SNI explicitly

**Status:** Accepted

The `0.3-alpha3` device trace proved that calling `mbedtls_ssl_set_hostname()` alone was not enough in the project's minimal build. Hostname verification was active, but the ClientHello did not carry the `server_name` extension because `MBEDTLS_SSL_SERVER_NAME_INDICATION` was not enabled.

The virtual-hosted IMAP server therefore returned its default certificate:

```text
CN=da2.mirahosting.com
SAN=da2.mirahosting.com
```

rather than the certificate selected for `mail.olap.com.tr`.

**Decision:** Enable `MBEDTLS_SSL_SERVER_NAME_INDICATION` and continue using `mbedtls_ssl_set_hostname()` so the same hostname is both transmitted via SNI and verified against the received certificate.

**Security consequence:** This fixes virtual-host certificate selection without relaxing root, chain, or hostname verification.
