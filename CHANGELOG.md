# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Settings app: `TSQuickLook.app` now opens a settings window. It shows the registration status and re-registers the extension, switches the appearance (auto, light, dark), picks the font and font size, and sets the preview size (fit to content, or a fixed width and height).
- File extension list in the settings app with presets for `.ts`, `.mts`, `.cts`, `.tsx`, `.js`, `.mjs`, `.cjs`, `.jsx` and custom entries. Apply rewrites `QLSupportedContentTypes` in the installed extension, re-signs it and registers it again. An extension without a registered content type is skipped and named in the result.
- `TSQuickLook --apply` applies the saved extension list without opening a window; `scripts/install.sh` uses it, so a reinstall keeps the selected extensions.

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
