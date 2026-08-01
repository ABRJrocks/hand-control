import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

protocol SystemControlling: AnyObject {
    var isDragging: Bool { get }
    var isAuthorized: Bool { get }
    func movePointer(to point: CGPoint)
    func click(at point: CGPoint)
    func beginDrag(at point: CGPoint)
    func endDrag(at point: CGPoint?)
    func scroll(vertical delta: CGFloat)
    func zoom(delta: CGFloat)
    func currentPointerLocation() -> CGPoint
    func virtualDesktopBounds() -> CGRect
    @discardableResult func moveFocusedWindowToNextDisplay(direction: Int) -> Bool
}

extension SystemControlling {
    func endDrag() {
        endDrag(at: nil)
    }
}

final class SystemController: SystemControlling, @unchecked Sendable {
    private(set) var isDragging = false

    var isAuthorized: Bool { AXIsProcessTrusted() }

    func movePointer(to point: CGPoint) {
        guard isAuthorized else { return }
        let type: CGEventType = isDragging ? .leftMouseDragged : .mouseMoved
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    func click(at point: CGPoint) {
        guard isAuthorized else { return }
        postMouse(.leftMouseDown, at: point)
        postMouse(.leftMouseUp, at: point)
    }

    func beginDrag(at point: CGPoint) {
        guard isAuthorized, !isDragging else { return }
        isDragging = true
        postMouse(.leftMouseDown, at: point)
    }

    func endDrag(at point: CGPoint?) {
        guard isDragging else { return }
        let location = point ?? CGEvent(source: nil)?.location ?? .zero
        postMouse(.leftMouseUp, at: location)
        isDragging = false
    }

    func endDrag() {
        endDrag(at: nil)
    }

    func scroll(vertical delta: CGFloat) {
        guard isAuthorized, abs(delta) >= 1 else { return }
        let clamped = Int32(max(-24, min(24, delta)))
        CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: clamped,
            wheel2: 0,
            wheel3: 0
        )?.post(tap: .cghidEventTap)
    }

    func zoom(delta: CGFloat) {
        guard isAuthorized, abs(delta) >= 1 else { return }
        let clamped = Int32(max(-16, min(16, delta)))
        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: clamped,
            wheel2: 0,
            wheel3: 0
        )
        event?.flags = .maskControl
        event?.post(tap: .cghidEventTap)
    }

    func currentPointerLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    func virtualDesktopBounds() -> CGRect {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return CGDisplayBounds(CGMainDisplayID())
        }
        var displays = Array(repeating: CGDirectDisplayID(), count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else {
            return CGDisplayBounds(CGMainDisplayID())
        }
        return displays.prefix(Int(count)).map(CGDisplayBounds).reduce(.null) { $0.union($1) }
    }

    @discardableResult
    func moveFocusedWindowToNextDisplay(direction: Int) -> Bool {
        guard isAuthorized else { return false }
        let displays = activeDisplays().sorted { lhs, rhs in
            if lhs.bounds.minX == rhs.bounds.minX { return lhs.bounds.minY < rhs.bounds.minY }
            return lhs.bounds.minX < rhs.bounds.minX
        }
        guard displays.count > 1,
              let window = focusedWindow(),
              let position = copyPoint(window, attribute: kAXPositionAttribute),
              let size = copySize(window, attribute: kAXSizeAttribute) else { return false }

        let center = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
        let currentIndex = displays.firstIndex { $0.bounds.contains(center) } ?? 0
        let offset = direction >= 0 ? 1 : -1
        let targetIndex = (currentIndex + offset + displays.count) % displays.count
        let source = displays[currentIndex].bounds
        let target = displays[targetIndex].bounds

        let relativeX = source.width > size.width
            ? (position.x - source.minX) / max(1, source.width - size.width)
            : 0.5
        let relativeY = source.height > size.height
            ? (position.y - source.minY) / max(1, source.height - size.height)
            : 0.5
        var newPosition = CGPoint(
            x: target.minX + max(0, target.width - size.width) * max(0, min(1, relativeX)),
            y: target.minY + max(0, target.height - size.height) * max(0, min(1, relativeY))
        )
        guard let value = AXValueCreate(.cgPoint, &newPosition) else { return false }
        return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value) == .success
    }

    private func postMouse(_ type: CGEventType, at point: CGPoint) {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    private func activeDisplays() -> [(id: CGDirectDisplayID, bounds: CGRect)] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success else { return [] }
        var ids = Array(repeating: CGDirectDisplayID(), count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { ($0, CGDisplayBounds($0)) }
    }

    private func focusedWindow() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var appValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedApplicationAttribute as CFString, &appValue) == .success,
              let appValue else { return nil }
        let app = unsafeDowncast(appValue, to: AXUIElement.self)
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
              let windowValue else { return nil }
        return unsafeDowncast(windowValue, to: AXUIElement.self)
    }

    private func copyPoint(_ element: AXUIElement, attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(unsafeDowncast(value, to: AXValue.self), .cgPoint, &point) else { return nil }
        return point
    }

    private func copySize(_ element: AXUIElement, attribute: String) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(value, to: AXValue.self), .cgSize, &size) else { return nil }
        return size
    }
}
