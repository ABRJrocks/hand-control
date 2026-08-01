import AppKit
import ApplicationServices
import AVFoundation
import Foundation

enum PermissionState: String {
    case unknown = "Not requested"
    case granted = "Allowed"
    case denied = "Needs access"
    case restricted = "Restricted"
}

@MainActor
final class PermissionManager: ObservableObject {
    @Published private(set) var camera: PermissionState = .unknown
    @Published private(set) var accessibility: PermissionState = .unknown
    private var refreshTimer: Timer?

    init() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func refresh() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: camera = .granted
        case .denied: camera = .denied
        case .restricted: camera = .restricted
        case .notDetermined: camera = .unknown
        @unknown default: camera = .unknown
        }
        accessibility = AXIsProcessTrusted() ? .granted : .denied
    }

    func requestCamera() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let granted: Bool
        if status == .notDetermined {
            granted = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            granted = status == .authorized
        }
        refresh()
        if !granted && status != .notDetermined {
            openCameraSettings()
        }
        return granted
    }

    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        refresh()
        if accessibility != .granted {
            openAccessibilitySettings()
        }
    }

    func openCameraSettings() {
        openSettings("Privacy_Camera")
    }

    func openAccessibilitySettings() {
        openSettings("Privacy_Accessibility")
    }

    private func openSettings(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
