import SwiftUI

struct SettingsView: View {
    @ObservedObject private var api          = ClaudeAPIManager.shared
    @ObservedObject private var theme        = ThemeStore.shared
    @ObservedObject private var focusSettings = FocusOverlaySettings.shared

    @Environment(\.dismiss) private var dismiss

    // Local editable state so we don't write on every keystroke
    @State private var anthropicKey  = ""
    @State private var openRouterKey = ""
    @State private var anthropicModel  = ""
    @State private var openRouterModel = ""

    var body: some View {
        ZStack {
            TerminalTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Title bar
                HStack {
                    Text("⚙ SETTINGS")
                        .font(TerminalTheme.header)
                        .foregroundColor(TerminalTheme.primary)
                        .glowEffect()
                        .tracking(3)
                    Spacer()
                    Button {
                        saveAndDismiss()
                    } label: {
                        Text("[CLOSE]")
                            .font(TerminalTheme.small)
                            .foregroundColor(TerminalTheme.primaryDim)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .terminalBorder(TerminalTheme.border)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(TerminalTheme.surface)

                Divider().background(TerminalTheme.border)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // MARK: Theme
                        sectionHeader("THEME")

                        VStack(spacing: 8) {
                            ForEach(TerminalPreset.allCases, id: \.self) { preset in
                                themeRow(preset)
                            }
                        }

                        Divider().background(TerminalTheme.borderDim)

                        // MARK: API Provider
                        sectionHeader("AI PROVIDER")

                        VStack(spacing: 8) {
                            ForEach(APIProvider.allCases, id: \.self) { p in
                                providerRow(p)
                            }
                        }

                        Divider().background(TerminalTheme.borderDim)

                        // MARK: API credentials (only for selected provider)
                        if api.provider == .anthropic {
                            sectionHeader("ANTHROPIC")

                            apiField(
                                label: "API KEY",
                                placeholder: "sk-ant-...",
                                text: $anthropicKey,
                                isSecret: true
                            )

                            apiField(
                                label: "MODEL",
                                placeholder: APIProvider.anthropic.defaultModel,
                                text: $anthropicModel,
                                isSecret: false
                            )

                            Divider().background(TerminalTheme.borderDim)
                        }

                        if api.provider == .openRouter {
                            sectionHeader("OPENROUTER")

                            apiField(
                                label: "API KEY",
                                placeholder: "sk-or-...",
                                text: $openRouterKey,
                                isSecret: true
                            )

                            apiField(
                                label: "MODEL",
                                placeholder: APIProvider.openRouter.defaultModel,
                                text: $openRouterModel,
                                isSecret: false
                            )

                            Divider().background(TerminalTheme.borderDim)
                        }

                        // MARK: Focus Overlay
                        sectionHeader("FOCUS OVERLAY")

                        // Display picker
                        VStack(spacing: 6) {
                            ForEach(NSScreen.screens, id: \.displayID) { screen in
                                if let id = screen.displayID {
                                    let enabled = focusSettings.isEnabled(id)
                                    Button {
                                        focusSettings.toggleDisplay(id)
                                        FocusOverlayManager.shared.refreshVisibility()
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: enabled ? "checkmark.square.fill" : "square")
                                                .foregroundColor(enabled ? TerminalTheme.cyan : TerminalTheme.primaryDim)
                                                .font(.system(size: 13))
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(screen.localizedName)
                                                    .font(TerminalTheme.small)
                                                    .foregroundColor(enabled ? TerminalTheme.primary : TerminalTheme.primaryDim)
                                                Text("\(Int(screen.frame.width))×\(Int(screen.frame.height))")
                                                    .font(TerminalTheme.micro)
                                                    .foregroundColor(TerminalTheme.primaryDim.opacity(0.5))
                                            }
                                            Spacer()
                                            if screen == NSScreen.main {
                                                Text("主屏幕")
                                                    .font(TerminalTheme.micro)
                                                    .foregroundColor(TerminalTheme.primaryDim.opacity(0.4))
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(enabled ? TerminalTheme.surface : Color.clear)
                                        .terminalBorder(enabled ? TerminalTheme.cyan.opacity(0.4) : TerminalTheme.borderDim)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(spacing: 12) {
                            // Opacity
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("边缘亮度")
                                        .font(TerminalTheme.small)
                                        .foregroundColor(TerminalTheme.primaryDim)
                                    Spacer()
                                    Text(String(format: "%.0f%%", focusSettings.opacity * 100))
                                        .font(TerminalTheme.small)
                                        .foregroundColor(TerminalTheme.cyan)
                                        .monospacedDigit()
                                }
                                Slider(value: $focusSettings.opacity, in: 0.1...0.75)
                                    .accentColor(TerminalTheme.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(TerminalTheme.surface)
                            .terminalBorder(TerminalTheme.borderDim)

                            // Gradient steepness
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("过渡范围")
                                        .font(TerminalTheme.small)
                                        .foregroundColor(TerminalTheme.primaryDim)
                                    Spacer()
                                    Text(focusSettings.gradientEdge < 0.25 ? "缓" :
                                         focusSettings.gradientEdge > 0.6  ? "陡" : "中")
                                        .font(TerminalTheme.small)
                                        .foregroundColor(TerminalTheme.cyan)
                                }
                                Slider(value: $focusSettings.gradientEdge, in: 0.05...0.8)
                                    .accentColor(TerminalTheme.primary)
                                HStack {
                                    Text("渐变从中心扩散")
                                        .font(TerminalTheme.micro)
                                        .foregroundColor(TerminalTheme.primaryDim.opacity(0.5))
                                    Spacer()
                                    Text("集中在边缘")
                                        .font(TerminalTheme.micro)
                                        .foregroundColor(TerminalTheme.primaryDim.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(TerminalTheme.surface)
                            .terminalBorder(TerminalTheme.borderDim)
                        }

                        // Save button
                        HStack {
                            Spacer()
                            Button {
                                saveAndDismiss()
                            } label: {
                                Text("[ SAVE & CLOSE ]")
                                    .font(TerminalTheme.body)
                                    .tracking(2)
                                    .foregroundColor(TerminalTheme.background)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(TerminalTheme.primary)
                            }
                            .buttonStyle(.plain)
                            .glowEffect()
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 460, height: 580)
        .onAppear { loadCurrentValues() }
    }

    // MARK: - Components

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(TerminalTheme.micro)
            .foregroundColor(TerminalTheme.primaryDim)
            .tracking(3)
    }

    private func themeRow(_ preset: TerminalPreset) -> some View {
        let selected = theme.preset == preset
        return Button {
            theme.preset = preset
        } label: {
            HStack(spacing: 12) {
                // Color swatch strip
                HStack(spacing: 3) {
                    colorSwatch(preset.primary)
                    colorSwatch(preset.primaryDim)
                    colorSwatch(preset.background)
                    colorSwatch(preset.surface)
                }

                Text(preset.displayName)
                    .font(TerminalTheme.body)
                    .foregroundColor(selected ? TerminalTheme.primary : TerminalTheme.primaryDim)
                    .tracking(1)

                Spacer()

                if selected {
                    Text("◆")
                        .font(TerminalTheme.small)
                        .foregroundColor(TerminalTheme.primary)
                        .glowEffect()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? TerminalTheme.surface : Color.clear)
            .terminalBorder(selected ? TerminalTheme.border : TerminalTheme.borderDim)
        }
        .buttonStyle(.plain)
    }

    private func colorSwatch(_ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: 12, height: 12)
    }

    private func providerRow(_ p: APIProvider) -> some View {
        let selected = api.provider == p
        return Button {
            api.switchProvider(p)
        } label: {
            HStack {
                Text(p.rawValue.uppercased())
                    .font(TerminalTheme.body)
                    .foregroundColor(selected ? TerminalTheme.primary : TerminalTheme.primaryDim)
                    .tracking(1)
                Spacer()
                if selected {
                    Text("◆ ACTIVE")
                        .font(TerminalTheme.micro)
                        .foregroundColor(TerminalTheme.cyan)
                        .tracking(2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selected ? TerminalTheme.surface : Color.clear)
            .terminalBorder(selected ? TerminalTheme.cyan.opacity(0.5) : TerminalTheme.borderDim)
        }
        .buttonStyle(.plain)
    }

    private func apiField(label: String, placeholder: String, text: Binding<String>, isSecret: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(TerminalTheme.micro)
                .foregroundColor(TerminalTheme.primaryDim)
                .tracking(2)

            Group {
                if isSecret {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(TerminalTheme.small)
            .foregroundColor(TerminalTheme.primary)
            .textFieldStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(TerminalTheme.surface)
            .terminalBorder(TerminalTheme.border)
        }
    }

    // MARK: - Persistence helpers

    private func loadCurrentValues() {
        anthropicKey    = UserDefaults.standard.string(forKey: "dayos_api_key_Anthropic")   ?? ""
        openRouterKey   = UserDefaults.standard.string(forKey: "dayos_api_key_OpenRouter")  ?? ""
        anthropicModel  = UserDefaults.standard.string(forKey: "dayos_model_Anthropic")     ?? APIProvider.anthropic.defaultModel
        openRouterModel = UserDefaults.standard.string(forKey: "dayos_model_OpenRouter")    ?? APIProvider.openRouter.defaultModel
    }

    private func saveAndDismiss() {
        UserDefaults.standard.set(anthropicKey,    forKey: "dayos_api_key_Anthropic")
        UserDefaults.standard.set(openRouterKey,   forKey: "dayos_api_key_OpenRouter")
        UserDefaults.standard.set(anthropicModel,  forKey: "dayos_model_Anthropic")
        UserDefaults.standard.set(openRouterModel, forKey: "dayos_model_OpenRouter")

        // Reload the active provider's key/model into the manager
        let p = api.provider
        api.apiKey = UserDefaults.standard.string(forKey: "dayos_api_key_\(p.rawValue)") ?? ""
        api.model  = UserDefaults.standard.string(forKey: "dayos_model_\(p.rawValue)")  ?? p.defaultModel

        dismiss()
    }
}
