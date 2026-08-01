import SwiftUI

private struct GestureDefinition: Identifiable {
    let id: ControlFeature
    let title: String
    let instruction: String
    let result: String
    let symbol: String
}

struct GestureLibraryView: View {
    @EnvironmentObject private var state: AppState

    private let definitions: [GestureDefinition] = [
        .init(id: .pointer, title: "Point", instruction: "Raise your index finger to move. Lower it to reposition your hand without moving the pointer.", result: "Moves the pointer", symbol: "cursorarrow.motionlines"),
        .init(id: .drag, title: "Pinch", instruction: "Pinch briefly and release to click. Hold, then move to drag.", result: "Clicks or drags", symbol: "hand.pinch"),
        .init(id: .scroll, title: "Two fingers", instruction: "Raise index and middle, then move vertically.", result: "Scrolls content", symbol: "arrow.up.and.down"),
        .init(id: .zoom, title: "Middle pinch", instruction: "Touch thumb to middle, then move vertically.", result: "Controls screen zoom", symbol: "plus.magnifyingglass"),
        .init(id: .displays, title: "Fist swipe", instruction: "Close your hand and swipe left or right.", result: "Moves the focused window", symbol: "rectangle.2.swap")
    ]

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Gestures", subtitle: "A small vocabulary designed to avoid accidental actions") {
                Text("\(state.settings.enabledFeatures.count) enabled")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                    ForEach(definitions) { definition in
                        GestureCard(definition: definition)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct GestureCard: View {
    @EnvironmentObject private var state: AppState
    let definition: GestureDefinition

    private var isEnabled: Binding<Bool> {
        Binding(
            get: { state.settings.isEnabled(definition.id) },
            set: { state.settings.setEnabled(definition.id, $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Image(systemName: definition.symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(HandFlowTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(HandFlowTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                Spacer()
                Toggle("", isOn: isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(definition.title).font(.headline)
                Text(definition.instruction)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Label(definition.result, systemImage: "arrow.turn.down.right")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(HandFlowTheme.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: HandFlowTheme.radius))
        .overlay(RoundedRectangle(cornerRadius: HandFlowTheme.radius).stroke(HandFlowTheme.line))
        .opacity(isEnabled.wrappedValue ? 1 : 0.58)
    }
}
