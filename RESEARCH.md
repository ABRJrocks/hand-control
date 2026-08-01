# HandFlow research and architecture

## Model decision

HandFlow uses Apple's on-device Vision hand-pose model as its landmark detector, then applies deterministic temporal interpretation:

1. `VNDetectHumanHandPoseRequest` returns one hand's joint coordinates and per-joint confidence.
2. Low-confidence joints are rejected.
3. A One Euro filter smooths pointer motion while preserving fast movement.
4. Gesture geometry is normalized by palm size so thresholds adapt to camera distance.
5. Hysteresis, minimum holds, movement thresholds, and cooldowns turn noisy frame-level measurements into stable actions.

This is preferable to using a large image or language model in the control loop. Pointer control needs predictable latency and bounded behavior, while the learned model's main job is accurately locating joints.

### Why Apple Vision by default

- It is built into macOS and performs inference on device.
- It exposes the joint confidences needed for input safety.
- It avoids a Python service, web runtime, model download, or camera-frame IPC.
- It integrates directly with `AVCaptureVideoDataOutput` and the app's native permission lifecycle.

Apple recommends limiting `maximumHandCount` for latency-sensitive work. HandFlow sets it to one because only a single control hand is needed.

### Why MediaPipe is not bundled

MediaPipe Hands is a strong alternative. Its published pipeline combines a palm detector with a cropped landmark model and predicts 21 landmarks in real time. MediaPipe Tasks also offers a gesture classifier and on-device processing. The current first-class Swift setup is centered on iOS and CocoaPods, however; a native macOS distribution would require a substantially larger C++ or custom framework integration. That cost does not improve this app's small, stateful gesture vocabulary enough to justify the larger binary and maintenance surface.

The code intentionally separates camera inference, gesture interpretation, and system control so a future MediaPipe or custom Core ML provider can replace Vision without rewriting the app.

## Interaction safety

- Camera access is requested only after an explicit Start action.
- System input is gated by macOS Accessibility trust.
- Quick pinch and drag are distinguished using both time and movement.
- Pinch uses separate engage and release thresholds to prevent flicker.
- Window movement has a one-second cooldown.
- A lost hand cancels state and releases the mouse button without clicking.
- Every feature can be disabled independently.
- Menu-bar pause is always available while the main window is closed.

## Sources

- [Apple Vision hand-pose request](https://developer.apple.com/documentation/vision/vndetecthumanhandposerequest)
- [Apple WWDC: Detect Body and Hand Pose with Vision](https://developer.apple.com/videos/play/wwdc2020/10653/)
- [Apple camera authorization guidance](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media)
- [Apple Accessibility trust API](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)
- [Apple Quartz event API](https://developer.apple.com/documentation/coregraphics/cgevent)
- [MediaPipe Hands paper](https://arxiv.org/abs/2006.10214)
- [On-device Real-time Hand Gesture Recognition](https://arxiv.org/abs/2111.00038)
- [On-device Real-time Custom Hand Gesture Recognition](https://arxiv.org/abs/2309.10858)
- [The One Euro Filter](https://gery.casiez.net/1euro/)
