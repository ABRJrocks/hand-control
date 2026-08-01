import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "Preferences", subtitle: "Tune movement without changing the gesture vocabulary") {
                EmptyView()
            }

            ScrollView {
                VStack(spacing: 14) {
                    PreferenceGroup(title: "Pointer") {
                        SliderSetting(
                            title: "Pointer speed",
                            detail: "Controls travel distance without changing gesture recognition.",
                            value: Binding(
                                get: { state.settings.pointerSpeed },
                                set: { state.settings.pointerSpeed = $0 }
                            )
                        )
                        Divider()
                        SliderSetting(
                            title: "Movement smoothing",
                            detail: "Higher values reduce hand jitter.",
                            value: Binding(
                                get: { state.settings.smoothing },
                                set: { state.settings.smoothing = $0 }
                            )
                        )
                        Divider()
                        SliderSetting(
                            title: "Gesture sensitivity",
                            detail: "Higher values recognize pinches sooner.",
                            value: Binding(
                                get: { state.settings.sensitivity },
                                set: { state.settings.sensitivity = $0 }
                            )
                        )
                    }

                    PreferenceGroup(title: "Camera") {
                        Toggle(isOn: Binding(
                            get: { state.settings.mirrored },
                            set: { state.settings.mirrored = $0 }
                        )) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Mirror movement").font(.subheadline.weight(.medium))
                                Text("Your hand and pointer move in the same visual direction.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }

                    PreferenceGroup(title: "Privacy") {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(HandFlowTheme.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Local processing only").font(.subheadline.weight(.medium))
                                Text("Vision inference runs on this Mac. HandFlow has no network client and stores no images.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct PreferenceGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            content()
        }
        .panelStyle()
    }
}

private struct SliderSetting: View {
    let title: String
    let detail: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Slider(value: $value, in: 0...1)
                .frame(width: 210)
        }
    }
}
