# Session Handoff

_Last updated: 2026-09-17_

## Where we are

The project is validating a bundled Mbed TLS 3.6.7 transport on the physical iPad 1.

Latest tested build:

```text
iPad1MailBox 0.3-alpha3
```

Next build:

```text
iPad1MailBox 0.3-alpha4
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

`0.3-alpha2` added RSA PKCS#1 v1.5 support for certificate validation and raised `MBEDTLS_MPI_MAX_SIZE` to 512 so ISRG Root X1 can be parsed. RSA TLS key exchange remains disabled.

## Latest physical-device result: 0.3-alpha3

The verification trace isolated the hostname failure precisely.

Chain depths 1-4 verify cleanly:

```text
Verify callback: depth=4 flags=0x00000000
Verify callback: depth=3 flags=0x00000000
Verify callback: depth=2 flags=0x00000000
Verify callback: depth=1 flags=0x00000000
```

Only the leaf has:

```text
Verify callback: depth=0 flags=0x00000004
```

The actual leaf certificate received by the iPad is:

```text
subject name  : CN=da2.mirahosting.com
subject alt name:
    dNSName : da2.mirahosting.com
```

So the mismatch is legitimate: the device received the hosting provider's default certificate rather than the virtual host certificate for `mail.olap.com.tr`.

## Root cause

The code already called:

```text
mbedtls_ssl_set_hostname(&ssl, "mail.olap.com.tr")
```

which enabled hostname verification, but `Config/IMBMBEDTLSConfig.h` did not define:

```text
MBEDTLS_SSL_SERVER_NAME_INDICATION
```

In Mbed TLS 3.6.7 the ClientHello `server_name` extension is written only when this configuration option is enabled. Therefore the TLS client verified against `mail.olap.com.tr` without actually sending SNI to the virtual-hosted server.

That caused the server to select the default `da2.mirahosting.com` certificate.

## 0.3-alpha4 fix prepared

The Mbed TLS config now enables:

```text
MBEDTLS_SSL_SERVER_NAME_INDICATION
```

The probe additionally prints:

```text
SNI ClientHello extension: ENABLED
```

Verification is not weakened. `MBEDTLS_SSL_VERIFY_REQUIRED`, hostname checking, ISRG Root X1, and the ECDHE-ECDSA + AES-GCM cipher restriction remain in place.

## Build commands

Because the Mbed TLS config changed, rerun bootstrap after pulling:

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
packages/com.shapeloglu.ipad1mailbox_0.3-alpha4_iphoneos-arm.deb
```

Copy:

```bash
scp -o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
packages/com.shapeloglu.ipad1mailbox_0.3-alpha4_iphoneos-arm.deb \
root@192.168.1.100:/var/mobile/
```

Install:

```bash
dpkg -i /var/mobile/com.shapeloglu.ipad1mailbox_0.3-alpha4_iphoneos-arm.deb
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
- `Config/IMBMBEDTLSConfig.h` - Mbed TLS feature set including client SNI
- `scripts/bootstrap_mbedtls.sh` - Mbed TLS + ISRG Root X1 bootstrap
- `Makefile` - armv7 build

## Resume here

Open `TASK.md`. Build/install `0.3-alpha4`, run the TLS probe, and confirm that SNI is enabled and the server now presents the `mail.olap.com.tr` certificate. If the handshake then succeeds, the next step is to move the existing IMAP `LOGIN -> SELECT INBOX -> FETCH` flow onto the Mbed TLS transport.
