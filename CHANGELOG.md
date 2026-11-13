# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- README screenshots: the Quick Look panel, Finder's preview pane, and a real MPEG-2 `.ts` file playing as video.
- Commit hooks from the hooks-lint-format kit: hk with oxfmt, rumdl, actionlint, zizmor, Conventional Commits, and an `hk check` workflow on a macOS runner. Swift files are formatted by swiftformat and linted by swiftlint (`.swiftformat`, `.swiftlint.yml`); tool versions are pinned in `mise.toml`.
- `.log` preview: a `log` preset in the settings app claims `com.apple.log`, and `.log` files use a log grammar (timestamps, levels, error and warning words, `[tags]`, URLs, strings, numbers, separator lines). `.txt` logs are not supported because Quick Look handles `public.plain-text` internally and never asks an extension.
- App icon: an Icon Composer bundle in `Icon/`, compiled into the app by `scripts/build.sh`.
- Settings app: `TSQuickLook.app` now opens a settings window. It shows the registration status and re-registers the extension, switches the appearance (auto, light, dark), picks the font and font size, and sets the preview size (fit to content, or a fixed width and height).
- File extension list in the settings app with presets for `.ts`, `.mts`, `.cts`, `.tsx`, `.js`, `.mjs`, `.cjs`, `.jsx` and custom entries. Apply rewrites `QLSupportedContentTypes` in the installed extension, re-signs it and registers it again. An extension without a registered content type is skipped and named in the result.
- `TSQuickLook --apply` applies the saved extension list without opening a window; `scripts/install.sh` uses it, so a reinstall keeps the selected extensions.
- Copy button in a slim bar above the source. It puts the file's text on the clipboard and shows "Copied" for a moment.
- Video player: a file that is a real MPEG transport stream (sync bytes at 188, 192 or 204 byte intervals) plays in an `AVPlayerView` with inline controls instead of showing the binary notice. Other binary files keep the notice.
- Line-number gutter with git change bars: green for added lines, orange for modified lines, a red marker where lines were removed. A file with uncommitted changes is compared with `HEAD`; a clean file shows the lines its last commit touched. The bar above the source shows the summary ("Uncommitted changes · +3 −3", or the last commit's short hash, age and subject, or "Untracked"). Files outside a repository show line numbers only.
- Git data is read directly from `.git` (refs, index, loose and packed objects) and diffed in-process, because the Quick Look sandbox does not let the extension start `git`.

- Swift sources are formatted with swiftformat and pass swiftlint in strict mode. Long functions are split into helpers, short names are spelled out, and the regular expressions compile without `try!`. Files with invalid UTF-8 now fall back to Latin-1 instead of showing replacement characters.
### Changed

- The extension is now view-based (`QLIsDataBasedPreview` false, principal class `TSQLPreviewViewController`): Finder's preview pane shows the highlighted source instead of the file icon. The source is drawn in a native text view; no HTML is generated.
- Long lines wrap to the width of the preview, and the margins shrink in narrow panes.
- The extension reads `~/Library/Application Support/TSQuickLook/settings.json` (appearance, font, font size, preview size) on every preview. Its sandbox now has read-only access to the file system for that.
- README and the architecture diagram describe the view-based extension, the settings app, the video player, the copy button and the git gutter.

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
