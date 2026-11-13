import AppKit

enum LogRenderer {
    static let fileExtensions: Set<String> = ["log"]

    private static let kinds = ["t", "r", "e", "w", "i", "g", "u", "s", "b", "n"]

    static let tokens = Renderer.compile(
        #"(?<t>^\[?\d{4}[-/.]\d{2}[-/.]\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2})?\]?"#,
        #"|^\[?\d{2}:\d{2}:\d{2}(?:[.,]\d+)?\]?:?)|"#,
        #"(?<r>[-=*#]{5,}[ \t]*$)|"#,
        #"(?<e>\b(?:FATAL|CRITICAL|CRIT|PANIC|ERROR|ERR|SEVERE|EMERG|ALERT|"#,
        #"[Ee]rror|[Ff]ailed|[Ff]ailure|[Ee]xception|[Ff]atal)\b)|"#,
        #"(?<w>\b(?:WARN|WARNING|[Ww]arning)\b)|"#,
        #"(?<i>\b(?:INFO|NOTICE)\b)|"#,
        #"(?<g>\b(?:DEBUG|TRACE|VERBOSE)\b)|"#,
        #"(?<u>\b[a-z][a-z0-9+.-]*://[^\s"'<>\])]+)|"#,
        #"(?<s>"(?:\\.|[^"\\\n])*")|"#,
        #"(?<b>\[[^\[\]\n]{1,40}\])|"#,
        #"(?<n>\b\d+(?:\.\d+)*\b)"#,
        options: [.anchorsMatchLines]
    )

    private static let warningColor = Renderer.dynamic(0x9A6700, 0xD29922)
    private static let infoColor = Renderer.dynamic(0x0969DA, 0x58A6FF)

    static func handles(_ url: URL) -> Bool {
        fileExtensions.contains(url.pathExtension.lowercased())
    }

    static func highlight(_ source: String, font: NSFont, truncated: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString(string: source, attributes: Renderer.baseAttributes(font))
        let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        let muted = Renderer.italic(font)
        tokens.enumerateMatches(in: source, range: NSRange(
            location: 0,
            length: (source as NSString).length
        )) { match, _, _ in
            guard let match, let kind = kinds.first(where: {
                match.range(withName: $0).location != NSNotFound
            }) else { return }
            result.addAttributes(attributes(for: kind, bold: bold, muted: muted), range: match.range)
        }
        if truncated {
            Renderer.appendTruncationNote(to: result, font: font)
        }
        return result
    }

    private static func attributes(for kind: String, bold: NSFont, muted: NSFont) -> [NSAttributedString.Key: Any] {
        switch kind {
        case "t", "r": [.foregroundColor: Renderer.commentColor]
        case "e": [.foregroundColor: Renderer.keywordColor, .font: bold]
        case "w": [.foregroundColor: warningColor, .font: bold]
        case "i": [.foregroundColor: infoColor]
        case "g": [.foregroundColor: Renderer.commentColor, .font: muted]
        case "u": [.foregroundColor: Renderer.functionColor]
        case "s": [.foregroundColor: Renderer.stringColor]
        case "b": [.foregroundColor: Renderer.typeColor]
        default: [.foregroundColor: Renderer.numberColor]
        }
    }
}
