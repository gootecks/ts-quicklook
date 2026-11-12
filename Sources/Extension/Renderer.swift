import AppKit

enum Renderer {
    static let maxBytes = 2_000_000

    static let keywords: Set<String> = [
        "abstract", "any", "as", "asserts", "async", "await", "bigint", "boolean", "break", "case", "catch",
        "class", "const", "constructor", "continue", "debugger", "declare", "default", "delete", "do", "else",
        "enum", "export", "extends", "false", "finally", "for", "from", "function", "get", "if", "implements",
        "import", "in", "infer", "instanceof", "interface", "is", "keyof", "let", "module", "namespace", "never",
        "new", "null", "number", "object", "of", "override", "private", "protected", "public", "readonly",
        "return", "satisfies", "set", "static", "string", "super", "switch", "symbol", "this", "throw", "true",
        "try", "type", "typeof", "undefined", "unique", "unknown", "var", "void", "while", "with", "yield",
    ]

    static let tokens = try! NSRegularExpression(
        pattern: #"(?<c>//[^\n]*|/\*[\s\S]*?\*/)|(?<s>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|`(?:\\[\s\S]|[^`\\])*`)|(?<n>\b(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|0[oO][0-7_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?)n?\b)|(?<d>@[A-Za-z_$][\w$]*)|(?<w>[A-Za-z_$][\w$]*)"#
    )

    static func dynamic(_ light: UInt32, _ dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return color(isDark ? dark : light)
        }
    }

    private static func color(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    static let background = dynamic(0xffffff, 0x0d1117)
    static let foreground = dynamic(0x1f2328, 0xe6edf3)

    static let commentColor = dynamic(0x6e7781, 0x8b949e)
    static let stringColor = dynamic(0x0a3069, 0xa5d6ff)
    static let numberColor = dynamic(0x0550ae, 0x79c0ff)
    static let keywordColor = dynamic(0xcf222e, 0xff7b72)
    static let typeColor = dynamic(0x8250df, 0xffa657)
    static let functionColor = dynamic(0x6639ba, 0xd2a8ff)
    private static let decoratorColor = dynamic(0x953800, 0xffa657)

    static func isBinary(_ data: Data) -> Bool {
        data.prefix(8192).contains(0)
    }

    static func source(from data: Data) -> String {
        String(decoding: data.prefix(maxBytes), as: UTF8.self)
    }

    static func font(for settings: PreviewSettings) -> NSFont {
        let size = CGFloat(settings.fontSize)
        if !settings.fontName.isEmpty, let named = NSFont(name: settings.fontName, size: size) {
            return named
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static func italic(_ font: NSFont) -> NSFont {
        let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(.italic))
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }

    private static func paragraphStyle(for font: NSFont) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        let natural = font.ascender - font.descender + font.leading
        style.lineSpacing = max(0, (natural * 1.5 - natural).rounded())
        style.lineBreakMode = .byWordWrapping
        style.tabStops = []
        style.defaultTabInterval = 4 * advance(of: font)
        return style
    }

    static func advance(of font: NSFont) -> CGFloat {
        let glyph = font.glyph(withName: "space")
        let width = font.advancement(forGlyph: glyph).width
        return width > 0 ? width : font.pointSize * 0.6
    }

    static func baseAttributes(_ font: NSFont) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: foreground, .paragraphStyle: paragraphStyle(for: font)]
    }

    static func highlight(_ source: String, font: NSFont, truncated: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString(string: source, attributes: baseAttributes(font))
        let text = source as NSString
        let commentFont = italic(font)
        tokens.enumerateMatches(in: source, range: NSRange(location: 0, length: text.length)) { match, _, _ in
            guard let match else { return }
            let range = match.range
            let token = text.substring(with: range)
            let kind = cssClass(for: match, token: token, in: text, after: range.location + range.length)
            switch kind {
            case "c":
                result.addAttributes([.foregroundColor: commentColor, .font: commentFont], range: range)
            case "s": result.addAttribute(.foregroundColor, value: stringColor, range: range)
            case "n": result.addAttribute(.foregroundColor, value: numberColor, range: range)
            case "k": result.addAttribute(.foregroundColor, value: keywordColor, range: range)
            case "t": result.addAttribute(.foregroundColor, value: typeColor, range: range)
            case "f": result.addAttribute(.foregroundColor, value: functionColor, range: range)
            case "d": result.addAttribute(.foregroundColor, value: decoratorColor, range: range)
            default: break
            }
        }
        if truncated { appendTruncationNote(to: result, font: font) }
        return result
    }

    static func appendTruncationNote(to result: NSMutableAttributedString, font: NSFont) {
        var attributes = baseAttributes(font)
        attributes[.foregroundColor] = commentColor
        result.append(NSAttributedString(string: "\n\nShowing the first \(maxBytes) bytes.", attributes: attributes))
    }

    static func notice(_ message: String, font: NSFont) -> NSAttributedString {
        NSAttributedString(string: message, attributes: baseAttributes(font))
    }

    static func cssClass(for match: NSTextCheckingResult, token: String, in text: NSString, after end: Int) -> String {
        for name in ["c", "s", "n", "d"] where match.range(withName: name).location != NSNotFound {
            return name
        }
        if keywords.contains(token) { return "k" }
        if let first = token.unicodeScalars.first, CharacterSet.uppercaseLetters.contains(first) { return "t" }
        var index = end
        while index < text.length, text.character(at: index) == 0x20 { index += 1 }
        return index < text.length && text.character(at: index) == 0x28 ? "f" : ""
    }
}
