# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

- The extension is now view-based (`QLIsDataBasedPreview` false, principal class `TSQLPreviewViewController`): Finder's preview pane shows the highlighted source instead of the file icon. The source is drawn in a native text view; no HTML is generated.
- Long lines wrap to the width of the preview, and the margins shrink in narrow panes.
- The extension reads `~/Library/Application Support/TSQuickLook/settings.json` (appearance, font, font size, preview size) on every preview. Its sandbox now has read-only access to the file system for that.

### Removed

- `PreviewProvider` and the HTML/CSS renderer.

## [0.1.0] - 2026-11-11

### Added

- Quick Look preview extension that claims `public.mpeg-2-transport-stream` (`.ts`) and `public.avchd-mpeg-2-transport-stream` (`.mts`).
- TypeScript syntax highlighting done in Swift: comments, strings and template literals, numbers, decorators, keywords, capitalized type names and function calls.
- Light and dark colour schemes that follow the system appearance.
- Short notice instead of source for binary files (real MPEG transport streams) and a 2 MB display limit for large files.
- `scripts/build.sh`, `scripts/install.sh` and `scripts/uninstall.sh`, with matching `mise` tasks.
- Architecture diagram in `docs/`.
