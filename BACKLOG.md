# Backlog

_Last updated: 2026-09-17_

This file contains work that is not part of the current active task. Keep `TASK.md` focused on one immediate goal.

## Transport and protocol

- Add reconnect behavior after network changes.
- Add SMTP transport after IMAP is stable.
- Distinguish SMTP implicit TLS (typically 465) from STARTTLS submission (typically 587).
- Replace broad Mbed TLS source wildcarding with an explicit minimal source list after functional milestones stabilize.

## IMAP

- Folder discovery/listing.
- Sent/Drafts/Trash mapping.
- Paged message header loading beyond the initial 25-message page.
- Full message body loading on demand.
- Read/unread flags.
- Star/flag support.
- Delete/move operations.
- Refresh without reloading unnecessary data.
- Basic search after the low-memory mailbox path is stable.

## Message parsing

- Parse multipart MIME messages.
- Prefer plain text when appropriate.
- Add conservative HTML rendering for iPad 1.
- Expand charset coverage as real mail samples require it.
- Parse attachment metadata without loading attachment data eagerly.
- Reuse `IMBRFC2047Decoder` anywhere decoded display headers are needed outside the Inbox list.

## Compose and SMTP

- Real SMTP send.
- Reply.
- Reply all.
- Forward.
- CC/BCC.
- Draft persistence.
- Attachment upload with bounded memory use.
- Sent-folder copy/save behavior.

## Attachments and iPad1 suite integration

- Save attachments under `/var/mobile/Media/iPad1Files/Mail/Attachments/`.
- PDF -> iPad1PDFReader.
- ZIP/general files -> iPad1Files.
- Audio/video -> iPad1Player.
- Avoid duplicating file-manager functionality inside iPad1MailBox.
- Define safe filenames and collision handling.
- Add explicit user action before large downloads.

## Storage and caching

- Add a small metadata cache only after transport/message parsing is stable.
- Define cache limits appropriate for 256 MB RAM and limited device storage.
- Cache headers and mailbox metadata, not entire mailboxes.
- Purge old body/attachment cache safely.
- Never store passwords or authentication secrets in the cache.

## TLS and security

- Keep bundled trust anchors maintainable and documented.
- Consider bundling multiple required ISRG roots rather than relying on the iOS 5 trust store.
- Add diagnostic output for negotiated curve and peer certificate chain where useful.
- Keep certificate and hostname verification mandatory.
- Review Mbed TLS configuration for unused modules and reduce binary size after the transport works.
- Review Mbed TLS security updates before each release.

## UI and diagnostics

- Separate user-facing connection errors from developer diagnostics.
- Add a compact account status indicator.
- Add loading/cancel state that remains responsive on iPad 1.
- Improve empty mailbox and offline states.

## Provider compatibility

- Test generic Dovecot/cPanel style IMAP/SMTP first.
- Evaluate Gmail compatibility after generic IMAP/SMTP is stable.
- Evaluate Outlook/Microsoft compatibility after generic IMAP/SMTP is stable.
- Investigate OAuth2 only where feasible on iOS 5.1.1; do not block basic standards-based mail support on OAuth work.

## Release hygiene

- Keep `SESSION.md` updated at the end of meaningful development sessions.
- Keep `TASK.md` to one active problem.
- Record architecture-changing choices in `DECISIONS.md`.
- Update `ARCHITECTURE.md` when component boundaries change.
- Maintain `THIRD_PARTY_NOTICES.md` when dependencies or licenses change.
