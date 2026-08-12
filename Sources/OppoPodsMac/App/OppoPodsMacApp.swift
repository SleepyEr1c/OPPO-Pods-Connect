import AppKit
import SwiftUI

@main
struct OppoPodsMacApp: App {
    @StateObject private var model = AppModel()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(model)
                .environmentObject(model.session)
                .environmentObject(model.devices)
        } label: {
            MenuBarLabelView()
                .environmentObject(model.session)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
                .environmentObject(model.session)
                .environmentObject(model.devices)
        }
    }
}
