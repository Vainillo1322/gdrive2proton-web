# gdrive2proton

Copies a Google Drive account into Proton Drive, preserving the full folder
hierarchy. One self-contained binary per platform, no runtime to install.

How a migration run works:

1. The browser opens a Google sign-in page (the app only ever gets a
   **read-only** token; it cannot change anything in the Drive).
2. The browser opens a second page, served by the app on the user's own
   computer, for the Proton sign-in (username, password, and a 2FA code if
   the account has one). The credentials go straight to Proton's servers and
   are dropped when the sign-in completes. Uploads are end-to-end encrypted
   the same way the Proton Drive apps encrypt them.
3. The tool walks the Drive and recreates every folder in Proton Drive, under
   a folder named after the Drive account, uploading each file as it goes.
   Google Docs / Sheets / Slides / Drawings are converted to .docx / .xlsx /
   .pptx / .png on the way (they are not real files on Drive and cannot be
   copied as-is). Each file keeps its modified time.
4. If the run is interrupted, run the same command again: a manifest
   (`.gdrive2proton_manifest.jsonl` in the working directory) records what
   was already uploaded, and files that are already in Proton Drive with the
   same name and size are skipped too.

**Nothing sensitive is ever written to disk.** No tokens, no sessions, no
keys, no passwords — everything lives in the process's memory for the
duration of the run and is gone when it ends. Each run therefore starts with
a fresh browser sign-in on both sides. The only file the tool ever writes is
the resume manifest (Google file IDs and names, no credentials).

Nothing is ever deleted from Google Drive (the tool holds a read-only
token). Each file is downloaded to a temporary local copy while it uploads,
and that temp file is removed automatically the moment the upload finishes
or fails.

## The binaries

In `binaries/`:

    gdrive2proton-linux-amd64         Linux, Intel/AMD 64-bit

It is a static build with no dependencies: copy it anywhere and run it.
(The tool is written in Go, so builds for other platforms are one command
away — see "Building from source".)

## Getting Google API credentials (developer, one-time, ~10 minutes)

1. https://console.cloud.google.com → create a project.
2. APIs & Services → Library → enable **Google Drive API**.
3. APIs & Services → OAuth consent screen → **External**, fill in app name
   and contact email, and add your testers under **Test users**. The scope
   used, `drive.readonly`, is a sensitive scope, so Google marks the app
   unverified in test mode; that is expected and fine for up to 100 test
   users, after which Google's verification review is required before wide
   distribution.
4. APIs & Services → Credentials → Create credentials → **OAuth client ID**
   → type **Desktop app** → download the JSON.
5. Ship that file as `credentials.json` next to the binary (the desktop-app
   secret is not meant to stay secret; that is how installed apps work).

## Running a migration

Put `credentials.json` and the binary in a folder, open a terminal there:

    ./gdrive2proton-linux-amd64

The browser opens a Google sign-in page, then a second page for the Proton
sign-in (username, password, and the 2FA code if the account has one). If a
tab does not open by itself, the tool prints the local URL to paste. After
each sign-in the tab can be closed; the migration starts when both are done.
Re-running the same command resumes: it retries what errored and picks up
new files.

Everything lands in Proton Drive under **My Drive / <Drive folder name>/**.

### Options

    --folder <ID>            copy only the subtree of this Drive folder ID
                             (default: all of My Drive)
    --shared-drives          also copy every Shared Drive you can access
                             (one top-level folder per drive)
    --dest-folder <name>     choose the name of the top folder in Proton Drive
    --dry-run                list what would be copied; uploads nothing
    --gclient                custom path for the Google credential file
    --proton-appversion      app identifier sent to Proton (change only if
                             Proton rejects the default)

A good first command:

    ./gdrive2proton-linux-amd64 --dry-run

## Notes and limits

* Drive **shortcuts** are pointers, not files; they are reported and skipped.
* **Google Forms, Apps Scripts, My Maps** cannot be exported as files by
  Drive; they are reported and skipped. Forms responses export as CSV from
  Google Forms itself.
* Trashed files are not copied.
* Only the folder hierarchy of **My Drive** (and Shared Drives with
  `--shared-drives`) is mirrored. Files shared with the user but stored in
  no folder of theirs have no hierarchy to preserve and are not included.
* Proton Drive quota applies; the tool prints the account usage at sign-in.
  Large accounts: let it run, and re-run the same command if anything errors.
* Nothing sensitive is stored: no token, session, key or password file is
  ever created (the Google and Proton sessions live in memory for the run
  only). To end the app's access to Google, remove it at
  https://myaccount.google.com/permissions; the Proton sign-in is a normal
  session that ends when the run does.
* The migration copies content; it does not convert sharing settings,
  comments, or version history. Those do not transfer between providers.

## Building from source

The `src/` folder is the whole tool (Go 1.22+). On any machine with Go:

    go build -trimpath -ldflags="-s -w" -o gdrive2proton .

Cross-compiling from one machine, e.g. for Windows or macOS:

    CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -o gdrive2proton.exe .
    CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -o gdrive2proton-macos .

## Code map

* `main.go` — CLI flags, the resume manifest, and `copyTree`/`copyFile`: the
  migration engine that mirrors Drive folders into Proton and streams each
  file from Google to Proton through a temp file (preserving mtime).
* `drive.go` — the Google side: the installed-app OAuth flow (browser
  sign-in, token caching and refresh) and a small read-only REST client
  (list children, download, export Google-native types), with retry and
  backoff on transient errors.
* `proton.go` — the Proton side: browser-based sign-in (a local page served
  on 127.0.0.1, credentials used once and dropped) through Proton-API-Bridge
  (SRP, 2FA, end-to-end encryption), recursive folder creation, and
  same-name-same-size dedupe so re-runs are cheap.
* `common.go` — shared helpers: name sanitizing, human sizes, HTTP retry.

## License

GPL-3.0 — see `LICENSE`. Anyone who modifies and redistributes the tool must
keep the modifications open under the same license. The two vendored Proton
libraries in `third_party/` keep their own licenses (both GPL-compatible);
the patches they carry to support Proton's current upload protocol are part
of this repository.
