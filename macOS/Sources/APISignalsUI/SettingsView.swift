import SwiftUI
import AppKit


public struct SettingsView: View {
    @AppStorage("defaultTimeout") private var defaultTimeout: Double = 30
    @AppStorage("followRedirects") private var followRedirects: Bool = true
    @AppStorage("verifySSL") private var verifySSL: Bool = true
    @AppStorage("colorScheme") private var colorScheme: String = "auto"
    @SwiftUI.Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $colorScheme) {
                        Text("System").tag("auto")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Request Defaults") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Default Timeout")
                            Spacer()
                            Text("\(Int(defaultTimeout))s")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $defaultTimeout, in: 5...300, step: 5)
                    }

                    Toggle("Follow Redirects", isOn: $followRedirects)

                    Toggle("Verify SSL Certificates", isOn: $verifySSL)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("License")
                        Spacer()
                        Text("MIT")
                            .foregroundStyle(.secondary)
                    }
                    Link("GitHub Repository", destination: URL(string: "https://github.com/apisignals/api-signals")!)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 460, height: 420)
        .preferredColorScheme(resolvedColorScheme)
    }

    private var resolvedColorScheme: ColorScheme? {
        switch colorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
