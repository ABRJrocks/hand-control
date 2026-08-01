import AVFoundation
import SwiftUI

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    let mirrored: Bool

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        updateMirroring(view.previewLayer)
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.previewLayer.session = session
        updateMirroring(nsView.previewLayer)
    }

    private func updateMirroring(_ layer: AVCaptureVideoPreviewLayer) {
        guard let connection = layer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = mirrored
    }
}

final class PreviewView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = previewLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct HandSkeletonOverlay: View {
    let frame: HandPoseFrame
    let mirrored: Bool

    private static let connections: [(HandJoint, HandJoint)] = [
        (.wrist, .thumbCMC), (.thumbCMC, .thumbMP), (.thumbMP, .thumbIP), (.thumbIP, .thumbTip),
        (.wrist, .indexMCP), (.indexMCP, .indexPIP), (.indexPIP, .indexDIP), (.indexDIP, .indexTip),
        (.wrist, .middleMCP), (.middleMCP, .middlePIP), (.middlePIP, .middleDIP), (.middleDIP, .middleTip),
        (.wrist, .ringMCP), (.ringMCP, .ringPIP), (.ringPIP, .ringDIP), (.ringDIP, .ringTip),
        (.wrist, .littleMCP), (.littleMCP, .littlePIP), (.littlePIP, .littleDIP), (.littleDIP, .littleTip),
        (.indexMCP, .middleMCP), (.middleMCP, .ringMCP), (.ringMCP, .littleMCP)
    ]

    var body: some View {
        Canvas { context, size in
            for (startJoint, endJoint) in Self.connections {
                guard let start = point(startJoint, in: size), let end = point(endJoint, in: size) else { continue }
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(HandFlowTheme.accent.opacity(0.72)), lineWidth: 2)
            }
            for joint in HandJoint.allCases {
                guard let point = point(joint, in: size) else { continue }
                let isTip = [.thumbTip, .indexTip, .middleTip, .ringTip, .littleTip].contains(joint)
                let diameter: CGFloat = isTip ? 9 : 5
                let rect = CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter)
                context.fill(Path(ellipseIn: rect), with: .color(isTip ? .white : HandFlowTheme.accent))
            }
        }
        .allowsHitTesting(false)
    }

    private func point(_ joint: HandJoint, in size: CGSize) -> CGPoint? {
        guard let normalized = frame[joint] else { return nil }
        let x = mirrored ? 1 - normalized.x : normalized.x
        return CGPoint(x: x * size.width, y: (1 - normalized.y) * size.height)
    }
}
