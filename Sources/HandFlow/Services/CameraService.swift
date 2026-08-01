@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import OSLog
@preconcurrency import Vision

enum CameraRunState: Sendable, Equatable {
    case idle
    case configuring
    case running
    case interrupted(String)
    case failed(String)

    var label: String {
        switch self {
        case .idle: "Camera idle"
        case .configuring: "Starting camera"
        case .running: "Camera running"
        case .interrupted(let reason): "Interrupted: \(reason)"
        case .failed(let reason): "Camera error: \(reason)"
        }
    }
}

struct CameraTelemetry: Sendable, Equatable {
    var state: CameraRunState = .idle
    var inputFrames = 0
    var detectedFrames = 0
    var inferenceErrors = 0
    var lastError: String?

    var detectionRate: Int {
        guard inputFrames > 0 else { return 0 }
        return Int((Double(detectedFrames) / Double(inputFrames) * 100).rounded())
    }
}

final class CameraService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.handflow.capture.session", qos: .userInitiated)
    private let visionQueue = DispatchQueue(label: "com.handflow.capture.vision", qos: .userInteractive)
    private var request: VNDetectHumanHandPoseRequest = CameraService.makeRequest()
    private static func makeRequest() -> VNDetectHumanHandPoseRequest {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        return request
    }
    private var configured = false
    private var wantsRunning = false
    private var frameHandler: (@Sendable (HandPoseFrame) -> Void)?
    private var telemetryHandler: (@Sendable (CameraTelemetry) -> Void)?
    private var telemetry = CameraTelemetry()
    private var consecutiveInferenceErrors = 0
    private let logger = Logger(subsystem: "com.handflow.desktop", category: "Camera")

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted(_:)),
            name: .AVCaptureSessionWasInterrupted,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded(_:)),
            name: .AVCaptureSessionInterruptionEnded,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError(_:)),
            name: .AVCaptureSessionRuntimeError,
            object: session
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setFrameHandler(_ handler: @escaping @Sendable (HandPoseFrame) -> Void) {
        frameHandler = handler
    }

    func setTelemetryHandler(_ handler: @escaping @Sendable (CameraTelemetry) -> Void) {
        telemetryHandler = handler
        handler(telemetry)
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsRunning = true
            self.telemetry.inputFrames = 0
            self.telemetry.detectedFrames = 0
            self.telemetry.inferenceErrors = 0
            self.telemetry.lastError = nil
            self.updateState(.configuring)
            do {
                if !self.configured { try self.configure() }
                guard !self.session.isRunning else { return }
                self.session.startRunning()
                self.updateState(self.session.isRunning ? .running : .failed("Capture session did not start"))
            } catch {
                self.logger.error("Camera setup failed: \(error.localizedDescription, privacy: .public)")
                self.updateState(.failed(error.localizedDescription))
                self.frameHandler?(.empty())
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsRunning = false
            if self.session.isRunning { self.session.stopRunning() }
            self.updateState(.idle)
        }
    }

    @objc private func sessionWasInterrupted(_ notification: Notification) {
        sessionQueue.async { [weak self] in
            self?.updateState(.interrupted("Camera temporarily unavailable"))
        }
    }

    @objc private func sessionInterruptionEnded(_ notification: Notification) {
        sessionQueue.async { [weak self] in
            guard let self, self.wantsRunning else { return }
            if !self.session.isRunning { self.session.startRunning() }
            self.updateState(self.session.isRunning ? .running : .failed("Camera did not resume"))
        }
    }

    @objc private func sessionRuntimeError(_ notification: Notification) {
        let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let message = error?.localizedDescription ?? "Unknown capture error"
            self.logger.error("Capture runtime error: \(message, privacy: .public)")
            if self.wantsRunning {
                self.session.startRunning()
                self.updateState(self.session.isRunning ? .running : .failed(message))
            } else {
                self.updateState(.failed(message))
            }
        }
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .medium

        guard let camera = AVCaptureDevice.systemPreferredCamera
            ?? AVCaptureDevice.default(for: .video) else {
            throw CameraError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: visionQueue)
        guard session.canAddOutput(output) else { throw CameraError.cannotAddOutput }
        session.addOutput(output)
        configured = true
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        autoreleasepool {
            telemetry.inputFrames += 1
            let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up)
            do {
                try handler.perform([request])
                consecutiveInferenceErrors = 0
                guard let observation = request.results?.first else {
                    frameHandler?(.empty())
                    publishTelemetryIfNeeded()
                    return
                }
                telemetry.detectedFrames += 1
                frameHandler?(makeFrame(from: observation))
                publishTelemetryIfNeeded()
            } catch {
                consecutiveInferenceErrors += 1
                telemetry.inferenceErrors += 1
                telemetry.lastError = error.localizedDescription
                logger.error("Vision inference failed: \(error.localizedDescription, privacy: .public)")
                if consecutiveInferenceErrors >= 3 {
                    request = Self.makeRequest()
                    consecutiveInferenceErrors = 0
                    logger.notice("Vision request reset after consecutive errors")
                }
                telemetryHandler?(telemetry)
                frameHandler?(.empty())
            }
        }
    }

    private func updateState(_ state: CameraRunState) {
        telemetry.state = state
        telemetryHandler?(telemetry)
        logger.info("\(state.label, privacy: .public)")
    }

    private func publishTelemetryIfNeeded() {
        if telemetry.inputFrames % 15 == 0 {
            telemetryHandler?(telemetry)
        }
    }

    private func makeFrame(from observation: VNHumanHandPoseObservation) -> HandPoseFrame {
        var landmarks: [HandJoint: HandLandmark] = [:]
        for (joint, visionName) in Self.jointMap {
            guard let point = try? observation.recognizedPoint(visionName), point.confidence >= 0.15 else { continue }
            landmarks[joint] = HandLandmark(point: point.location, confidence: point.confidence)
        }

        let handedness: Handedness
        switch observation.chirality {
        case .left: handedness = .left
        case .right: handedness = .right
        default: handedness = .unknown
        }

        return HandPoseFrame(
            landmarks: landmarks,
            timestamp: ProcessInfo.processInfo.systemUptime,
            chirality: handedness
        )
    }

    private static let jointMap: [HandJoint: VNHumanHandPoseObservation.JointName] = [
        .wrist: .wrist,
        .thumbCMC: .thumbCMC,
        .thumbMP: .thumbMP,
        .thumbIP: .thumbIP,
        .thumbTip: .thumbTip,
        .indexMCP: .indexMCP,
        .indexPIP: .indexPIP,
        .indexDIP: .indexDIP,
        .indexTip: .indexTip,
        .middleMCP: .middleMCP,
        .middlePIP: .middlePIP,
        .middleDIP: .middleDIP,
        .middleTip: .middleTip,
        .ringMCP: .ringMCP,
        .ringPIP: .ringPIP,
        .ringDIP: .ringDIP,
        .ringTip: .ringTip,
        .littleMCP: .littleMCP,
        .littlePIP: .littlePIP,
        .littleDIP: .littleDIP,
        .littleTip: .littleTip
    ]

    private enum CameraError: Error {
        case noCamera
        case cannotAddInput
        case cannotAddOutput
    }
}
