import AppKit
import QuickLookUI

@objc(TSQLPreviewViewController)
final class PreviewViewController: NSViewController, QLPreviewingController {
    private(set) var source = ""
    private(set) var sourceView: SourceView?

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.autoresizingMask = [.width, .height]
        view = container
        preferredContentSize = NSSize(width: 900, height: 700)
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let settings = PreviewSettings.load()
        applyAppearance(settings.appearance)
        let font = Renderer.font(for: settings)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let data: Data
            do {
                data = try Data(contentsOf: url, options: .mappedIfSafe)
            } catch {
                DispatchQueue.main.async { handler(error) }
                return
            }
            let text: NSAttributedString
            let decoded: String
            var size: NSSize?
            if Renderer.isBinary(data) {
                decoded = ""
                text = Renderer.notice("Binary file (\(data.count) bytes), not source text.", font: font)
            } else {
                decoded = Renderer.source(from: data)
                text = Renderer.highlight(decoded, font: font, truncated: data.count > Renderer.maxBytes)
                if settings.sizeMode == .auto {
                    size = Self.fittedSize(for: decoded, font: font)
                }
            }
            let preferred = settings.sizeMode == .fixed
                ? NSSize(width: settings.width, height: settings.height)
                : (size ?? NSSize(width: 520, height: 320))
            DispatchQueue.main.async {
                guard let self else {
                    handler(nil)
                    return
                }
                self.source = decoded
                let content = SourceView(frame: self.view.bounds)
                content.toolbar.isHidden = decoded.isEmpty
                content.toolbar.copyText = { [weak self] in self?.source ?? "" }
                content.show(text)
                self.install(content)
                self.sourceView = content
                self.preferredContentSize = preferred
                handler(nil)
            }
        }
    }

    func install(_ content: NSView) {
        for subview in view.subviews { subview.removeFromSuperview() }
        content.frame = view.bounds
        content.autoresizingMask = [.width, .height]
        view.addSubview(content)
    }

    private func applyAppearance(_ appearance: PreviewSettings.Appearance) {
        switch appearance {
        case .light:
            view.appearance = NSAppearance(named: .aqua)
        case .dark:
            view.appearance = NSAppearance(named: .darkAqua)
        case .auto:
            view.appearance = nil
            let systemDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
            let isDark = view.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            if systemDark && !isDark {
                view.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }

    private static func fittedSize(for text: String, font: NSFont) -> NSSize {
        var longest = 0
        var current = 0
        var lines = 1
        for unit in text.utf8 {
            if unit == 0x0A {
                lines += 1
                longest = max(longest, current)
                current = 0
            } else if unit & 0xC0 != 0x80 {
                current += 1
            }
        }
        longest = max(longest, current)
        let columns = CGFloat(min(longest, 120))
        let width = min(max(columns * Renderer.advance(of: font) + 80, 520), 1100)
        let lineHeight = (font.ascender - font.descender + font.leading) * 1.5
        let height = min(max(CGFloat(lines) * lineHeight + 56 + PreviewToolbar.height, 320), 900)
        return NSSize(width: width.rounded(), height: height.rounded())
    }
}
