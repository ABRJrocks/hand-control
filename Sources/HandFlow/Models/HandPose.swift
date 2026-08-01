import CoreGraphics
import Foundation

enum HandJoint: String, CaseIterable, Sendable {
    case wrist
    case thumbCMC
    case thumbMP
    case thumbIP
    case thumbTip
    case indexMCP
    case indexPIP
    case indexDIP
    case indexTip
    case middleMCP
    case middlePIP
    case middleDIP
    case middleTip
    case ringMCP
    case ringPIP
    case ringDIP
    case ringTip
    case littleMCP
    case littlePIP
    case littleDIP
    case littleTip
}

struct HandLandmark: Sendable, Equatable {
    let point: CGPoint
    let confidence: Float
}

struct HandPoseFrame: Sendable {
    let landmarks: [HandJoint: HandLandmark]
    let timestamp: TimeInterval
    let chirality: Handedness

    static func empty(at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) -> HandPoseFrame {
        HandPoseFrame(landmarks: [:], timestamp: timestamp, chirality: .unknown)
    }

    subscript(_ joint: HandJoint) -> CGPoint? {
        // Vision's confidence can fluctuate frame to frame even when the pose is
        // stable. Reject only genuinely weak points, then let temporal logic
        // decide whether the hand was lost.
        guard let landmark = landmarks[joint], landmark.confidence >= 0.15 else { return nil }
        return landmark.point
    }

    var averageConfidence: Double {
        guard !landmarks.isEmpty else { return 0 }
        return Double(landmarks.values.reduce(0) { $0 + $1.confidence }) / Double(landmarks.count)
    }
}

enum Handedness: String, Sendable {
    case left = "Left"
    case right = "Right"
    case unknown = "Hand"
}

enum RecognizedGesture: String, CaseIterable, Identifiable, Sendable {
    case idle = "Ready"
    case pointing = "Pointing"
    case clicking = "Click"
    case dragging = "Dragging"
    case scrolling = "Scrolling"
    case zooming = "Zooming"
    case windowMove = "Window moved"
    case handLost = "No hand"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .idle: "hand.raised"
        case .pointing: "cursorarrow.motionlines"
        case .clicking: "hand.tap"
        case .dragging: "hand.draw"
        case .scrolling: "arrow.up.and.down"
        case .zooming: "plus.magnifyingglass"
        case .windowMove: "rectangle.2.swap"
        case .handLost: "hand.raised.slash"
        }
    }
}

enum ControlFeature: String, CaseIterable, Identifiable, Sendable {
    case pointer
    case drag
    case scroll
    case zoom
    case displays

    var id: String { rawValue }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
