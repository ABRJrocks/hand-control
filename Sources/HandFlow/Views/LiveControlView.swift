import AVFoundation
import SwiftUI

struct LiveControlView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                title: "Live control",
                subtitle: state.isRunning ? state.gestures.lastAction : "Camera processing is paused"
            ) {
                ControlButton()
            }

            HStack(alignment: .top, spacing: 18) {
                CameraStage()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 14) {
                    SignalPanel()
                    PermissionSummary()
                    SafetyPanel()
                }
                .frame(width: 250)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }
}

struct ControlButton: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Button {
            state.toggle()
        } label: {
            Label(state.isRunning ? "Pause control" : "Start control", systemImage: state.isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 15)
                .frame(height: 38)
        }
        .buttonStyle(.plain)
        .foregroundStyle(state.isRunning ? Color.primary : Color.white)
        .background(
            state.isRunning ? Color.primary.opacity(0.08) : HandFlowTheme.accent,
            in: RoundedRectangle(cornerRadius: 11)
        )
    }
}

private struct CameraStage: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HandFlowTheme.radius)
                .fill(Color(nsColor: .underPageBackgroundColor))

            if state.permissions.camera == .granted && state.isRunning {
                CameraPreview(session: state.camera.session, mirrored: state.settings.mirrored)
                    .overlay(HandSkeletonOverlay(frame: state.gestures.frame, mirrored: state.settings.mirrored))
                    .clipShape(RoundedRectangle(cornerRadius: HandFlowTheme.radius))
            } else {
                CameraPlaceholder()
            }

            VStack {
                HStack {
                    Label(state.isRunning ? "ON DEVICE" : "CAMERA OFF", systemImage: state.isRunning ? "lock.fill" : "video.slash.fill")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .foregroundStyle(.white.opacity(0.92))
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
                    Spacer()
                }
                Spacer()
                if state.isRunning {
                    HStack(spacing: 10) {
                        Image(systemName: state.gestures.gesture.symbol)
                        Text(state.gestures.gesture.rawValue)
                        Spacer()
                        Text("\(Int(state.gestures.confidence * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(14)
        }
        .overlay(RoundedRectangle(cornerRadius: HandFlowTheme.radius).stroke(HandFlowTheme.line))
        .aspectRatio(16 / 10, contentMode: .fit)
    }
}

private struct CameraPlaceholder: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: state.permissions.camera == .denied ? "video.slash" : "hand.raised")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            VStack(spacing: 5) {
                Text(state.permissions.camera == .denied ? "Camera access is off" : "Ready when you are")
                    .font(.headline)
                Text("HandFlow does not record or upload camera frames.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if state.permissions.camera == .denied {
                Button("Open Camera Settings") { state.permissions.openCameraSettings() }
            }
        }
    }
}

private struct SignalPanel: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Signal").font(.headline)
            HStack(alignment: .firstTextBaseline) {
                Text(state.gestures.gesture.rawValue)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer()
                Image(systemName: state.gestures.gesture.symbol)
                    .foregroundStyle(HandFlowTheme.accent)
            }
            Divider()
            MetricRow(label: "Tracking", value: state.isRunning ? "\(state.gestures.framesPerSecond) fps" : "Paused")
            MetricRow(label: "Camera frames", value: "\(state.cameraTelemetry.inputFrames)")
            MetricRow(label: "Hand frames", value: "\(state.cameraTelemetry.detectionRate)%")
            MetricRow(label: "Hand", value: state.gestures.frame.chirality.rawValue)
            MetricRow(label: "Confidence", value: "\(Int(state.gestures.confidence * 100))%")
            if let error = state.cameraTelemetry.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .panelStyle()
    }
}

private struct PermissionSummary: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Permissions").font(.headline)
            PermissionLine(title: "Camera", state: state.permissions.camera)
            PermissionLine(title: "Accessibility", state: state.permissions.accessibility)
            if state.permissions.accessibility != .granted {
                Button("Open Accessibility Settings") {
                    state.permissions.requestAccessibility()
                }
                .buttonStyle(.bordered)
            }
        }
        .panelStyle()
    }
}

private struct SafetyPanel: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .foregroundStyle(HandFlowTheme.accent)
            Text("Use the menu-bar hand at any time to pause input immediately.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .panelStyle()
    }
}

private struct MetricRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.caption)
    }
}

struct PermissionLine: View {
    let title: String
    let state: PermissionState
    var body: some View {
        HStack {
            Image(systemName: state == .granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(state == .granted ? HandFlowTheme.accent : Color.orange)
            Text(title).font(.subheadline)
            Spacer()
            Text(state.rawValue).font(.caption).foregroundStyle(.secondary)
        }
    }
}

extension View {
    func panelStyle() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HandFlowTheme.panel.opacity(0.7), in: RoundedRectangle(cornerRadius: HandFlowTheme.radius))
            .overlay(RoundedRectangle(cornerRadius: HandFlowTheme.radius).stroke(HandFlowTheme.line))
    }
}
