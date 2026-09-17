# Current Task

_Last updated: 2026-09-17_

## Goal

Validate the first on-demand message reader on the physical iPad 1 while preserving the now-working Mbed TLS Inbox and RFC 2047 header decoding.

## Completed gates

`0.4-alpha1` proved normal Inbox loading over `IMBMBEDTLSTransport`:

```text
verified Mbed TLS 1.2
-> LOGIN
-> SELECT INBOX
-> FETCH latest headers
-> message list displayed
```

`0.4-alpha2` was then tested successfully on the physical iPad. UTF-8 and ISO-8859-9 RFC 2047 Subject/From values now display as readable Turkish text.

## 0.5-alpha1 implementation prepared

Selecting an Inbox row now pushes `IMBMessageReaderViewController` instead of showing the old placeholder alert.

The reader requests the selected message by IMAP UID over the same verified Mbed TLS transport:

```text
connect / LOGIN / SELECT INBOX
-> UID FETCH <uid> BODY.PEEK[]<0.262144>
-> extract IMAP literal
-> parse MIME
-> display first non-attachment text/plain part
```

New MIME support is deliberately bounded and conservative:

- maximum fetched raw message prefix: 256 KB
- total IMAP response safety limit remains 512 KB
- text/plain only for this milestone
- multipart recursion with a small depth limit
- quoted-printable body decoding
- Base64 body decoding
- charset conversion through CoreFoundation
- attachment parts are skipped
- HTML rendering is not enabled yet

## Next actions

1. Pull and build `0.5-alpha1`.
2. No Mbed TLS bootstrap/config change is required.
3. Install on the physical iPad.
4. Open Inbox and tap several different messages.
5. Confirm Subject / From / Date remain visible and a plain-text body loads below them.
6. Test at least one multipart message and one Turkish message if available.
7. Return to Inbox and open another message to exercise cancellation/lifecycle behavior.
8. If a message has no text/plain part, the reader should show the explicit fallback rather than crash.

## Acceptance criteria

- Inbox continues to load normally
- tapping a row opens a real reader screen
- selected message is fetched by UID, not sequence number
- text/plain body is shown when present
- quoted-printable and Base64 text bodies decode correctly
- common charsets, including Turkish legacy charsets recognized by CoreFoundation, display correctly
- large messages are bounded to a 256 KB preview
- HTML-only or unsupported MIME messages fail gracefully
- credentials remain only in Keychain
- TLS certificate and hostname verification remain mandatory

## Do not

- Do not weaken TLS verification.
- Do not fetch entire unbounded messages or attachments.
- Do not render HTML yet.
- Do not add SMTP, attachment downloads, or offline cache in this milestone.

## Definition of done

The task is complete when the physical iPad can open several real Inbox messages and display their readable text/plain body on demand without destabilizing the existing Inbox path.
