import AppKit

enum LogRenderer {
    static let fileExtensions: Set<String> = ["log"]

    static let tokens = try! NSRegularExpression(
        pattern: #"(?<t>^\[?\d{4}[-/.]\d{2}[-/.]\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2})?\]?|^\[?\d{2}:\d{2}:\d{2}(?:[.,]\d+)?\]?:?)|(?<r>[-=*#]{5,}[ \t]*$)|(?<e>\b(?:FATAL|CRITICAL|CRIT|PANIC|ERROR|ERR|SEVERE|EMERG|ALERT|[Ee]rror|[Ff]ailed|[Ff]ailure|[Ee]xception|[Ff]atal)\b)|(?<w>\b(?:WARN|WARNING|[Ww]arning)\b)|(?<i>\b(?:INFO|NOTICE)\b)|(?<g>\b(?:DEBUG|TRACE|VERBOSE)\b)|(?<u>\b[a-z][a-z0-9+.-]*://[^\s"'<>\])]+)|(?<s>"(?:\\.|[^"\\\n])*")|(?<b>\[[^\[\]\n]{1,40}\])|(?<n>\b\d+(?:\.\d+)*\b)"#,
        options: [.anchorsMatchLines]
    )

    private static let warningColor = Renderer.dynamic(0x9a6700, 0xd29922)
    private static let infoColor = Renderer.dynamic(0x0969da, 0x58a6ff)

    static func handles(_ url: URL) -> Bool {
        fileExtensions.contains(url.pathExtension.lowercased())
    }

    static func highlight(_ source: String, font: NSFont, truncated: Bool) -> NSAttributedString {
        let result = NSMutableAttributedString(string: source, attributes: Renderer.baseAttributes(font))
        let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        let muted = Renderer.italic(font)
        tokens.enumerateMatches(in: source, range: NSRange(location: 0, length: (source as NSString).length)) { match, _, _ in
            guard let match, let kind = ["t", "r", "e", "w", "i", "g", "u", "s", "b", "n"].first(where: {
                match.range(withName: $0).location != NSNotFound
            }) else { return }
            let range = match.range
            switch kind {
            case "t", "r": result.addAttribute(.foregroundColor, value: Renderer.commentColor, range: range)
            case "e": result.addAttributes([.foregroundColor: Renderer.keywordColor, .font: bold], range: range)
            case "w": result.addAttributes([.foregroundColor: warningColor, .font: bold], range: range)
            case "i": result.addAttribute(.foregroundColor, value: infoColor, range: range)
            case "g": result.addAttributes([.foregroundColor: Renderer.commentColor, .font: muted], range: range)
            case "u": result.addAttribute(.foregroundColor, value: Renderer.functionColor, range: range)
            case "s": result.addAttribute(.foregroundColor, value: Renderer.stringColor, range: range)
            case "b": result.addAttribute(.foregroundColor, value: Renderer.typeColor, range: range)
            default: result.addAttribute(.foregroundColor, value: Renderer.numberColor, range: range)
            }
        }
        if truncated { Renderer.appendTruncationNote(to: result, font: font) }
        return result
    }
}
