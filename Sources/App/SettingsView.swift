import SwiftUI
import AppKit

private struct FontChoice: Hashable {
    let family: String
    let postScriptName: String
}

final class SettingsModel: ObservableObject {
    @Published var settings: PreviewSettings {
        didSet {
            guard settings != oldValue else { return }
            do {
                try settings.save()
                saveError = nil
            } catch {
                saveError = error.localizedDescription
            }
        }
    }
    @Published var saveError: String?
    @Published var status = ExtensionManager.Status.missing
    @Published var registering = false
    @Published var registerMessage: String?
    @Published var applying = false
    @Published var applyMessage: String?
    @Published var installedTypes = Set<String>()
    @Published var newExtension = ""

    init() {
        settings = PreviewSettings.load()
        refresh()
    }

    func refresh() {
        DispatchQueue.global().async {
            let status = ExtensionManager.status()
            let types = Set(ExtensionManager.installedContentTypes())
            DispatchQueue.main.async {
                self.status = status
                self.installedTypes = types
            }
        }
    }

    func register() {
        registering = true
        registerMessage = nil
        DispatchQueue.global().async {
            let message: String
            do { message = try ExtensionManager.register() } catch { message = error.localizedDescription }
            DispatchQueue.main.async {
                self.registerMessage = message
                self.registering = false
                self.refresh()
            }
        }
    }

    func apply() {
        applying = true
        applyMessage = nil
        let extensions = settings.extensions
        DispatchQueue.global().async {
            let message: String
            do { message = try ExtensionManager.apply(extensions: extensions) } catch { message = error.localizedDescription }
            DispatchQueue.main.async {
                self.applyMessage = message
                self.applying = false
                self.refresh()
            }
        }
    }

    var listedExtensions: [String] {
        let custom = settings.extensions.filter { !ExtensionManager.presets.contains($0) }
        return ExtensionManager.presets + custom
    }

    var selectedTypes: Set<String> {
        Set(settings.extensions.compactMap { ExtensionManager.contentType(for: $0) })
    }

    func binding(for ext: String) -> Binding<Bool> {
        Binding(
            get: { self.settings.extensions.contains(ext) },
            set: { on in
                if on {
                    if !self.settings.extensions.contains(ext) { self.settings.extensions.append(ext) }
                } else {
                    self.settings.extensions.removeAll { $0 == ext }
                }
            }
        )
    }

    func remove(_ ext: String) {
        settings.extensions.removeAll { $0 == ext }
    }

    func addExtension() {
        guard let ext = ExtensionManager.normalize(newExtension) else { return }
        if !settings.extensions.contains(ext) { settings.extensions.append(ext) }
        newExtension = ""
    }
}

struct SettingsView: View {
    @StateObject private var model = SettingsModel()

    var body: some View {
        Form {
            if let error = model.saveError {
                Text(error).foregroundColor(.red)
            }
            ExtensionSection(model: model)
            AppearanceSection(model: model)
            FontSection(model: model)
            SizeSection(model: model)
            ExtensionsSection(model: model)
        }
        .formStyle(.grouped)
    }
}

private struct ExtensionSection: View {
    @ObservedObject var model: SettingsModel

    private var statusText: String {
        switch model.status {
        case .enabled: return "Enabled"
        case .registered: return "Registered"
        case .ignored: return "Disabled in System Settings"
        case .missing: return "Not registered"
        }
    }

    var body: some View {
        Section("Extension") {
            LabeledContent("Status", value: statusText)
            HStack {
                Button("Re-register") { model.register() }
                    .disabled(model.registering)
                if model.registering { ProgressView().controlSize(.small) }
            }
            if let message = model.registerMessage {
                Text(message).font(.caption).foregroundColor(.secondary).textSelection(.enabled)
            }
        }
    }
}

private struct AppearanceSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Section("Appearance") {
            Picker("Appearance", selection: $model.settings.appearance) {
                Text("Auto").tag(PreviewSettings.Appearance.auto)
                Text("Light").tag(PreviewSettings.Appearance.light)
                Text("Dark").tag(PreviewSettings.Appearance.dark)
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct FontSection: View {
    @ObservedObject var model: SettingsModel
    private let choices: [FontChoice] = FontSection.fixedPitchChoices()

    private static func fixedPitchChoices() -> [FontChoice] {
        let manager = NSFontManager.shared
        var result: [FontChoice] = []
        for family in manager.availableFontFamilies {
            guard let font = manager.font(withFamily: family, traits: [], weight: 5, size: 12), font.isFixedPitch else { continue }
            result.append(FontChoice(family: family, postScriptName: font.fontName))
        }
        return result.sorted { $0.family.localizedCaseInsensitiveCompare($1.family) == .orderedAscending }
    }

    private var unlisted: String? {
        let name = model.settings.fontName
        guard !name.isEmpty, !choices.contains(where: { $0.postScriptName == name }) else { return nil }
        return name
    }

    var body: some View {
        Section("Font") {
            Picker("Font", selection: $model.settings.fontName) {
                Text("System Monospaced").tag("")
                if let name = unlisted { Text(name).tag(name) }
                ForEach(choices, id: \.postScriptName) { choice in
                    Text(choice.family).tag(choice.postScriptName)
                }
            }
            Stepper(value: $model.settings.fontSize, in: 9...24, step: 1) {
                Text("Size: \(Int(model.settings.fontSize)) pt")
            }
        }
    }
}

private struct SizeSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Section("Preview size") {
            Picker("Size", selection: $model.settings.sizeMode) {
                Text("Auto").tag(PreviewSettings.SizeMode.auto)
                Text("Fixed").tag(PreviewSettings.SizeMode.fixed)
            }
            .pickerStyle(.segmented)
            if model.settings.sizeMode == .fixed {
                DimensionRow(title: "Width", value: $model.settings.width, range: 400...2000)
                DimensionRow(title: "Height", value: $model.settings.height, range: 300...1600)
            }
            Text("Auto fits the window to the file's content.")
                .font(.caption).foregroundColor(.secondary)
        }
    }
}

private struct DimensionRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    private var clamped: Binding<Double> {
        Binding(
            get: { value },
            set: { value = min(max($0, range.lowerBound), range.upperBound) }
        )
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: clamped, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Stepper(title, value: clamped, in: range, step: 50)
                .labelsHidden()
        }
    }
}

private struct ExtensionsSection: View {
    @ObservedObject var model: SettingsModel

    @State private var adding = false

    private var pending: Bool { model.installedTypes != model.selectedTypes }

    var body: some View {
        Section("File extensions") {
            ForEach(model.listedExtensions, id: \.self) { ext in
                ExtensionRow(model: model, ext: ext)
            }
            if adding {
                HStack {
                    TextField("Extension", text: $model.newExtension, prompt: Text("tsx"))
                        .onSubmit { model.addExtension() }
                    Button("Add") { model.addExtension() }
                        .disabled(ExtensionManager.normalize(model.newExtension) == nil)
                    Button("Done") {
                        model.newExtension = ""
                        adding = false
                    }
                }
            } else {
                Button("Add extension…") { adding = true }
            }
            if pending {
                Text("Changes not applied").foregroundColor(.orange)
            }
            HStack {
                Button("Apply") { model.apply() }
                    .disabled(model.applying)
                if model.applying { ProgressView().controlSize(.small) }
            }
            if let message = model.applyMessage {
                Text(message).font(.caption).foregroundColor(.secondary).textSelection(.enabled)
            }
            Text("Applying re-signs the extension and restarts Quick Look.")
                .font(.caption).foregroundColor(.secondary)
        }
    }
}

private struct ExtensionRow: View {
    @ObservedObject var model: SettingsModel
    let ext: String

    var body: some View {
        let type = ExtensionManager.contentType(for: ext)
        HStack {
            Toggle(isOn: model.binding(for: ext)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(".\(ext)")
                    if let type {
                        Text(type).font(.caption).foregroundColor(.secondary)
                    } else {
                        Text("No content type registered").font(.caption).foregroundColor(.orange)
                    }
                }
            }
            if !ExtensionManager.presets.contains(ext) {
                Button {
                    model.remove(ext)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("Remove .\(ext)")
            }
        }
    }
}
