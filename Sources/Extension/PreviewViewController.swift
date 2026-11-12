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

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let data: Data
            do {
                data = try Data(contentsOf: url, options: .mappedIfSafe)
            } catch {
                DispatchQueue.main.async { handler(error) }
                return
            }
            guard TransportStream.matches(data.prefix(65536)) else {
                self?.showSource(data, settings: settings, handler: handler)
                return
            }
            DispatchQueue.main.async {
                guard let self else {
                    handler(nil)
                    return
                }
                let video = VideoPreviewView(url: url)
                video.load { size in
                    guard let size else {
                        DispatchQueue.global(qos: .userInitiated).async {
                            self.showSource(data, settings: settings, handler: handler)
                        }
                        return
                    }
                    self.source = ""
                    self.sourceView = nil
                    self.install(video)
                    self.preferredContentSize = settings.sizeMode == .fixed
                        ? NSSize(width: settings.width, height: settings.height)
                        : Self.fittedSize(forVideo: size)
                    handler(nil)
                }
            }
        }
    }

    private func showSource(_ data: Data, settings: PreviewSettings, handler: @escaping (Error?) -> Void) {
        let font = Renderer.font(for: settings)
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
        DispatchQueue.main.async { [weak self] in
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

    private static func fittedSize(forVideo size: NSSize) -> NSSize {
        guard size.width > 0, size.height > 0 else { return NSSize(width: 640, height: 360) }
        let scale = min(1, 960 / size.width, 720 / size.height)
        return NSSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
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
