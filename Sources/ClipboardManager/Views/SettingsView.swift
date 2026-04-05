import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("maxItems")      private var maxItems: Int    = 10_000
    @AppStorage("maxAgeDays")    private var maxAgeDays: Int  = 30
    @AppStorage("launchAtLogin") private var launchAtLogin    = false
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                generalSection
                privacySection
                storageSection
                aboutSection
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 430, height: 510)
        .confirmationDialog(
            "Clear all clipboard history?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive) { viewModel.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Pinned and favorited items will also be removed.")
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            LabeledContent("Max history") {
                Stepper("\(maxItems) items", value: $maxItems, in: 100...50_000, step: 500)
            }
            LabeledContent("Auto-delete") {
                Stepper("after \(maxAgeDays) days", value: $maxAgeDays, in: 1...365)
            }
            Toggle("Launch at login", isOn: $launchAtLogin)
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section("Privacy & Security") {
            LabeledContent("Clipboard tracking") {
                Toggle("", isOn: Binding(
                    get:  { ClipboardMonitor.shared.isMonitoring },
                    set:  { _ in ClipboardMonitor.shared.toggle() }
                ))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Default excluded apps:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(["1Password", "Bitwarden", "Keychain Access"], id: \.self) { app in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                        Text(app)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("To exclude additional apps, add their bundle IDs to the blacklist in code (ClipboardMonitor.blacklist).")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        Section("Storage") {
            LabeledContent("Items stored") {
                Text("\(StorageService.shared.totalCount())")
                    .foregroundStyle(.secondary)
            }

            Button("Apply cleanup rules now") {
                StorageService.shared.cleanup(maxItems: maxItems, maxAgeDays: maxAgeDays)
            }

            Button("Clear all history…", role: .destructive) {
                showClearConfirm = true
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0")
            LabeledContent("Global shortcut", value: "⌘ ⇧ V")
            LabeledContent("Storage", value: "Local SQLite (private)")
        }
    }
}
