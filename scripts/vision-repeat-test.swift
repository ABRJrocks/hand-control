import AppKit
import Foundation
import Vision

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("Usage: swift vision-repeat-test.swift <hand-image> [iterations] [no-hand-lead-in-image]\n".utf8))
    exit(2)
}

let imageURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iterations = CommandLine.arguments.count >= 3 ? Int(CommandLine.arguments[2]) ?? 120 : 120
guard let image = NSImage(contentsOf: imageURL),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data("Could not decode \(imageURL.path)\n".utf8))
    exit(2)
}
let leadInImage: CGImage? = {
    guard CommandLine.arguments.count >= 4,
          let image = NSImage(contentsOfFile: CommandLine.arguments[3]) else { return nil }
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
}()

let request = VNDetectHumanHandPoseRequest()
request.maximumHandCount = 1
var detections = 0
var errors = 0
var confidences: [Float] = []
let start = ProcessInfo.processInfo.systemUptime

for index in 0..<iterations {
    autoreleasepool {
        let currentImage = (leadInImage != nil && index < iterations / 2) ? leadInImage! : cgImage
        let handler = VNImageRequestHandler(cgImage: currentImage, orientation: .up)
        do {
            try handler.perform([request])
            if let observation = request.results?.first {
                detections += 1
                if let point = try? observation.recognizedPoint(.wrist) {
                    confidences.append(point.confidence)
                }
            }
        } catch {
            errors += 1
        }
    }
}

let elapsed = ProcessInfo.processInfo.systemUptime - start
let averageConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)
let confidenceText = String(format: "%.3f", averageConfidence)
let elapsedText = String(format: "%.3f", elapsed)
print("iterations=\(iterations) detections=\(detections) errors=\(errors) avgWristConfidence=\(confidenceText) elapsed=\(elapsedText)s")
