import SwiftUI
import AppKit

@main
enum Main {
    static func main() {
        if CommandLine.arguments.contains("--apply") {
            exit(ExtensionManager.applyFromCommandLine())
        }
        TSQuickLookApp.main()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct TSQuickLookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("TSQuickLook Settings") {
            SettingsView()
                .frame(minWidth: 520, maxWidth: 520, minHeight: 480)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 520, height: 760)
    }
}
