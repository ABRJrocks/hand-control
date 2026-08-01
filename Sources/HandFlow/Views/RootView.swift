import AppKit
import SwiftUI

enum HandFlowTheme {
    static let accent = Color(red: 0.09, green: 0.45, blue: 0.36)
    static let sidebar = Color(nsColor: .windowBackgroundColor).opacity(0.72)
    static let panel = Color(nsColor: .controlBackgroundColor)
    static let line = Color.primary.opacity(0.09)
    static let secondary = Color.secondary
    static let radius: CGFloat = 16
}

struct RootView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 224)
            Divider().opacity(0.55)
            Group {
                switch state.selectedSection {
                case .live: LiveControlView()
                case .gestures: GestureLibraryView()
                case .setup: SetupView()
                case .preferences: PreferencesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .background(.regularMaterial)
        .tint(HandFlowTheme.accent)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.permissions.refresh()
        }
    }
}

private struct Sidebar: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(HandFlowTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(HandFlowTheme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text("HandFlow").font(.headline)
                    Text("Spatial control").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 28)

            VStack(spacing: 5) {
                ForEach(AppSection.allCases) { section in
                    Button {
                        state.selectedSection = section
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: section.symbol)
                                .frame(width: 18)
                            Text(section.rawValue)
                            Spacer()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(state.selectedSection == section ? Color.primary : Color.secondary)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(
                            state.selectedSection == section ? Color.primary.opacity(0.075) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(state.isRunning ? HandFlowTheme.accent : Color.secondary.opacity(0.45))
                        .frame(width: 7, height: 7)
                    Text(state.isRunning ? "Camera active" : "Camera off")
                        .font(.caption.weight(.medium))
                    Spacer()
                }
                Text(state.isRunning ? "Frames stay on this Mac." : "Start only when you are ready.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: HandFlowTheme.radius))
            .padding(12)
        }
        .background(HandFlowTheme.sidebar)
    }
}
