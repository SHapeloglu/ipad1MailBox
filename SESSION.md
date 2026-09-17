# Session Handoff

_Last updated: 2026-09-17_

## Where we are

The physical iPad 1 has now passed both the modern transport and header-decoding milestones.

Latest proven device build:

```text
iPad1MailBox 0.4-alpha2
```

Next test build:

```text
iPad1MailBox 0.5-alpha1
```

## Proven on the physical iPad

Normal Inbox works through verified Mbed TLS 3.6.7:

```text
TLS 1.2
-> LOGIN
-> SELECT INBOX
-> FETCH latest 25 headers
-> RFC 2047 decoding
-> readable Turkish message list
```

The old SecureTransport `OSStatus -9844` normal-operation failure is gone. UTF-8 and ISO-8859-9 encoded Subject/From fields now render correctly.

## 0.5-alpha1 changes prepared

### Message reader

New controller:

```text
Classes/IMBMessageReaderViewController.h
Classes/IMBMessageReaderViewController.m
```

Tapping an Inbox row now pushes a real message screen showing Subject, From, Date and an on-demand body.

### Bounded body fetch

`IMBIMAPClient` now supports:

```text
fetchMessageBodyForAccount:password:uid:
```

Flow:

```text
connect
-> LOGIN
-> SELECT INBOX
-> UID FETCH <uid> BODY.PEEK[]<0.262144>
-> extract IMAP literal
-> MIME plain-text extraction
-> LOGOUT
```

The selected message is addressed by UID rather than sequence number.

### MIME text extraction

New files:

```text
Classes/IMBMIMETextExtractor.h
Classes/IMBMIMETextExtractor.m
```

Current scope:

- first non-attachment `text/plain` entity
- multipart recursion with bounded depth
- quoted-printable decode
- Base64 decode
- charset conversion through CoreFoundation
- attachment parts skipped
- HTML is intentionally not rendered yet

Memory/safety bounds:

```text
message prefix: 256 KB maximum
IMAP accumulated response: 512 KB maximum
command timeout: 20 seconds
```

## Build commands

No Mbed TLS config changed, so bootstrap is not required if the existing local vendor tree is current.

```bash
cd ~/projects/ipad1MailBox
git pull origin main
find . -type f -exec touch {} +
make clean
make package FINALPACKAGE=1
```

Expected package:

```text
packages/com.shapeloglu.ipad1mailbox_0.5-alpha1_iphoneos-arm.deb
```

Copy:

```bash
scp -o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
packages/com.shapeloglu.ipad1mailbox_0.5-alpha1_iphoneos-arm.deb \
root@192.168.1.100:/var/mobile/
```

Install:

```bash
dpkg -i /var/mobile/com.shapeloglu.ipad1mailbox_0.5-alpha1_iphoneos-arm.deb
su mobile -c 'HOME=/var/mobile /usr/bin/uicache'
killall SpringBoard
```

## What to test next

Open several messages from Inbox. Confirm at least one plain-text or multipart mail displays readable content. Test navigating back and opening another message. HTML-only messages may intentionally show the plain-text-not-found fallback in this milestone.

## Resume here

Read `TASK.md`. Build and physically test `0.5-alpha1`. Fix any compile/runtime/MIME issues before adding HTML rendering, attachments or SMTP.
