import AppKit
import SwiftUI

@main
struct HandFlowApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("HandFlow", id: "main") {
            RootView()
                .environmentObject(state)
                .frame(minWidth: 940, minHeight: 640)
                .onAppear { state.permissions.refresh() }
        }
        .defaultSize(width: 1120, height: 760)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(state)
        } label: {
            Image(systemName: state.isRunning ? "hand.raised.fill" : "hand.raised")
                .accessibilityLabel(state.isRunning ? "HandFlow active" : "HandFlow paused")
        }
        .menuBarExtraStyle(.window)
    }
}
