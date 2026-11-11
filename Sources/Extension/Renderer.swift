import Foundation

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

    static let style = """
    :root{color-scheme:light dark}
    body{margin:0;padding:14px 18px;background:#fff;color:#1f2328;font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace}
    pre{margin:0;white-space:pre;tab-size:4;font:inherit}
    .c{color:#6e7781;font-style:italic}.s{color:#0a3069}.n{color:#0550ae}.k{color:#cf222e}.t{color:#8250df}.f{color:#6639ba}.d{color:#953800}
    @media(prefers-color-scheme:dark){body{background:#0d1117;color:#e6edf3}.c{color:#8b949e}.s{color:#a5d6ff}.n{color:#79c0ff}.k{color:#ff7b72}.t{color:#ffa657}.f{color:#d2a8ff}.d{color:#ffa657}}
    """

    static func page(for data: Data) -> String {
        let body: String
        if data.prefix(8192).contains(0) {
            body = "<p>Binary MPEG transport stream (\(data.count) bytes), not TypeScript source.</p>"
        } else {
            let note = data.count > maxBytes ? "<p>Showing the first \(maxBytes) bytes.</p>" : ""
            body = note + "<pre>" + highlight(String(decoding: data.prefix(maxBytes), as: UTF8.self)) + "</pre>"
        }
        return "<!doctype html><html><head><meta charset=\"utf-8\"><style>\(style)</style></head><body>\(body)</body></html>"
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    static func highlight(_ source: String) -> String {
        let text = source as NSString
        var html = ""
        var cursor = 0
        tokens.enumerateMatches(in: source, range: NSRange(location: 0, length: text.length)) { match, _, _ in
            guard let match else { return }
            let range = match.range
            html += escape(text.substring(with: NSRange(location: cursor, length: range.location - cursor)))
            cursor = range.location + range.length
            let token = text.substring(with: range)
            let kind = cssClass(for: match, token: token, in: text, after: cursor)
            html += kind.isEmpty ? escape(token) : "<span class=\"\(kind)\">\(escape(token))</span>"
        }
        return html + escape(text.substring(from: cursor))
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
