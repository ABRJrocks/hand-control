import CoreGraphics
import Foundation
import XCTest
@testable import HandFlow

@MainActor
final class GestureEngineTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: AppSettings!
    private var controller: MockSystemController!
    private var engine: GestureEngine!

    override func setUp() async throws {
        let suite = "GestureEngineTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        settings = AppSettings(defaults: defaults)
        controller = MockSystemController()
        engine = GestureEngine(settings: settings, controller: controller)
    }

    func testPointingMovesPointer() {
        engine.process(pose(kind: .point, time: 1), controlsEnabled: true)
        engine.process(pose(kind: .pointMoved, time: 1.05), controlsEnabled: true)
        XCTAssertEqual(engine.gesture, .pointing)
        XCTAssertEqual(controller.pointerMoves.count, 1)
        XCTAssertGreaterThan(abs((controller.pointerMoves.first?.x ?? 500) - 500), 20)
    }

    func testSubDeadZoneJitterDoesNotMovePointer() {
        engine.process(pose(kind: .point, time: 1), controlsEnabled: true)
        for frameIndex in 1...60 {
            engine.process(
                pose(kind: .pointJitter, time: 1 + Double(frameIndex) / 30),
                controlsEnabled: true
            )
        }
        XCTAssertTrue(controller.pointerMoves.isEmpty)
    }

    func testBriefPinchNoiseDoesNotClick() {
        engine.process(pose(kind: .point, time: 1), controlsEnabled: true)
        engine.process(pose(kind: .pinch, time: 1.04), controlsEnabled: true)
        engine.process(pose(kind: .point, time: 1.10), controlsEnabled: true)
        XCTAssertTrue(controller.clicks.isEmpty)
        XCTAssertFalse(controller.isDragging)
    }

    func testPointerFreezesWhilePinchIsForming() {
        engine.process(pose(kind: .point, time: 1), controlsEnabled: true)
        engine.process(pose(kind: .pointMoved, time: 1.05), controlsEnabled: true)
        let movesBeforePinch = controller.pointerMoves.count
        engine.process(pose(kind: .pinch, time: 1.10), controlsEnabled: true)
        engine.process(pose(kind: .pinchMoved, time: 1.16), controlsEnabled: true)
        XCTAssertEqual(controller.pointerMoves.count, movesBeforePinch)
    }

    func testBriefTwoFingerPoseDoesNotScroll() {
        engine.process(pose(kind: .twoFinger, time: 1), controlsEnabled: true)
        engine.process(pose(kind: .point, time: 1.10), controlsEnabled: true)
        XCTAssertTrue(controller.scrollDeltas.isEmpty)
    }

    func testBriefFistDoesNotMoveWindow() {
        engine.process(pose(kind: .fist, time: 1), controlsEnabled: true)
        engine.process(pose(kind: .point, time: 1.10), controlsEnabled: true)
        XCTAssertTrue(controller.windowMoves.isEmpty)
    }

    func testQuickPinchClicksOnlyOnRelease() {
        engine.process(pose(kind: .point, time: 1), controlsEnabled: true)
        engine.process(pose(kind: .pinch, time: 1.05), controlsEnabled: true)
        engine.process(pose(kind: .pinch, time: 1.18), controlsEnabled: true)
        XCTAssertEqual(controller.clicks.count, 0)
        engine.process(pose(kind: .point, time: 1.25), controlsEnabled: true)
        XCTAssertEqual(controller.clicks.count, 1)
        XCTAssertEqual(controller.clicks.first, CGPoint(x: 500, y: 400))
        XCTAssertFalse(controller.isDragging)
    }

    func testMovingPinchDragsAndLostHandReleasesWithoutClick() {
        engine.process(pose(kind: .pinch, time: 1), controlsEnabled: true)
        engine.process(pose(kind: .pinchMoved, time: 1.08), controlsEnabled: true)
        engine.process(pose(kind: .pinchMoved, time: 1.24), controlsEnabled: true)
        XCTAssertTrue(controller.isDragging)
        engine.process(.empty(at: 1.2), controlsEnabled: true)
        XCTAssertTrue(controller.isDragging, "A brief missed frame should keep the drag stable")
        engine.process(.empty(at: 1.6), controlsEnabled: true)
        XCTAssertFalse(controller.isDragging)
        XCTAssertEqual(controller.clicks.count, 0)
        XCTAssertEqual(controller.dragEnds, 1)
    }

    func testTwoFingerMotionScrolls() {
        engine.process(pose(kind: .twoFinger, time: 1), controlsEnabled: true)
        engine.process(pose(kind: .twoFinger, time: 1.2), controlsEnabled: true)
        engine.process(pose(kind: .twoFingerLower, time: 1.26), controlsEnabled: true)
        XCTAssertEqual(engine.gesture, .scrolling)
        XCTAssertFalse(controller.scrollDeltas.isEmpty)
    }

    func testMiddlePinchMotionZooms() {
        engine.process(pose(kind: .middlePinch, time: 1), controlsEnabled: true)
        engine.process(pose(kind: .middlePinch, time: 1.2), controlsEnabled: true)
        engine.process(pose(kind: .middlePinchLower, time: 1.26), controlsEnabled: true)
        XCTAssertEqual(engine.gesture, .zooming)
        XCTAssertFalse(controller.zoomDeltas.isEmpty)
    }

    func testFistSwipeMovesWindowOnce() {
        engine.process(pose(kind: .fist, time: 2), controlsEnabled: true)
        engine.process(pose(kind: .fist, time: 2.25), controlsEnabled: true)
        engine.process(pose(kind: .fistMoved, time: 2.5), controlsEnabled: true)
        XCTAssertEqual(engine.gesture, .windowMove)
        XCTAssertEqual(controller.windowMoves.count, 1)
    }

    private enum PoseKind {
        case point, pointMoved, pointJitter, pinch, pinchMoved, twoFinger, twoFingerLower
        case middlePinch, middlePinchLower, fist, fistMoved
    }

    private func pose(kind: PoseKind, time: TimeInterval) -> HandPoseFrame {
        let shiftX: CGFloat = kind == .fistMoved ? 0.24 : 0
        let wrist = CGPoint(x: 0.42 + shiftX, y: 0.22)
        let make: (CGFloat, CGFloat) -> HandLandmark = {
            HandLandmark(point: CGPoint(x: $0 + shiftX, y: $1), confidence: 0.96)
        }
        var values: [HandJoint: HandLandmark] = [
            .wrist: HandLandmark(point: wrist, confidence: 0.96),
            .middleMCP: make(0.42, 0.45),
            .indexPIP: make(0.37, 0.59),
            .middlePIP: make(0.43, 0.61),
            .ringPIP: make(0.49, 0.58),
            .littlePIP: make(0.55, 0.53),
            .indexTip: make(0.36, 0.82),
            .middleTip: make(0.43, 0.53),
            .ringTip: make(0.48, 0.49),
            .littleTip: make(0.53, 0.46),
            .thumbTip: make(0.24, 0.56)
        ]

        switch kind {
        case .point:
            break
        case .pointMoved:
            values[.indexTip] = make(0.41, 0.82)
        case .pointJitter:
            values[.indexTip] = make(0.3605, 0.8204)
        case .pinch:
            values[.thumbTip] = make(0.36, 0.81)
        case .pinchMoved:
            values[.indexTip] = make(0.62, 0.78)
            values[.thumbTip] = make(0.62, 0.77)
        case .twoFinger, .twoFingerLower:
            let offset: CGFloat = kind == .twoFingerLower ? -0.12 : 0
            values[.indexTip] = make(0.36, 0.82 + offset)
            values[.middleTip] = make(0.44, 0.84 + offset)
        case .middlePinch, .middlePinchLower:
            let y: CGFloat = kind == .middlePinchLower ? 0.66 : 0.80
            values[.middleTip] = make(0.44, y)
            values[.thumbTip] = make(0.445, y - 0.005)
        case .fist, .fistMoved:
            values[.indexTip] = make(0.37, 0.48)
            values[.middleTip] = make(0.43, 0.49)
            values[.ringTip] = make(0.48, 0.47)
            values[.littleTip] = make(0.52, 0.44)
            values[.thumbTip] = make(0.31, 0.45)
        }

        return HandPoseFrame(landmarks: values, timestamp: time, chirality: .right)
    }
}

private final class MockSystemController: SystemControlling {
    var isDragging = false
    var isAuthorized = true
    var pointerMoves: [CGPoint] = []
    var clicks: [CGPoint] = []
    var dragStarts = 0
    var dragEnds = 0
    var scrollDeltas: [CGFloat] = []
    var zoomDeltas: [CGFloat] = []
    var windowMoves: [Int] = []
    var pointerLocation = CGPoint(x: 500, y: 400)

    func movePointer(to point: CGPoint) { pointerLocation = point; pointerMoves.append(point) }
    func click(at point: CGPoint) { clicks.append(point) }
    func beginDrag(at point: CGPoint) { isDragging = true; dragStarts += 1 }
    func endDrag(at point: CGPoint?) { isDragging = false; dragEnds += 1 }
    func scroll(vertical delta: CGFloat) { scrollDeltas.append(delta) }
    func zoom(delta: CGFloat) { zoomDeltas.append(delta) }
    func currentPointerLocation() -> CGPoint { pointerLocation }
    func virtualDesktopBounds() -> CGRect { CGRect(x: 0, y: 0, width: 1000, height: 800) }
    func moveFocusedWindowToNextDisplay(direction: Int) -> Bool {
        windowMoves.append(direction)
        return true
    }
}
