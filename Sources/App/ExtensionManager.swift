import Foundation
import UniformTypeIdentifiers

enum ExtensionManager {
    static let extensionID = "local.tsquicklook.preview"
    static let presets = ["ts", "mts", "cts", "tsx", "js", "mjs", "cjs", "jsx", "log"]

    enum Status { case enabled, registered, ignored, missing }

    struct ToolError: LocalizedError {
        let message: String
        var errorDescription: String? {
            message
        }
    }

    private static let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/"
        + "LaunchServices.framework/Support/lsregister"

    static var appexURL: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/PlugIns/TSQuickLookPreview.appex")
    }

    static func normalize(_ ext: String) -> String? {
        var value = ext.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while value.hasPrefix(".") {
            value.removeFirst()
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1 ... 16).contains(value.count),
              value.unicodeScalars
                  .allSatisfy({
                      $0.isASCII && (("a" ... "z").contains(Character($0)) || ("0" ... "9").contains(Character($0))) })
        else { return nil }
        return value
    }

    static func contentType(for ext: String) -> String? {
        guard let identifier = UTType(filenameExtension: ext)?.identifier,
              !identifier.hasPrefix("dyn.") else { return nil }
        return identifier
    }

    static func installedContentTypes() -> [String] {
        guard let root = readInfoPlist(),
              let ext = root["NSExtension"] as? [String: Any],
              let attributes = ext["NSExtensionAttributes"] as? [String: Any],
              let types = attributes["QLSupportedContentTypes"] as? [String] else { return [] }
        return types
    }

    static func status() -> Status {
        guard let result = try? run("/usr/bin/pluginkit", ["-m", "-A", "-D", "-v", "-i", extensionID])
        else { return .missing }
        for line in result.output.split(whereSeparator: \.isNewline) where line.contains(extensionID) {
            switch line.drop(while: { $0 == " " || $0 == "\t" }).first {
            case "+": return .enabled
            case "-": return .ignored
            default: return .registered
            }
        }
        return .missing
    }

    static func register() throws -> String {
        let bundle = Bundle.main.bundleURL.path
        try require("lsregister", lsregister, ["-f", "-R", bundle])
        var found = false
        for _ in 0 ..< 10 {
            try require("pluginkit", "/usr/bin/pluginkit", ["-a", appexURL.path])
            Thread.sleep(forTimeInterval: 1)
            if status() != .missing {
                found = true
                break
            }
        }
        guard found else {
            throw ToolError(
                message: "Extension did not register. Reason: log show --last 1m --predicate 'process == \"pkd\"'"
            )
        }
        _ = try? run("/usr/bin/qlmanage", ["-r"])
        _ = try? run("/usr/bin/qlmanage", ["-r", "cache"])
        _ = try? run("/usr/bin/killall", ["QuickLookUIService"])
        switch status() {
        case .enabled: return "Extension registered and enabled."
        case .ignored: return "Extension registered but disabled in System Settings."
        default: return "Extension registered."
        }
    }

    static func apply(extensions: [String]) throws -> String {
        var types: [String] = []
        var skipped: [String] = []
        for ext in extensions {
            if let type = contentType(for: ext) {
                if !types.contains(type) {
                    types.append(type)
                }
            } else {
                skipped.append(ext)
            }
        }
        guard !types.isEmpty else {
            throw ToolError(
                message: "No selected extension has a registered content type; the extension would claim nothing."
            )
        }
        guard let entitlements = Bundle.main.url(forResource: "Extension", withExtension: "entitlements") else {
            throw ToolError(message: "Extension.entitlements is missing from the app bundle resources.")
        }
        _ = try? run("/usr/bin/pluginkit", ["-r", appexURL.path])
        try writeContentTypes(types)
        try require(
            "codesign",
            "/usr/bin/codesign",
            ["-f", "-s", "-", "--entitlements", entitlements.path, appexURL.path]
        )
        try require("codesign", "/usr/bin/codesign", ["-f", "-s", "-", Bundle.main.bundleURL.path])
        _ = try register()
        var line = "Applied: " + types.joined(separator: ", ")
        if !skipped.isEmpty {
            line += ". Skipped (no content type): " + skipped.map { "." + $0 }.joined(separator: ", ")
        }
        return line
    }

    static func applyFromCommandLine() -> Int32 {
        do {
            try print(apply(extensions: PreviewSettings.load().extensions))
            return 0
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            return 1
        }
    }

    private static var infoPlistURL: URL {
        appexURL.appendingPathComponent("Contents/Info.plist")
    }

    private static func readInfoPlist() -> [String: Any]? {
        guard let data = try? Data(contentsOf: infoPlistURL),
              let object = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return nil }
        return object as? [String: Any]
    }

    private static func writeContentTypes(_ types: [String]) throws {
        guard var root = readInfoPlist() else {
            throw ToolError(message: "Cannot read \(infoPlistURL.path).")
        }
        var ext = root["NSExtension"] as? [String: Any] ?? [:]
        var attributes = ext["NSExtensionAttributes"] as? [String: Any] ?? [:]
        attributes["QLSupportedContentTypes"] = types
        ext["NSExtensionAttributes"] = attributes
        root["NSExtension"] = ext
        let data = try PropertyListSerialization.data(fromPropertyList: root, format: .xml, options: 0)
        try data.write(to: infoPlistURL, options: .atomic)
    }

    private static func require(_ name: String, _ path: String, _ arguments: [String]) throws {
        let result = try run(path, arguments)
        guard result.status == 0 else {
            let text = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ToolError(message: "\(name) failed (exit \(result.status)): \(text)")
        }
    }

    private static func run(_ path: String, _ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (
            process.terminationStatus,
            String(bytes: data, encoding: .utf8) ?? String(bytes: data, encoding: .isoLatin1) ?? ""
        )
    }
}
