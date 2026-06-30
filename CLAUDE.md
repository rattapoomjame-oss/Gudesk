# GuDesk — Claude Code Guide

GuDesk is a branded remote desktop application forked from RustDesk.
Core networking, codec, and relay code remain upstream-compatible.

## Architecture

- **Core (Rust):** `src/` + `libs/` — upstream RustDesk, touch only when necessary
- **Custom features (Rust):** `gudesk/src/` — GuDesk-specific modules (directory system, status, etc.)
- **Flutter UI:** `flutter/` — upstream shell + GuDesk screens in `flutter/lib/gudesk/`
- **Database migrations:** `gudesk/migrations/` — SQLite schema changes

## Development Rules

1. Keep upstream `src/` and `libs/` as close to RustDesk HEAD as possible
2. All GuDesk-specific Rust code lives in `gudesk/src/`
3. All GuDesk-specific Flutter code lives in `flutter/lib/gudesk/`
4. Every feature must have unit tests
5. Every commit must be atomic
6. Use `gudesk/migrations/` for all SQLite schema changes
7. Use feature flags (Cargo features) for experimental functionality
8. All UI must support dark mode

## Bundle Identity

- App name: `GuDesk`
- macOS bundle ID: `com.gudesk.app`
- URL scheme: `gudesk://`
- Rust lib name: `librustdesk` (kept for upstream compat — do not rename)

## App Name

The runtime app name is controlled by `APP_NAME` in `libs/hbb_common/src/config.rs` (set to "GuDesk").
The `is_rustdesk()` check in `src/common.rs` returns false for GuDesk — this disables upstream-specific cloud routes.

## Development Phases

- **Phase 1 (done):** Branding, build system
- **Phase 2:** Directory system (`gudesk/src/directory.rs`, `flutter/lib/gudesk/directory/`)
- **Phase 3:** Online status via WebSocket
- **Phase 4:** Session recording (MP4)
- **Phase 5:** File transfer improvements
- **Phase 6:** Auto-update infrastructure

## Build (macOS)

```bash
# Install deps
brew install nasm yasm

# Build Rust core
source ~/.cargo/env
cargo build --release --features flutter

# Build Flutter app
cd flutter
flutter pub get
flutter build macos --release
```
