import CoreGraphics
import Foundation

/// A low-latency adaptive filter for noisy pointing input.
struct OneEuroFilter {
    private var xFilter = AxisFilter()
    private var yFilter = AxisFilter()
    private var lastTime: TimeInterval?

    var minimumCutoff: Double = 1.15
    var beta: Double = 0.022
    var derivativeCutoff: Double = 1.0

    mutating func filter(_ point: CGPoint, at time: TimeInterval) -> CGPoint {
        guard let previousTime = lastTime else {
            lastTime = time
            xFilter.reset(Double(point.x))
            yFilter.reset(Double(point.y))
            return point
        }

        let dt = max(1.0 / 120.0, min(0.1, time - previousTime))
        lastTime = time
        let x = xFilter.filter(Double(point.x), dt: dt, minCutoff: minimumCutoff, beta: beta, derivativeCutoff: derivativeCutoff)
        let y = yFilter.filter(Double(point.y), dt: dt, minCutoff: minimumCutoff, beta: beta, derivativeCutoff: derivativeCutoff)
        return CGPoint(x: x, y: y)
    }

    mutating func reset() {
        xFilter = AxisFilter()
        yFilter = AxisFilter()
        lastTime = nil
    }

    private struct AxisFilter {
        var value: Double?
        var derivative: Double = 0

        mutating func reset(_ newValue: Double) {
            value = newValue
            derivative = 0
        }

        mutating func filter(
            _ input: Double,
            dt: Double,
            minCutoff: Double,
            beta: Double,
            derivativeCutoff: Double
        ) -> Double {
            guard let previous = value else {
                reset(input)
                return input
            }
            let rawDerivative = (input - previous) / dt
            let derivativeAlpha = Self.alpha(cutoff: derivativeCutoff, dt: dt)
            derivative = derivativeAlpha * rawDerivative + (1 - derivativeAlpha) * derivative
            let cutoff = minCutoff + beta * abs(derivative)
            let positionAlpha = Self.alpha(cutoff: cutoff, dt: dt)
            let result = positionAlpha * input + (1 - positionAlpha) * previous
            value = result
            return result
        }

        private static func alpha(cutoff: Double, dt: Double) -> Double {
            let tau = 1.0 / (2.0 * Double.pi * cutoff)
            return 1.0 / (1.0 + tau / dt)
        }
    }
}
