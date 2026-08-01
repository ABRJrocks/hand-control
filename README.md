# HandFlow

HandFlow is a privacy-first macOS menu-bar app that turns hand gestures into pointer, drag, scroll, zoom, and window-placement actions.

## Gesture vocabulary

| Gesture | Action |
| --- | --- |
| Raise and move the index finger | Move the pointer relatively; lower it to clutch and reposition |
| Brief thumb-index pinch | Click |
| Hold thumb-index pinch, move, release | Drag and drop |
| Raise index and middle fingers, move vertically | Scroll |
| Touch thumb to middle finger, move vertically | macOS screen zoom |
| Close the hand and swipe horizontally | Move the focused window to the next display |

The pointer uses relative motion, adaptive smoothing, and a small dead zone. A pinch must remain stable before it can click, and the pointer stays anchored while the click is forming. Scroll, zoom, and display gestures also require a short intentional hold before activation.

Screen zoom uses macOS's Control-scroll accessibility gesture. Enable it in System Settings > Accessibility > Zoom > Use scroll gesture with modifier keys to zoom.

## Build and run

Requirements: macOS 14 or newer and Xcode 16 or newer.

```sh
./scripts/build-app.sh
open ./dist/HandFlow.app
```

On first use, approve Camera and Accessibility access. The build script uses an available Apple Development signing identity so the app keeps a stable designated requirement across rebuilds. If you previously approved an older ad-hoc HandFlow build, remove that stale entry in System Settings > Privacy & Security > Accessibility and enable the newly signed app once.

## Privacy and safety

- Video frames are processed locally with Apple Vision.
- No frame recording, image storage, analytics, or network client is included.
- Camera capture starts only after the user presses Start control.
- Pausing from the app or menu bar stops the `AVCaptureSession` and releases any active drag.
- Losing hand tracking releases the mouse button and never converts a partial gesture into a click.

## Development

```sh
swift build
swift test
```

The app uses SwiftUI, AVFoundation, Vision, Core Graphics events, and macOS Accessibility APIs. See [RESEARCH.md](RESEARCH.md) for the model and interaction rationale.
