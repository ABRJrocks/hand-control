import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    let settings: AppSettings
    let permissions: PermissionManager
    let camera: CameraService
    let systemController: SystemController
    let gestures: GestureEngine

    @Published private(set) var isRunning = false
    @Published private(set) var cameraTelemetry = CameraTelemetry()
    @Published var selectedSection: AppSection = .live

    init() {
        let settings = AppSettings()
        let permissions = PermissionManager()
        let camera = CameraService()
        let systemController = SystemController()

        self.settings = settings
        self.permissions = permissions
        self.camera = camera
        self.systemController = systemController
        gestures = GestureEngine(settings: settings, controller: systemController)

        camera.setFrameHandler { [weak self] frame in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let canControl = self.isRunning && self.permissions.accessibility == .granted
                self.gestures.process(frame, controlsEnabled: canControl)
            }
        }
        camera.setTelemetryHandler { [weak self] telemetry in
            Task { @MainActor [weak self] in
                self?.cameraTelemetry = telemetry
            }
        }
    }

    func start() async {
        guard !isRunning else { return }
        guard await permissions.requestCamera() else {
            selectedSection = .setup
            return
        }
        permissions.refresh()
        isRunning = true
        camera.start()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        camera.stop()
        gestures.reset()
    }

    func toggle() {
        if isRunning {
            stop()
        } else {
            Task { await start() }
        }
    }

    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.canBecomeKey }?.makeKeyAndOrderFront(nil)
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case live = "Live control"
    case gestures = "Gestures"
    case setup = "Setup"
    case preferences = "Preferences"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .live: "viewfinder"
        case .gestures: "hand.raised.fingers.spread"
        case .setup: "checkmark.shield"
        case .preferences: "slider.horizontal.3"
        }
    }
}
