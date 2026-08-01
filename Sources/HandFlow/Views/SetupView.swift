import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Setup", subtitle: "Two permissions are required for full control") {
                Button("Refresh") { state.permissions.refresh() }
                    .buttonStyle(.bordered)
            }

            ScrollView {
                VStack(spacing: 14) {
                    SetupPermissionCard(
                        symbol: "video.fill",
                        title: "Camera",
                        detail: "Used only while control is active. Frames are analyzed on your Mac and are never saved by HandFlow.",
                        state: state.permissions.camera,
                        actionTitle: state.permissions.camera == .unknown ? "Allow camera" : "Open settings"
                    ) {
                        if state.permissions.camera == .unknown {
                            Task { _ = await state.permissions.requestCamera() }
                        } else {
                            state.permissions.openCameraSettings()
                        }
                    }

                    SetupPermissionCard(
                        symbol: "accessibility",
                        title: "Accessibility",
                        detail: "Lets HandFlow move the pointer, click, scroll, zoom, and reposition the focused window.",
                        state: state.permissions.accessibility,
                        actionTitle: "Open Accessibility Settings"
                    ) {
                        if state.permissions.accessibility == .granted {
                            state.permissions.openAccessibilitySettings()
                        } else {
                            state.permissions.requestAccessibility()
                        }
                    }

                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "lightbulb.max.fill")
                            .foregroundStyle(HandFlowTheme.accent)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("For the best tracking").font(.headline)
                            Text("Face the camera, keep your hand inside the center of the frame, and use soft front lighting. Avoid strong backlight.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .panelStyle()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct SetupPermissionCard: View {
    let symbol: String
    let title: String
    let detail: String
    let state: PermissionState
    let actionTitle: String
    let action: () -> Void

    var bodyView: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(HandFlowTheme.accent)
                .frame(width: 46, height: 46)
                .background(HandFlowTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    PermissionLine(title: "", state: state)
                }
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if state != .granted {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 5)
                } else {
                    Button(actionTitle, action: action)
                        .buttonStyle(.link)
                        .padding(.top, 3)
                }
            }
        }
        .panelStyle()
    }

    var body: some View { bodyView }
}
