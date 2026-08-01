import AppKit
import SwiftUI

struct MenuBarPanel: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: state.isRunning ? "hand.raised.fill" : "hand.raised")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(state.isRunning ? HandFlowTheme.accent : .secondary)
                    .frame(width: 36, height: 36)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.isRunning ? "Control active" : "Control paused")
                        .font(.headline)
                    Text(state.isRunning ? state.gestures.lastAction : "Camera is off")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(15)

            Divider()

            Button {
                state.toggle()
            } label: {
                Label(state.isRunning ? "Pause control" : "Start control", systemImage: state.isRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(.borderedProminent)
            .padding(12)

            Divider()

            HStack {
                Button("Open HandFlow") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.medium))
            .padding(14)
        }
        .frame(width: 300)
        .tint(HandFlowTheme.accent)
    }
}
