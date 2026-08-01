import CoreGraphics
import Foundation

struct HandShape {
    let indexExtended: Bool
    let middleExtended: Bool
    let ringExtended: Bool
    let littleExtended: Bool
    let indexPinchRatio: CGFloat
    let middlePinchRatio: CGFloat

    var isFist: Bool { !indexExtended && !middleExtended && !ringExtended && !littleExtended }
    var isTwoFinger: Bool { indexExtended && middleExtended && !ringExtended && !littleExtended }
}

enum GestureGeometry {
    static func analyze(_ frame: HandPoseFrame) -> HandShape? {
        guard let wrist = frame[.wrist],
              let middleMCP = frame[.middleMCP],
              let thumb = frame[.thumbTip],
              let index = frame[.indexTip],
              let middle = frame[.middleTip] else { return nil }

        let palmScale = max(0.045, wrist.distance(to: middleMCP))
        return HandShape(
            indexExtended: extended(.indexTip, .indexPIP, frame, wrist),
            middleExtended: extended(.middleTip, .middlePIP, frame, wrist),
            ringExtended: extended(.ringTip, .ringPIP, frame, wrist),
            littleExtended: extended(.littleTip, .littlePIP, frame, wrist),
            indexPinchRatio: thumb.distance(to: index) / palmScale,
            middlePinchRatio: thumb.distance(to: middle) / palmScale
        )
    }

    private static func extended(_ tip: HandJoint, _ pip: HandJoint, _ frame: HandPoseFrame, _ wrist: CGPoint) -> Bool {
        guard let tipPoint = frame[tip], let pipPoint = frame[pip] else { return false }
        return tipPoint.distance(to: wrist) > pipPoint.distance(to: wrist) * 1.13
    }
}

@MainActor
final class GestureEngine: ObservableObject {
    @Published private(set) var gesture: RecognizedGesture = .handLost
    @Published private(set) var confidence: Double = 0
    @Published private(set) var frame: HandPoseFrame = .empty()
    @Published private(set) var framesPerSecond: Int = 0
    @Published private(set) var lastAction = "Waiting for a hand"

    private let settings: AppSettings
    private let controller: any SystemControlling
    private var pointerFilter = OneEuroFilter()
    private var lastFilteredHandPoint: CGPoint?
    private var pointerResidual = CGPoint.zero
    private var pinchActive = false
    private var pinchCandidateSince: TimeInterval?
    private var pinchAnchorPointer = CGPoint.zero
    private var pinchAnchorHand = CGPoint.zero
    private var lastPointer = CGPoint.zero
    private var scrollSmoothedY: CGFloat?
    private var scrollResidual: CGFloat = 0
    private var zoomSmoothedY: CGFloat?
    private var zoomResidual: CGFloat = 0
    private var fistStart: (point: CGPoint, time: TimeInterval)?
    private var lastWindowMoveAt: TimeInterval = 0
    private var candidateIntent: MotionIntent?
    private var candidateSince: TimeInterval = 0
    private var fpsStart = ProcessInfo.processInfo.systemUptime
    private var frameCount = 0
    private var missingSince: TimeInterval?
    private var hasTrackedHand = false

    private enum MotionIntent: Equatable {
        case scroll, zoom, fist
    }

    init(settings: AppSettings, controller: any SystemControlling) {
        self.settings = settings
        self.controller = controller
    }

    func process(_ newFrame: HandPoseFrame, controlsEnabled: Bool) {
        frame = newFrame
        confidence = newFrame.averageConfidence
        updateFPS(at: newFrame.timestamp)

        guard !newFrame.landmarks.isEmpty, let shape = GestureGeometry.analyze(newFrame) else {
            guard hasTrackedHand else {
                gesture = .handLost
                lastAction = "Looking for your hand"
                return
            }
            if missingSince == nil { missingSince = newFrame.timestamp }
            if newFrame.timestamp - (missingSince ?? newFrame.timestamp) >= 0.35 {
                handWasLost()
            } else {
                lastAction = "Keeping lock on your hand"
            }
            return
        }
        hasTrackedHand = true
        missingSince = nil

        let sensitivityOffset = CGFloat((settings.sensitivity - 0.5) * 0.28)
        let pinchDown = CGFloat(0.43) + sensitivityOffset
        let pinchUp = pinchDown + 0.16
        let indexPinched: Bool
        if pinchActive {
            indexPinched = !shape.isFist && shape.indexPinchRatio < pinchUp
        } else {
            indexPinched = !shape.isFist
                && shape.indexPinchRatio < pinchDown
                && shape.indexPinchRatio + 0.06 < shape.middlePinchRatio
        }
        let middlePinched = !shape.isFist
            && !indexPinched
            && shape.middlePinchRatio < pinchDown
            && shape.middlePinchRatio + 0.06 < shape.indexPinchRatio

        if shape.isFist && settings.isEnabled(.displays) {
            finishPinchIfNeeded(allowClick: false, controlsEnabled: controlsEnabled)
            primePointer(with: newFrame)
            resetScrollAndZoom()
            if intentIsStable(.fist, at: newFrame.timestamp, dwell: 0.24) {
                handleFist(frame: newFrame, controlsEnabled: controlsEnabled)
            } else {
                gesture = .idle
                lastAction = "Hold fist steady"
            }
        } else if middlePinched && settings.isEnabled(.zoom) {
            finishPinchIfNeeded(allowClick: false, controlsEnabled: controlsEnabled)
            primePointer(with: newFrame)
            resetScroll()
            fistStart = nil
            if intentIsStable(.zoom, at: newFrame.timestamp, dwell: 0.18) {
                handleZoom(frame: newFrame, controlsEnabled: controlsEnabled)
            } else {
                primeZoom(frame: newFrame)
                gesture = .idle
                lastAction = "Hold middle pinch steady"
            }
        } else if shape.isTwoFinger && settings.isEnabled(.scroll) {
            finishPinchIfNeeded(allowClick: false, controlsEnabled: controlsEnabled)
            primePointer(with: newFrame)
            resetZoom()
            fistStart = nil
            if intentIsStable(.scroll, at: newFrame.timestamp, dwell: 0.18) {
                handleScroll(frame: newFrame, controlsEnabled: controlsEnabled)
            } else {
                primeScroll(frame: newFrame)
                gesture = .idle
                lastAction = "Hold two fingers steady"
            }
        } else if indexPinched && settings.isEnabled(.drag) {
            candidateIntent = nil
            resetScrollAndZoom()
            fistStart = nil
            handlePinch(frame: newFrame, controlsEnabled: controlsEnabled)
        } else {
            let mayClick = shape.indexExtended
            finishPinchIfNeeded(allowClick: mayClick, controlsEnabled: controlsEnabled)
            candidateIntent = nil
            resetScrollAndZoom()
            fistStart = nil
            if shape.indexExtended {
                updatePointer(frame: newFrame, controlsEnabled: controlsEnabled)
                gesture = .pointing
                lastAction = "Pointer tracking"
            } else {
                resetPointerReference()
                gesture = .idle
                lastAction = "Hand detected"
            }
        }
    }

    func reset() {
        controller.endDrag()
        pointerFilter.reset()
        lastFilteredHandPoint = nil
        pointerResidual = .zero
        pinchActive = false
        pinchCandidateSince = nil
        resetScrollAndZoom()
        fistStart = nil
        candidateIntent = nil
        missingSince = nil
        hasTrackedHand = false
        gesture = .handLost
        lastAction = "Control paused"
    }

    private func updatePointer(frame: HandPoseFrame, controlsEnabled: Bool) {
        guard settings.isEnabled(.pointer), let tip = frame[.indexTip] else { return }
        let handPoint = normalizedPointerPoint(tip)
        pointerFilter.minimumCutoff = 1.2 + (1 - settings.smoothing) * 1.4
        pointerFilter.beta = 0.12 + (1 - settings.smoothing) * 0.50
        let filtered = pointerFilter.filter(handPoint, at: frame.timestamp)

        guard let previous = lastFilteredHandPoint else {
            lastFilteredHandPoint = filtered
            lastPointer = controller.currentPointerLocation()
            return
        }
        lastFilteredHandPoint = filtered

        pointerResidual.x += filtered.x - previous.x
        pointerResidual.y += filtered.y - previous.y
        let deadZone = CGFloat(0.0012 + settings.smoothing * 0.0018)
        guard hypot(pointerResidual.x, pointerResidual.y) >= deadZone else { return }

        let desktop = controller.virtualDesktopBounds()
        let rawSpeed = hypot(pointerResidual.x, pointerResidual.y)
        let acceleration: CGFloat = rawSpeed > 0.018 ? 1.55 : (rawSpeed > 0.007 ? 1.15 : 0.85)
        let gain = CGFloat(0.9 + settings.pointerSpeed * 1.05) * acceleration
        let dx = max(-92, min(92, pointerResidual.x * 1500 * gain))
        let dy = max(-92, min(92, pointerResidual.y * 960 * gain))
        pointerResidual = .zero

        let target = CGPoint(
            x: max(desktop.minX + 1, min(desktop.maxX - 1, lastPointer.x + dx)),
            y: max(desktop.minY + 1, min(desktop.maxY - 1, lastPointer.y + dy))
        )
        lastPointer = target
        if controlsEnabled { controller.movePointer(to: lastPointer) }
    }

    private func handlePinch(frame: HandPoseFrame, controlsEnabled: Bool) {
        guard let indexTip = frame[.indexTip] else { return }
        if pinchCandidateSince == nil {
            pinchCandidateSince = frame.timestamp
            pinchAnchorPointer = controller.currentPointerLocation()
            pinchAnchorHand = indexTip
            lastPointer = pinchAnchorPointer
            primePointer(with: frame)
        }

        let duration = frame.timestamp - (pinchCandidateSince ?? frame.timestamp)
        guard duration >= 0.11 else {
            primePointer(with: frame)
            gesture = .idle
            lastAction = "Pinch settling"
            return
        }
        pinchActive = true
        let handMovement = pinchAnchorHand.distance(to: indexTip)
        if controller.isDragging || (duration >= 0.22 && handMovement >= 0.025) {
            if controlsEnabled, !controller.isDragging {
                controller.beginDrag(at: pinchAnchorPointer)
                lastPointer = pinchAnchorPointer
                primePointer(with: frame)
            }
            updatePointer(frame: frame, controlsEnabled: controlsEnabled)
            gesture = .dragging
            lastAction = "Holding item"
        } else {
            primePointer(with: frame)
            gesture = .clicking
            lastAction = "Release to click"
        }
    }

    private func finishPinchIfNeeded(allowClick: Bool, controlsEnabled: Bool) {
        guard pinchCandidateSince != nil else { return }
        let duration = frame.timestamp - (pinchCandidateSince ?? frame.timestamp)
        let handMovement = frame[.indexTip]?.distance(to: pinchAnchorHand) ?? .greatestFiniteMagnitude
        if controller.isDragging {
            if controlsEnabled { controller.endDrag(at: lastPointer) } else { controller.endDrag() }
            lastAction = "Item dropped"
        } else if pinchActive, allowClick, duration <= 0.55, handMovement < 0.04 {
            if controlsEnabled { controller.click(at: pinchAnchorPointer) }
            lastPointer = pinchAnchorPointer
            lastAction = "Clicked"
        }
        pinchActive = false
        pinchCandidateSince = nil
    }

    private func handleScroll(frame: HandPoseFrame, controlsEnabled: Bool) {
        guard let index = frame[.indexTip], let middle = frame[.middleTip] else { return }
        let y = (index.y + middle.y) / 2
        if let previous = scrollSmoothedY {
            let smoothed = previous + (y - previous) * 0.28
            scrollResidual += (smoothed - previous) * 280
            scrollSmoothedY = smoothed
            if abs(scrollResidual) >= 1 {
                if controlsEnabled { controller.scroll(vertical: scrollResidual) }
                scrollResidual = 0
            }
        } else {
            scrollSmoothedY = y
        }
        gesture = .scrolling
        lastAction = "Two-finger scroll"
    }

    private func handleZoom(frame: HandPoseFrame, controlsEnabled: Bool) {
        guard let middle = frame[.middleTip] else { return }
        if let previous = zoomSmoothedY {
            let smoothed = previous + (middle.y - previous) * 0.24
            zoomResidual += (smoothed - previous) * 180
            zoomSmoothedY = smoothed
            if abs(zoomResidual) >= 1 {
                if controlsEnabled { controller.zoom(delta: zoomResidual) }
                zoomResidual = 0
            }
        } else {
            zoomSmoothedY = middle.y
        }
        gesture = .zooming
        lastAction = "Screen zoom"
    }

    private func handleFist(frame: HandPoseFrame, controlsEnabled: Bool) {
        guard let wrist = frame[.wrist] else { return }
        if fistStart == nil { fistStart = (wrist, frame.timestamp) }
        guard let start = fistStart else { return }
        let elapsed = frame.timestamp - start.time
        let travel = wrist.x - start.point.x
        if elapsed <= 0.8, abs(travel) > 0.19, frame.timestamp - lastWindowMoveAt > 1.0 {
            let direction = settings.mirrored ? (travel > 0 ? -1 : 1) : (travel > 0 ? 1 : -1)
            if controlsEnabled, controller.moveFocusedWindowToNextDisplay(direction: direction) {
                lastAction = "Window moved to another display"
            } else {
                lastAction = "Display swipe detected"
            }
            gesture = .windowMove
            lastWindowMoveAt = frame.timestamp
            fistStart = nil
        } else if elapsed > 0.8 {
            fistStart = (wrist, frame.timestamp)
            gesture = .idle
            lastAction = "Fist ready"
        } else {
            gesture = .idle
            lastAction = "Fist ready"
        }
    }

    private func handWasLost() {
        // Losing tracking must never turn an unfinished pinch into a click.
        controller.endDrag()
        pinchActive = false
        pinchCandidateSince = nil
        resetScrollAndZoom()
        resetPointerReference()
        fistStart = nil
        candidateIntent = nil
        missingSince = nil
        hasTrackedHand = false
        gesture = .handLost
        confidence = 0
        lastAction = "Move your hand into view"
    }

    private func updateFPS(at time: TimeInterval) {
        frameCount += 1
        let elapsed = time - fpsStart
        if elapsed >= 1 {
            framesPerSecond = Int((Double(frameCount) / elapsed).rounded())
            frameCount = 0
            fpsStart = time
        }
    }

    private func normalizedPointerPoint(_ tip: CGPoint) -> CGPoint {
        CGPoint(x: settings.mirrored ? 1 - tip.x : tip.x, y: 1 - tip.y)
    }

    private func primePointer(with frame: HandPoseFrame) {
        guard let tip = frame[.indexTip] else {
            resetPointerReference()
            return
        }
        let point = normalizedPointerPoint(tip)
        pointerFilter.minimumCutoff = 1.2 + (1 - settings.smoothing) * 1.4
        pointerFilter.beta = 0.12 + (1 - settings.smoothing) * 0.50
        lastFilteredHandPoint = pointerFilter.filter(point, at: frame.timestamp)
        pointerResidual = .zero
    }

    private func resetPointerReference() {
        pointerFilter.reset()
        lastFilteredHandPoint = nil
        pointerResidual = .zero
    }

    private func intentIsStable(_ intent: MotionIntent, at time: TimeInterval, dwell: TimeInterval) -> Bool {
        if candidateIntent != intent {
            candidateIntent = intent
            candidateSince = time
            return false
        }
        return time - candidateSince >= dwell
    }

    private func primeScroll(frame: HandPoseFrame) {
        guard let index = frame[.indexTip], let middle = frame[.middleTip] else { return }
        scrollSmoothedY = (index.y + middle.y) / 2
        scrollResidual = 0
    }

    private func primeZoom(frame: HandPoseFrame) {
        zoomSmoothedY = frame[.middleTip]?.y
        zoomResidual = 0
    }

    private func resetScroll() {
        scrollSmoothedY = nil
        scrollResidual = 0
    }

    private func resetZoom() {
        zoomSmoothedY = nil
        zoomResidual = 0
    }

    private func resetScrollAndZoom() {
        resetScroll()
        resetZoom()
    }
}
