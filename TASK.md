# Current Task

_Last updated: 2026-09-17_

## Goal

Validate readable RFC 2047-decoded Subject and From headers on the physical iPad 1 while preserving the now-working Mbed TLS Inbox path.

## Transport gate: PASSED

`0.4-alpha1` was successfully tested on the physical iPad. Normal Inbox loading now works over `IMBMBEDTLSTransport`:

```text
Mbed TLS 3.6.7
-> verified TLS 1.2
-> LOGIN
-> SELECT INBOX
-> FETCH latest headers
-> message list displayed
```

The legacy normal-Inbox `OSStatus -9844` SecureTransport failure is no longer present.

## Current visible issue

Some real messages display raw RFC 2047 encoded words, for example:

```text
=?UTF-8?Q?Yeni_Oturum_Kayd=C4=B1...?=
=?iso-8859-9?Q?...?=
```

## 0.4-alpha2 implementation prepared

New files:

```text
Classes/IMBRFC2047Decoder.h
Classes/IMBRFC2047Decoder.m
```

The decoder supports:

- RFC 2047 `Q` encoded words
- RFC 2047 `B` / Base64 encoded words
- adjacent encoded words with folding whitespace
- UTF-8
- US-ASCII
- ISO-8859-1
- IANA charset conversion through CoreFoundation, including ISO-8859-9 / Windows-1254 when recognized by the platform
- malformed/unsupported words are preserved rather than silently discarded

Inbox presentation decodes `Subject` and `From` once when fetched messages are accepted by the view controller.

## Next actions

1. Pull `0.4-alpha2`.
2. Build; no Mbed TLS bootstrap/config change is required.
3. Install on the physical iPad.
4. Open `info@olap.com.tr -> Inbox`.
5. Confirm previously raw UTF-8 and ISO-8859-9 subjects display as readable Turkish text.
6. Confirm encoded sender display names are readable.
7. Tap refresh once and confirm headers remain correct.
8. If header decoding passes, move to on-demand message-body loading as the next milestone.

## Acceptance criteria

- Inbox still loads over verified Mbed TLS
- RFC 2047 UTF-8 Q/B headers decode correctly
- ISO-8859-9 Turkish headers decode correctly on-device
- adjacent/folded encoded words do not gain artificial spaces
- plain ASCII headers remain unchanged
- unsupported/malformed encoded words do not crash the app
- refresh still works

## Do not

- Do not weaken TLS verification.
- Do not change the working IMAP transport in this task.
- Do not add SMTP, attachments, HTML rendering, or offline cache yet.
- Do not use modern Base64 APIs unavailable on iOS 5.1.1.

## Definition of done

The task is complete when the physical iPad displays the current Inbox with readable Turkish Subject/From fields instead of raw `=?charset?Q/B?...?=` strings, while `0.4-alpha1` transport behavior remains stable.
