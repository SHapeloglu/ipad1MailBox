# Current Task

_Last updated: 2026-09-17_

## Goal

Establish a fully verified TLS 1.2 IMAP connection from the physical iPad 1 to `mail.olap.com.tr:993` using Mbed TLS 3.6.7, then move the existing minimal IMAP flow from SecureTransport to that transport.

## Current state

The physical iPad has now tested `iPad1MailBox 0.3-alpha2`. The next diagnostic build is `0.3-alpha3`.

Confirmed on the physical device:

- Mbed TLS 3.6.7 builds for armv7 with the iPhoneOS 6.1 SDK.
- The iOS 5 `clock_gettime()` incompatibility is handled through `IMBMBEDTLSPlatform.c` and `mach_absolute_time()`.
- RNG initialization succeeds.
- ISRG Root X1 now parses successfully.
- TCP connection to `mail.olap.com.tr:993` succeeds.
- SNI/hostname is configured as `mail.olap.com.tr`.
- Certificate and hostname verification remain mandatory.
- SecureTransport remains unable to negotiate the server's required modern ECDHE-ECDSA AES-GCM suites.

Latest `0.3-alpha2` probe result:

```text
RNG seed: OK
CA trust anchor: ISRG Root X1 loaded
TCP connect: OK
SNI/hostname: mail.olap.com.tr
TLS handshake: FAILED
X509 - Certificate verification failed, e.g. CRL, CA or signature check failed (-9984 / -0x2700)
Certificate verify flags: 0x00000004
  The certificate Common Name (CN) does not match with the expected CN
```

Mbed TLS defines verification flag `0x00000004` as `MBEDTLS_X509_BADCERT_CN_MISMATCH`.

## Current question

Earlier OpenSSL inspection indicated that the live certificate for this endpoint includes `mail.olap.com.tr` in Subject Alternative Name (SAN), while the leaf Common Name is `olap.com.tr`.

Mbed TLS normally checks DNS SAN entries before falling back to CN. Therefore the current failure must be diagnosed before any verification behavior is changed.

Possible explanations to distinguish:

1. The certificate currently presented to the iPad differs from the certificate previously observed with OpenSSL.
2. The peer certificate SAN is not being parsed as expected by the current Mbed TLS build.
3. A server/SNI or certificate-deployment detail differs on the device path.

Do **not** clear or ignore the CN mismatch until the exact peer certificate seen by Mbed TLS is known.

## 0.3-alpha3 diagnostic change

`IMBModernTLSProbe` now installs a read-only verification callback that records:

- verification depth
- verification flags
- the peer certificate information exactly as parsed by Mbed TLS
- SAN information printed by Mbed TLS for the leaf certificate

The callback does not change, clear, or mask any verification flag.

The TLS Diagnostics view also auto-scrolls to the completed modern TLS result.

## Next actions

1. Pull and build `0.3-alpha3`.
2. No `make bootstrap` is required for this build because the Mbed TLS config is unchanged from `0.3-alpha2`.
3. Install on the physical iPad.
4. Run `Inbox -> TLS`.
5. Capture the `Peer certificate as parsed by Mbed TLS` section, especially Subject and Subject Alternative Name.
6. If SAN contains `mail.olap.com.tr`, fix the Mbed TLS hostname-validation integration without weakening verification.
7. If SAN does not contain `mail.olap.com.tr`, treat it as a server certificate/deployment issue rather than bypassing hostname checks.
8. Only after hostname verification passes, continue to cipher/protocol confirmation and the Dovecot greeting gate.

## Do not

- Do not disable certificate verification.
- Do not clear `MBEDTLS_X509_BADCERT_CN_MISMATCH` merely to make the handshake pass.
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
