# Session Handoff

_Last updated: 2026-09-17_

## Where we are

The project has moved from investigating iOS 5 SecureTransport limitations to validating a bundled Mbed TLS 3.6.7 transport on the physical iPad 1.

Installed test build:

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

## What was proven this session

### Keychain

The earlier `errSecInteractionNotAllowed (-25308)` problem was fixed by signing the application with the required `application-identifier` and `keychain-access-groups` entitlements. Keychain storage is now working.

### SecureTransport limitation

The iPad 1 SecureTransport diagnostic reports 53 supported/enabled cipher suites, but not the modern ECDHE-ECDSA AES-GCM suites required by the current server.

The iPad supports older ECDHE-ECDSA CBC suites, but server-side OpenSSL tests showed the server rejects those suites. Therefore the existing SecureTransport IMAP path cannot negotiate a mutually supported cipher without weakening the server.

### Mbed TLS integration

Mbed TLS 3.6.7 is bootstrapped into `Vendor/mbedtls` and compiled into the application.

Compatibility fixes already made:

- iOS 5 has no usable `clock_gettime()` for this build target.
- `MBEDTLS_PLATFORM_MS_TIME_ALT` is enabled.
- `MBEDTLS_PLATFORM_C` is enabled as its prerequisite.
- `Classes/IMBMBEDTLSPlatform.c` implements `mbedtls_ms_time()` using `mach_absolute_time()`.

The resulting alpha1 package builds successfully and is approximately 102 KB.

## Latest physical-device result

The TLS diagnostics screen shows the Modern TLS section.

Latest relevant result from `0.3-alpha1`:

```text
--- Modern TLS transport ---
Modern TLS probe (Mbed TLS 3.6.7)
Target: mail.olap.com.tr:993

RNG seed: OK
CA trust anchor: FAILED
X509 - Signature algorithm (oid) is unsupported
OID - OID is not found
```

This occurred while loading/parsing the bundled ISRG Root X1 trust anchor, before TCP/TLS handshake.

## Fix prepared for 0.3-alpha2

The next build changes the bundled trust anchor from ISRG Root X1 (RSA 4096) to **ISRG Root X2 (ECDSA P-384)**, which matches the current ECDSA Let's Encrypt hierarchy used by the target server.

The Mbed TLS config also enables:

```text
MBEDTLS_RSA_C
MBEDTLS_PKCS1_V15
```

This is for RSA PKCS#1 v1.5 **certificate-signature/OID compatibility** if a cross-signed CA certificate is present in the server chain. RSA TLS key exchange is not enabled. The only configured TLS ciphers remain ECDHE-ECDSA + AES-GCM.

The bootstrap script now downloads:

```text
https://letsencrypt.org/certs/isrg-root-x2.pem
```

and installs it as:

```text
Resources/isrgrootx2.pem
```

## Build commands

After pulling the alpha2 changes:

```bash
cd ~/projects/ipad1MailBox
git pull origin main
make bootstrap
find . -type f -exec touch {} +
make clean
make package FINALPACKAGE=1
```

Expected package path:

```text
packages/com.shapeloglu.ipad1mailbox_0.3-alpha2_iphoneos-arm.deb
```

Copy to iPad:

```bash
scp -o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
packages/com.shapeloglu.ipad1mailbox_0.3-alpha2_iphoneos-arm.deb \
root@192.168.1.100:/var/mobile/
```

Install on iPad:

```bash
dpkg -i /var/mobile/com.shapeloglu.ipad1mailbox_0.3-alpha2_iphoneos-arm.deb
su mobile -c 'HOME=/var/mobile /usr/bin/uicache'
killall SpringBoard
```

Verify installed package:

```bash
dpkg -s com.shapeloglu.ipad1mailbox | grep Version
```

## Important code locations

- `Classes/IMBIMAPClient.m` - current legacy IMAP transport
- `Classes/IMBTLSDiagnostics.m` - SecureTransport cipher diagnostics
- `Classes/IMBModernTLSProbe.m` - current Mbed TLS physical-device probe
- `Classes/IMBMBEDTLSPlatform.c` - iOS 5 Mbed TLS time compatibility
- `Config/IMBMBEDTLSConfig.h` - minimal Mbed TLS feature set
- `scripts/bootstrap_mbedtls.sh` - Mbed TLS + CA bootstrap
- `Makefile` - armv7 application build and Mbed TLS source inclusion

## Resume here

Open `TASK.md` first. Pull/build `0.3-alpha2`, run the physical-device TLS probe, and capture the Modern TLS section. The next diagnostic gate is whether ISRG Root X2 loads and the handshake proceeds beyond CA parsing.
