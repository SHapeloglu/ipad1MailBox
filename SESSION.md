# Session Handoff

_Last updated: 2026-09-17_

## Where we are

The project is validating a bundled Mbed TLS 3.6.7 transport on the physical iPad 1.

Installed build:

```text
iPad1MailBox 0.3-alpha1
```

Next test build:

```text
iPad1MailBox 0.3-alpha2
```

Target server:

```text
mail.olap.com.tr:993
implicit TLS / IMAPS
```

## Proven so far

### Keychain

The earlier `errSecInteractionNotAllowed (-25308)` issue was fixed with application identifier and keychain access group entitlements. Keychain storage works.

### SecureTransport limitation

The physical iPad supports 53 SecureTransport cipher suites but not the ECDHE-ECDSA AES-GCM suites required by the server. Server-side OpenSSL tests also showed that the older CBC ECDHE-ECDSA suites available on iOS 5 are rejected.

### Mbed TLS integration

Mbed TLS 3.6.7 compiles into the armv7 application. iOS 5 timer compatibility is provided through `MBEDTLS_PLATFORM_MS_TIME_ALT`, `MBEDTLS_PLATFORM_C`, and `mach_absolute_time()` in `IMBMBEDTLSPlatform.c`.

## Latest physical-device result

`0.3-alpha1` reached the modern probe but failed before TCP/TLS handshake:

```text
RNG seed: OK
CA trust anchor: FAILED
X509 - Signature algorithm (oid) is unsupported
OID - OID is not found
```

The failure happened while parsing ISRG Root X1.

## Fix prepared for 0.3-alpha2

The trust anchor remains:

```text
ISRG Root X1
```

The Mbed TLS config now adds:

```text
MBEDTLS_RSA_C
MBEDTLS_PKCS1_V15
MBEDTLS_MPI_MAX_SIZE 512
```

This allows the 4096-bit RSA root and RSA PKCS#1 v1.5 certificate signatures to be parsed/verified. RSA TLS key exchange is still disabled: the configured TLS suites remain ECDHE-ECDSA + AES-GCM only.

## Build commands

```bash
cd ~/projects/ipad1MailBox
git pull origin main
make bootstrap
find . -type f -exec touch {} +
make clean
make package FINALPACKAGE=1
```

Expected package:

```text
packages/com.shapeloglu.ipad1mailbox_0.3-alpha2_iphoneos-arm.deb
```

Copy:

```bash
scp -o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
packages/com.shapeloglu.ipad1mailbox_0.3-alpha2_iphoneos-arm.deb \
root@192.168.1.100:/var/mobile/
```

Install:

```bash
dpkg -i /var/mobile/com.shapeloglu.ipad1mailbox_0.3-alpha2_iphoneos-arm.deb
su mobile -c 'HOME=/var/mobile /usr/bin/uicache'
killall SpringBoard
```

Verify:

```bash
dpkg -s com.shapeloglu.ipad1mailbox | grep Version
```

## Important code locations

- `Classes/IMBIMAPClient.m` - current legacy IMAP transport
- `Classes/IMBTLSDiagnostics.m` - SecureTransport diagnostics
- `Classes/IMBModernTLSProbe.m` - Mbed TLS device probe
- `Classes/IMBMBEDTLSPlatform.c` - iOS 5 timer compatibility
- `Config/IMBMBEDTLSConfig.h` - Mbed TLS feature set
- `scripts/bootstrap_mbedtls.sh` - Mbed TLS + ISRG Root X1 bootstrap
- `Makefile` - armv7 build

## Resume here

Open `TASK.md`. Pull/build `0.3-alpha2`, run the TLS probe on the iPad, and capture the Modern TLS section. The next gate is whether ISRG Root X1 loads and the probe reaches TCP/TLS handshake.
