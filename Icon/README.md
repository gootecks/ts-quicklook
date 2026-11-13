# App icon

The icon shows highlighted code lines on a graphite tile, under a magnifying glass whose lens is the TypeScript mark.

`TSQuickLook.icon` is an Icon Composer bundle. `scripts/build.sh` compiles it with `actool` into `Assets.car` (macOS 26+) and `TSQuickLook.icns` (older systems). This step needs Xcode 26 or later. Without it the build prints a warning and the app has no icon.

- `TSQuickLook.icon/Assets/` holds one SVG per layer.
- `TSQuickLook.icon/icon.json` holds layer order, glass settings, and the light and dark graphite fills. The first group and the first layer in each list are the top ones.
- `previews/sheet.png` shows the macOS renders: light, dark, tinted light, tinted dark, then 128, 64 and 32 px.
- `previews/marketing-1024.png` is an opaque 1024 px render.

## Groups

| Group     | Layers        | Notes                                    |
| --------- | ------------- | ---------------------------------------- |
| magnifier | magnifier     | Silver ring and handle                   |
| lens      | letters, lens | White TS letters on a blue radial disc   |
| code      | code          | Code rows in white, blue and yellow      |

## Colours

The colours come from the TypeScript brand palette: `#3178C6`, `#358EF1` and `#235A97` for the lens, `#358EF1` and `#F1DD35` for the coloured code rows. The TS letters are the official lettermark path, scaled to fit the lens. TypeScript and its logo are trademarks of Microsoft.

## Editing

Edit with Icon Composer or the `icon-composer` MCP tools, then re-render the previews. Run `mise run build` before committing, because `actool` validates rules that the preview renderer does not. It rejects more than four visible groups.
