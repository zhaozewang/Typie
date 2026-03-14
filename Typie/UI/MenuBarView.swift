import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @State private var selectedModelId: String = AppConfig.selectedModelId
    @StateObject private var downloadService = ModelDownloadService()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Typie")
                .font(.headline)

            Divider()

            Label(appState.status.statusText, systemImage: appState.status.menuBarIcon)
                .foregroundColor(statusColor)

            if !appState.lastTranscription.isEmpty {
                Divider()
                Text("Last: \(String(appState.lastTranscription.prefix(80)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Divider()

            Text("Model")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(WhisperModel.all) { model in
                ModelMenuItem(
                    model: model,
                    isSelected: selectedModelId == model.id,
                    downloadService: downloadService,
                    onSelect: {
                        selectedModelId = model.id
                        AppConfig.selectedModelId = model.id
                    }
                )
            }

            Divider()

            Button("Settings...") {
                SettingsView.open()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            HStack {
                Text("Hotkey: \(AppConfig.hotkeyDisplayString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Divider()

            Button("Quit Typie") {
                appState.quit()
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(8)
        .frame(width: 280)
    }

    private var statusColor: Color {
        switch appState.status {
        case .idle: return .primary
        case .recording: return .red
        case .transcribing: return .orange
        case .error: return .red
        }
    }
}

struct ModelMenuItem: View {
    let model: WhisperModel
    let isSelected: Bool
    @ObservedObject var downloadService: ModelDownloadService
    let onSelect: () -> Void

    private var isDownloadingThis: Bool {
        downloadService.downloadingModelId == model.id
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(isSelected ? .accentColor : .secondary)

            Text(model.displayName)
                .font(.caption)

            Text(model.size)
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            if isDownloadingThis {
                ProgressView(value: downloadService.progress)
                    .frame(width: 50)
                Text("\(Int(downloadService.progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if !model.isDownloaded {
                Button("Download") {
                    Task {
                        do {
                            try await downloadService.download(model)
                            onSelect()
                        } catch {
                            AppLogger.general.error("Download failed: \(error.localizedDescription)")
                        }
                    }
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if model.isDownloaded {
                onSelect()
            }
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
    }
}
