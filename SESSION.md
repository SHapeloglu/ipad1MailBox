# Session Handoff

_Last updated: 2026-09-17_

## Where we are

The modern TLS bring-up phase is complete on the physical iPad 1. `0.3-alpha4` proved the full verified TLS 1.2 path. The repository has now advanced to the first normal Inbox build using a reusable Mbed TLS transport.

Latest proven device build:

```text
iPad1MailBox 0.3-alpha4
```

Next functional test build:

```text
iPad1MailBox 0.4-alpha1
```

Target server:

```text
mail.olap.com.tr:993
implicit TLS / IMAPS
```

## Proven on the physical iPad

```text
RNG seed: OK
CA trust anchor: ISRG Root X1 loaded
TCP connect: OK
SNI ClientHello extension: ENABLED
SNI/hostname: mail.olap.com.tr
certificate verification depths 0-4: flags=0
TLS handshake: OK
Protocol: TLSv1.2
Cipher: TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384
Certificate verification: OK
IMAP greeting: * OK ... Dovecot DA ready.
```

The earlier Keychain entitlement issue, iOS 5 `clock_gettime()` incompatibility, RSA/X.509 trust-anchor support, and ClientHello SNI problem are all resolved.

## 0.4-alpha1 changes prepared

### New reusable transport

Files:

```text
Classes/IMBMBEDTLSTransport.h
Classes/IMBMBEDTLSTransport.m
```

Responsibilities:

- Mbed TLS context lifecycle
- RNG + ISRG Root X1 trust setup
- TCP connect
- TLS 1.2 handshake
- SNI and hostname verification
- mandatory X.509 verification
- encrypted read/write
- timeout handling
- cancellation through socket shutdown
- clean TLS close

### IMAP migration

`IMBIMAPClient` no longer uses `NSInputStream` / `NSOutputStream` / CFStream SecureTransport for normal Inbox loading.

The protocol flow now executes on a background thread through `IMBMBEDTLSTransport`:

```text
greeting
-> LOGIN
-> SELECT INBOX
-> read EXISTS
-> FETCH latest 25 headers
-> LOGOUT
```

Concurrency protection:

- each fetch receives a generation token
- cancel/refresh increments the token
- active transport is cancelled
- stale worker results are ignored

Safety limits:

```text
command timeout: 20 seconds
maximum accumulated IMAP response: 512 KB
```

Credentials are still sourced from Keychain and are never logged.

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
packages/com.shapeloglu.ipad1mailbox_0.4-alpha1_iphoneos-arm.deb
```

Copy:

```bash
scp -o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
packages/com.shapeloglu.ipad1mailbox_0.4-alpha1_iphoneos-arm.deb \
root@192.168.1.100:/var/mobile/
```

Install:

```bash
dpkg -i /var/mobile/com.shapeloglu.ipad1mailbox_0.4-alpha1_iphoneos-arm.deb
su mobile -c 'HOME=/var/mobile /usr/bin/uicache'
killall SpringBoard
```

Verify:

```bash
dpkg -s com.shapeloglu.ipad1mailbox | grep Version
```

## What to test next

1. Open `info@olap.com.tr`.
2. Inbox should connect without `OSStatus -9844`.
3. Up to 25 latest headers should appear.
4. Tap refresh once and confirm the list reloads correctly.
5. Keep the `TLS` diagnostics button for comparison; normal Inbox should no longer depend on SecureTransport.

## Important code locations

- `Classes/IMBMBEDTLSTransport.m` - reusable verified TLS transport
- `Classes/IMBIMAPClient.m` - background IMAP command/parser flow
- `Classes/IMBModernTLSProbe.m` - proven diagnostic path
- `Classes/IMBTLSDiagnostics.m` - legacy SecureTransport capability diagnostics
- `Config/IMBMBEDTLSConfig.h` - Mbed TLS feature/cipher configuration
- `TASK.md` - active physical-device test gate

## Resume here

Build `0.4-alpha1`. If it compiles, install and test normal Inbox loading plus one refresh. Do not begin body/MIME/SMTP work until those two operations pass on the physical iPad.
