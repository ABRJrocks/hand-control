import CoreGraphics
import XCTest
@testable import HandFlow

final class GestureGeometryTests: XCTestCase {
    func testOpenIndexIsRecognizedAsExtended() throws {
        let shape = try XCTUnwrap(GestureGeometry.analyze(frame(
            index: CGPoint(x: 0.45, y: 0.84),
            middle: CGPoint(x: 0.55, y: 0.58),
            thumb: CGPoint(x: 0.28, y: 0.58)
        )))
        XCTAssertTrue(shape.indexExtended)
        XCTAssertFalse(shape.middleExtended)
        XCTAssertFalse(shape.isFist)
    }

    func testClosedFingersAreRecognizedAsFist() throws {
        let shape = try XCTUnwrap(GestureGeometry.analyze(frame(
            index: CGPoint(x: 0.46, y: 0.50),
            middle: CGPoint(x: 0.51, y: 0.49),
            thumb: CGPoint(x: 0.36, y: 0.48),
            allClosed: true
        )))
        XCTAssertTrue(shape.isFist)
    }

    func testIndexPinchUsesPalmRelativeDistance() throws {
        let shape = try XCTUnwrap(GestureGeometry.analyze(frame(
            index: CGPoint(x: 0.45, y: 0.78),
            middle: CGPoint(x: 0.54, y: 0.56),
            thumb: CGPoint(x: 0.46, y: 0.77)
        )))
        XCTAssertLessThan(shape.indexPinchRatio, 0.2)
        XCTAssertGreaterThan(shape.middlePinchRatio, shape.indexPinchRatio)
    }

    func testTwoRaisedFingersAreRecognized() throws {
        let shape = try XCTUnwrap(GestureGeometry.analyze(frame(
            index: CGPoint(x: 0.45, y: 0.84),
            middle: CGPoint(x: 0.55, y: 0.86),
            thumb: CGPoint(x: 0.29, y: 0.58),
            middleRaised: true
        )))
        XCTAssertTrue(shape.isTwoFinger)
    }

    private func frame(
        index: CGPoint,
        middle: CGPoint,
        thumb: CGPoint,
        allClosed: Bool = false,
        middleRaised: Bool = false
    ) -> HandPoseFrame {
        let confidence: Float = 0.95
        let make: (CGPoint) -> HandLandmark = { HandLandmark(point: $0, confidence: confidence) }
        var points: [HandJoint: HandLandmark] = [
            .wrist: make(CGPoint(x: 0.5, y: 0.25)),
            .middleMCP: make(CGPoint(x: 0.5, y: 0.47)),
            .thumbTip: make(thumb),
            .indexTip: make(index),
            .indexPIP: make(CGPoint(x: 0.46, y: 0.60)),
            .middleTip: make(middle),
            .middlePIP: make(CGPoint(x: 0.53, y: 0.61)),
            .ringPIP: make(CGPoint(x: 0.58, y: 0.58)),
            .littlePIP: make(CGPoint(x: 0.63, y: 0.54)),
            .ringTip: make(CGPoint(x: 0.57, y: 0.50)),
            .littleTip: make(CGPoint(x: 0.61, y: 0.47))
        ]
        if allClosed {
            points[.indexPIP] = make(CGPoint(x: 0.46, y: 0.57))
            points[.middlePIP] = make(CGPoint(x: 0.51, y: 0.58))
        }
        if middleRaised {
            points[.middlePIP] = make(CGPoint(x: 0.54, y: 0.62))
        }
        return HandPoseFrame(landmarks: points, timestamp: 1, chirality: .right)
    }
}
