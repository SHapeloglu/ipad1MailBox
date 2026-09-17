# Session Handoff

_Last updated: 2026-09-17_

## Where we are

The project is validating a bundled Mbed TLS 3.6.7 transport on the physical iPad 1.

Latest tested build:

```text
iPad1MailBox 0.3-alpha2
```

Next diagnostic build:

```text
iPad1MailBox 0.3-alpha3
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

### RSA/X.509 trust-anchor support

`0.3-alpha2` added:

```text
MBEDTLS_RSA_C
MBEDTLS_PKCS1_V15
MBEDTLS_MPI_MAX_SIZE 512
```

This fixed the earlier ISRG Root X1 parse failure. RSA TLS key exchange is still disabled; the configured transport suites remain ECDHE-ECDSA + AES-GCM only.

## Latest physical-device result

`0.3-alpha2` now reaches live certificate verification:

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

`0x00000004` is Mbed TLS `MBEDTLS_X509_BADCERT_CN_MISMATCH`.

This is significant progress: RNG, trust-anchor parsing, TCP connection, and entry into certificate verification all work on the physical iPad.

## Why we are not bypassing this error

Earlier OpenSSL inspection indicated a leaf subject CN of `olap.com.tr` and a SAN entry for `mail.olap.com.tr`. Mbed TLS should normally accept a matching DNS SAN before CN fallback.

Therefore the next step is to inspect the exact certificate and SAN data that Mbed TLS sees on-device. Do not clear the mismatch flag just to continue.

## 0.3-alpha3 changes prepared

`IMBModernTLSProbe` now uses a diagnostic verification callback that logs the leaf certificate as parsed by Mbed TLS, including its extensions/SAN information. The callback leaves all verification flags untouched.

The TLS Diagnostics screen now auto-scrolls to the completed Modern TLS section to reduce manual scrolling on the iPad 1.

## Build commands

This build does not change `Config/IMBMBEDTLSConfig.h`, so `make bootstrap` is not required if the local checkout already built `0.3-alpha2` successfully.

```bash
cd ~/projects/ipad1MailBox
git pull origin main
find . -type f -exec touch {} +
make clean
make package FINALPACKAGE=1
```

Expected package:

```text
packages/com.shapeloglu.ipad1mailbox_0.3-alpha3_iphoneos-arm.deb
```

Copy:

```bash
scp -o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
packages/com.shapeloglu.ipad1mailbox_0.3-alpha3_iphoneos-arm.deb \
root@192.168.1.100:/var/mobile/
```

Install:

```bash
dpkg -i /var/mobile/com.shapeloglu.ipad1mailbox_0.3-alpha3_iphoneos-arm.deb
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
- `Classes/IMBModernTLSProbe.m` - Mbed TLS device probe + read-only verification trace
- `Classes/IMBMBEDTLSPlatform.c` - iOS 5 timer compatibility
- `Config/IMBMBEDTLSConfig.h` - Mbed TLS feature set
- `scripts/bootstrap_mbedtls.sh` - Mbed TLS + ISRG Root X1 bootstrap
- `Makefile` - armv7 build

## Resume here

Open `TASK.md`. Build/install `0.3-alpha3`, run the TLS probe, and capture the `Peer certificate as parsed by Mbed TLS` section. Determine whether `mail.olap.com.tr` is present in the SAN that Mbed TLS actually sees before changing any hostname-verification behavior.
