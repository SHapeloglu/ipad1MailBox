# iPad1MailBox Architecture

## Design constraints

The application targets the original iPad:

- iOS 5.1.1
- armv7
- 256 MB RAM
- non-ARC Objective-C
- Theos / iPhoneOS 6.1 SDK

Modern APIs and heavyweight frameworks are intentionally avoided.

## Layers

### UI

- `IMBAppDelegate` - application and split-view bootstrap
- `IMBInboxViewController` - account/mailbox sidebar
- `IMBAccountSetupViewController` - account configuration
- `IMBComposeViewController` - lightweight compose UI

### Account model

- `IMBAccount` - non-secret IMAP/SMTP configuration
- `IMBAccountStore` - metadata persistence and Keychain credential storage

Passwords are never persisted to plist, `NSUserDefaults`, SQLite, or logs.

### Transport (next milestone)

Transport will be isolated from UI code.

Planned responsibilities:

- IMAP connect/authenticate
- folder discovery
- paged header fetch (25-50 messages)
- on-demand body fetch
- message flags
- SMTP send
- MIME parsing
- attachment download on demand

MailCore 1 / libetpan will be evaluated against the actual iOS 5.1.1 armv7 toolchain before being committed as a dependency.

## Memory policy

- Never load an entire mailbox into memory.
- Cache lightweight message metadata only.
- Fetch body content when a message is opened.
- Fetch attachments only on explicit user action.
- Release message/body views aggressively after navigation.
- Keep HTML rendering conservative on large messages.

## Suite ownership

`iPad1MailBox` owns mail accounts, folders, messages, compose/send, and attachment hand-off.

It must not become a general file manager.

Attachment hand-off targets:

- PDF -> iPad1PDFReader
- ZIP/general files -> iPad1Files
- video/audio -> iPad1Player

Planned shared storage root:

`/var/mobile/Media/iPad1Files/Mail/Attachments/`

## Milestones

### v0.1-alpha1

- native application shell
- split-view UI
- account setup
- Keychain credentials
- mailbox/account sidebar
- compose shell

### v0.2-alpha

- IMAP authentication
- Inbox folder
- paged message headers
- plain-text message reading
- connection/error state

### v0.3-alpha

- SMTP send
- reply/forward
- Sent/Drafts/Trash
- message flags

### v0.4-beta

- MIME/HTML handling
- attachments
- suite routing
- SQLite metadata cache
- unified inbox

### Later

- OAuth2 where feasible on iOS 5.1.1
- Gmail/Outlook provider-specific sign-in paths
- search and advanced folder management
