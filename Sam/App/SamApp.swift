import SwiftUI

@main
struct SamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            // Verhindert ein leeres SwiftUI-Einstellungsfenster neben dem Menüleisten-Popover.
            CommandGroup(replacing: .appSettings) { }
        }
    }
}
