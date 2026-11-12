# TSQuickLook

A small macOS Quick Look extension that previews `.ts` and `.mts` TypeScript files as syntax-highlighted source.

## Why

macOS assigns the `.ts` extension to MPEG-2 transport stream video (`public.mpeg-2-transport-stream`) and `.mts` to AVCHD video (`public.avchd-mpeg-2-transport-stream`). Quick Look therefore treats TypeScript files as broken movies and shows the generic file preview. Source-code previewers such as Syntax Highlight do not claim those two types, so they are never asked.

TSQuickLook claims both types and renders the file as text.

## Requirements

- macOS 13 or later. Tested only on macOS 27.3 beta on Apple Silicon.
- Xcode or the Command Line Tools (`xcode-select --install`) for `swiftc`, `clang` and `codesign`.
- Xcode 26 or later for the app icon. Without it the build still works and the app has no icon.

## Install

```sh
git clone git@github.com:gootecks/ts-quicklook.git
cd ts-quicklook
mise run install
```

Without `mise`: `sh scripts/install.sh`.

The script builds the app, signs it ad hoc, copies it to `~/Applications/TSQuickLook.app`, registers the extension and restarts Quick Look. Select a `.ts` file in Finder and press Space.

Check the registration:

```sh
pluginkit -m -A -D -v -i local.tsquicklook.preview
```

Try it from the terminal:

```sh
qlmanage -p examples/sample.ts
```

## Uninstall

```sh
mise run uninstall
```

Without `mise`: `sh scripts/uninstall.sh`.

## How it works

![Architecture](docs/architecture.png)

- `TSQuickLook.app` is an empty container app. macOS only loads extensions that live inside an app bundle.
- `TSQuickLookPreview.appex` is a sandboxed Quick Look preview extension. Its `Info.plist` lists the two video types under `QLSupportedContentTypes`.
- `PreviewProvider` reads the file and returns an HTML reply.
- `Renderer` tokenizes the source with one regular expression and wraps tokens in `<span>` elements. Colours come from CSS and follow light or dark appearance. No JavaScript runs.

The diagram source is `docs/architecture.html`.

## Limitations

- Real video `.ts` and `.mts` files no longer get the built-in movie preview while the extension is installed. They show a one-line notice instead.
- The highlighter is a tokenizer, not a parser. Regular-expression literals are not recognized, and JSX is not handled (`.tsx` is a different type and is not claimed).
- Files larger than 2 MB are cut off at 2 MB.
- The build is signed ad hoc for the machine that built it. It is not notarized and is not meant to be distributed as a binary.
- Thumbnails and Spotlight are not covered, only the Quick Look preview.

## Troubleshooting

- **The extension does not register.** Read the reason from PlugInKit: `log show --last 1m --predicate 'process == "pkd"'`. PlugInKit rejects extensions under `/tmp`; keep the app in `~/Applications`.
- **The old preview still appears.** Run `qlmanage -r; qlmanage -r cache; killall QuickLookUIService` and try again.
- **Check which extension handled a file.** Run `qlmanage -p file.ts`, then `log show --last 30s --info --predicate 'eventMessage CONTAINS "xpcservice<"'` and look for `local.tsquicklook.preview`.

## Layout

| Path | Purpose |
|---|---|
| `Sources/Extension/` | `PreviewProvider.swift`, `Renderer.swift` |
| `Sources/App/main.c` | Container app entry point |
| `Resources/` | `Info.plist` files and the extension entitlements |
| `Icon/` | App icon bundle, previews and notes |
| `scripts/` | `build.sh`, `install.sh`, `uninstall.sh` |
| `examples/sample.ts` | Sample file for a manual check |
| `docs/` | Architecture diagram |

See [CHANGELOG.md](CHANGELOG.md) for release notes.
