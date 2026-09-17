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

**Reason:** The application may need a newer TLS implementation, but it should not obtain compatibility by removing server authentication.

## ADR-004 - SecureTransport is diagnostic/legacy, not the long-term modern TLS path

**Status:** Accepted

Physical-device diagnostics showed that iOS 5.1.1 SecureTransport lacks the ECDHE-ECDSA AES-GCM cipher suites currently required by the test mail server. The server also rejects the older ECDHE-ECDSA CBC suites available on the iPad.

**Decision:** Keep SecureTransport long enough to preserve the existing IMAP path and device diagnostics, but move modern server connectivity to a bundled TLS implementation.

## ADR-005 - Use Mbed TLS 3.6.7 for the modern TLS transport

**Status:** Accepted for current development

Mbed TLS 3.6.7 is compiled into the application and configured for the required TLS 1.2 client use case.

**Required capabilities:**

- TLS 1.2
- ECDHE-ECDSA
- AES-GCM
- SNI
- X.509 parsing and verification
- secure RNG
- low-memory configuration suitable for iPad 1

**Consequences:**

- the app carries its own modern TLS code
- Mbed TLS configuration becomes security-sensitive project code
- dependency/security updates must be reviewed intentionally
- binary size increases, but remains acceptable for the target

## ADR-006 - Validate Mbed TLS independently before replacing IMAP transport

**Status:** Accepted

`IMBModernTLSProbe` is a deliberate integration gate.

The replacement transport is not connected to `IMBIMAPClient` until the physical iPad proves:

1. RNG initialization
2. trust-anchor parsing
3. TCP connection
4. TLS handshake
5. hostname verification
6. certificate verification
7. approved cipher negotiation
8. IMAP server greeting

**Reason:** Separating TLS validation from IMAP parsing makes failures easier to isolate on the old platform.

## ADR-007 - Supply monotonic time with `mach_absolute_time()`

**Status:** Accepted

Mbed TLS 3.6.7's default Unix-like millisecond timer path selected `clock_gettime()`, which is unavailable for the iOS 5 target.

`MBEDTLS_PLATFORM_MS_TIME_ALT` plus `IMBMBEDTLSPlatform.c` provides `mbedtls_ms_time()` using `mach_absolute_time()`.

## ADR-008 - Keep mail application ownership narrow

**Status:** Accepted

iPad1MailBox owns mail accounts, folders, messages, compose/send, MIME interpretation, and attachment hand-off.

It does not become a second file manager or media player.

Planned hand-off:

- PDF -> iPad1PDFReader
- ZIP/general files -> iPad1Files
- audio/video -> iPad1Player

## ADR-009 - Optimize Mbed TLS only after the required feature set works

**Status:** Accepted

During bring-up, the Makefile may compile a broader set of Mbed TLS library sources than the final application needs.

After successful end-to-end TLS/IMAP validation, replace broad wildcard inclusion with an explicit minimal source list and measure binary/RAM impact.

**Reason:** Correctness and compatibility should be established before aggressive source pruning, while the final build should still respect the 256 MB target.

## ADR-010 - Use ISRG Root X2 as the ECDSA trust anchor

**Status:** Accepted

The first Mbed TLS probe bundled ISRG Root X1. That root is RSA 4096 and the intentionally small ECC-focused configuration could not parse its RSA signature OID.

The target server currently uses the Let's Encrypt ECDSA hierarchy, which can terminate at ISRG Root X2 (ECDSA P-384). The application therefore bundles ISRG Root X2 as the trust anchor for this bring-up path.

The Mbed TLS build still enables minimal RSA PKCS#1 v1.5 certificate-signature support so that RSA-signed cross-certificates in a server-provided chain can be recognised. This does **not** enable RSA TLS key exchange: the configured TLS ciphers remain ECDHE-ECDSA + AES-GCM only.

**Reason:** This keeps the trust store aligned with the actual ECDSA hierarchy and avoids carrying an unnecessary RSA 4096 trust-anchor key on the 256 MB target while retaining compatibility with cross-signed chain metadata.
