import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let sensitivity = "gesture.sensitivity"
        static let smoothing = "pointer.smoothing"
        static let pointerSpeed = "pointer.speed"
        static let mirrored = "camera.mirrored"
        static let launchAtLogin = "app.launchAtLogin"
        static let enabledFeatures = "gesture.enabledFeatures"
        static let motionProfileVersion = "gesture.motionProfileVersion"
    }

    private let defaults: UserDefaults

    @Published var sensitivity: Double {
        didSet { defaults.set(sensitivity, forKey: Key.sensitivity) }
    }

    @Published var smoothing: Double {
        didSet { defaults.set(smoothing, forKey: Key.smoothing) }
    }

    @Published var pointerSpeed: Double {
        didSet { defaults.set(pointerSpeed, forKey: Key.pointerSpeed) }
    }

    @Published var mirrored: Bool {
        didSet { defaults.set(mirrored, forKey: Key.mirrored) }
    }

    @Published var enabledFeatures: Set<ControlFeature> {
        didSet { defaults.set(enabledFeatures.map(\ .rawValue), forKey: Key.enabledFeatures) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedSensitivity = defaults.object(forKey: Key.sensitivity) as? Double ?? 0.42
        let savedSmoothing = defaults.object(forKey: Key.smoothing) as? Double ?? 0.84
        let savedPointerSpeed = defaults.object(forKey: Key.pointerSpeed) as? Double ?? 0.78
        let initialSensitivity: Double
        let initialSmoothing: Double
        let initialPointerSpeed: Double
        if defaults.integer(forKey: Key.motionProfileVersion) < 3 {
            initialSensitivity = min(savedSensitivity, 0.42)
            initialSmoothing = max(savedSmoothing, 0.84)
            initialPointerSpeed = max(savedPointerSpeed, 0.78)
            defaults.set(3, forKey: Key.motionProfileVersion)
            defaults.set(initialSensitivity, forKey: Key.sensitivity)
            defaults.set(initialSmoothing, forKey: Key.smoothing)
            defaults.set(initialPointerSpeed, forKey: Key.pointerSpeed)
        } else {
            initialSensitivity = savedSensitivity
            initialSmoothing = savedSmoothing
            initialPointerSpeed = savedPointerSpeed
        }
        sensitivity = initialSensitivity
        smoothing = initialSmoothing
        pointerSpeed = initialPointerSpeed
        mirrored = defaults.object(forKey: Key.mirrored) as? Bool ?? true

        if let saved = defaults.stringArray(forKey: Key.enabledFeatures) {
            enabledFeatures = Set(saved.compactMap(ControlFeature.init(rawValue:)))
        } else {
            enabledFeatures = Set(ControlFeature.allCases)
        }
    }

    func isEnabled(_ feature: ControlFeature) -> Bool {
        enabledFeatures.contains(feature)
    }

    func setEnabled(_ feature: ControlFeature, _ enabled: Bool) {
        if enabled {
            enabledFeatures.insert(feature)
        } else {
            enabledFeatures.remove(feature)
        }
    }
}
