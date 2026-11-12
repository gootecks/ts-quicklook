import Foundation

struct PreviewSettings: Codable, Equatable {
    enum Appearance: String, Codable, CaseIterable { case auto, light, dark }
    enum SizeMode: String, Codable, CaseIterable { case auto, fixed }

    var appearance = Appearance.auto
    var fontName = ""
    var fontSize = 12.0
    var sizeMode = SizeMode.auto
    var width = 900.0
    var height = 700.0
    var extensions = ["ts", "mts"]

    static let fileURL: URL = {
        let home = getpwuid(getuid()).flatMap { String(validatingUTF8: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home).appendingPathComponent("Library/Application Support/TSQuickLook/settings.json")
    }()

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        appearance = try values.decodeIfPresent(Appearance.self, forKey: .appearance) ?? appearance
        fontName = try values.decodeIfPresent(String.self, forKey: .fontName) ?? fontName
        fontSize = try values.decodeIfPresent(Double.self, forKey: .fontSize) ?? fontSize
        sizeMode = try values.decodeIfPresent(SizeMode.self, forKey: .sizeMode) ?? sizeMode
        width = try values.decodeIfPresent(Double.self, forKey: .width) ?? width
        height = try values.decodeIfPresent(Double.self, forKey: .height) ?? height
        extensions = try values.decodeIfPresent([String].self, forKey: .extensions) ?? extensions
    }

    static func load() -> PreviewSettings {
        guard let data = try? Data(contentsOf: fileURL),
              let settings = try? JSONDecoder().decode(PreviewSettings.self, from: data) else { return PreviewSettings() }
        return settings
    }

    func save() throws {
        try FileManager.default.createDirectory(at: Self.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: Self.fileURL, options: .atomic)
    }
}
