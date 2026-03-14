import Foundation

@MainActor
final class ModelDownloadService: NSObject, ObservableObject {
    @Published var isDownloading = false
    @Published var progress: Double = 0
    @Published var downloadingModelId: String?
    @Published var error: String?

    private var downloadTask: URLSessionDownloadTask?
    private var session: URLSession?
    private var continuation: CheckedContinuation<URL, Error>?

    func download(_ model: WhisperModel) async throws {
        guard !isDownloading else { return }

        // Ensure models directory exists
        let dir = NSString(string: "~/.typie/models").expandingTildeInPath
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        isDownloading = true
        progress = 0
        downloadingModelId = model.id
        error = nil

        defer {
            isDownloading = false
            downloadingModelId = nil
        }

        let tempURL: URL = try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let config = URLSessionConfiguration.default
            self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
            self.downloadTask = self.session?.downloadTask(with: model.downloadURL)
            self.downloadTask?.resume()
        }

        // Move to final location
        let destURL = URL(fileURLWithPath: model.localPath)
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destURL)

        AppLogger.general.info("Model downloaded: \(model.displayName)")
    }

    func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadingModelId = nil
        progress = 0
    }
}

extension ModelDownloadService: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Copy to a temp location we control (the system will delete `location` after this returns)
        let tempDest = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bin")
        try? FileManager.default.copyItem(at: location, to: tempDest)

        Task { @MainActor in
            self.continuation?.resume(returning: tempDest)
            self.continuation = nil
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            if totalBytesExpectedToWrite > 0 {
                self.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error, (error as NSError).code != NSURLErrorCancelled {
            Task { @MainActor in
                self.error = error.localizedDescription
                self.continuation?.resume(throwing: error)
                self.continuation = nil
            }
        }
    }
}
