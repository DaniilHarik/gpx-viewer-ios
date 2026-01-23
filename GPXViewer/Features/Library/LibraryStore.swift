import Foundation

final class LibraryStore: ObservableObject {
    @Published private(set) var files: [GPXFile] = []
    @Published var selectedFile: GPXFile?
    @Published var currentTrack: GPXTrack?
    @Published var currentError: String?
    @Published var parseErrors: [URL: String] = [:]
    @Published var trackStats: [URL: TrackStats] = [:]
    @Published var isScanning: Bool = false

    private let scanQueue = DispatchQueue(label: "LibraryStore.scan", qos: .userInitiated)
    private let parseQueue = DispatchQueue(label: "LibraryStore.parse", qos: .userInitiated)
    private let validationQueue = DispatchQueue(label: "LibraryStore.validation", qos: .utility)
    private let presenterQueue = OperationQueue()
    private var filePresenter: DocumentsFilePresenter?

    init() {
        presenterQueue.maxConcurrentOperationCount = 1
        startFilePresenter()
        scanDocuments()
    }

    deinit {
        if let presenter = filePresenter {
            NSFileCoordinator.removeFilePresenter(presenter)
        }
    }

    func scanDocuments() {
        let docsURL = documentsDirectory()
        DispatchQueue.main.async {
            self.isScanning = true
        }

        scanQueue.async {
            let enumerator = FileManager.default.enumerator(at: docsURL, includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey], options: [.skipsHiddenFiles])

            var results: [GPXFile] = []
            while let fileURL = enumerator?.nextObject() as? URL {
                let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
                if values?.isDirectory == true { continue }
                guard fileURL.pathExtension.lowercased() == "gpx" else { continue }
                let relativePath = self.relativePath(for: fileURL, docsURL: docsURL)
                let displayName = fileURL.deletingPathExtension().lastPathComponent
                let sortDate = Self.dateFromFilename(displayName) ?? values?.contentModificationDate
                let year = sortDate.flatMap { Calendar.current.dateComponents([.year], from: $0).year }

                results.append(GPXFile(id: fileURL, url: fileURL, displayName: displayName, relativePath: relativePath, sortDate: sortDate, year: year))
            }

            results.sort { (lhs, rhs) in
                let left = lhs.sortDate ?? .distantPast
                let right = rhs.sortDate ?? .distantPast
                if left == right {
                    return lhs.displayName > rhs.displayName
                }
                return left > right
            }

            DispatchQueue.main.async {
                self.files = results
                let urls = Set(results.map { $0.url })
                self.trackStats = self.trackStats.filter { urls.contains($0.key) }
                self.parseErrors = self.parseErrors.filter { urls.contains($0.key) }
                self.isScanning = false
            }

            self.validateFiles(results)
        }
    }

    func importFiles(_ urls: [URL]) {
        let docsURL = documentsDirectory()

        scanQueue.async {
            for url in urls {
                _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }

                guard url.pathExtension.lowercased() == "gpx" else { continue }

                let destination = docsURL.appendingPathComponent(url.lastPathComponent)
                let uniqueDestination = self.uniqueURL(for: destination)
                do {
                    try FileManager.default.copyItem(at: url, to: uniqueDestination)
                } catch {
                    continue
                }
            }

            DispatchQueue.main.async {
                self.scanDocuments()
            }
        }
    }

    func select(_ file: GPXFile) {
        selectedFile = file
        currentError = nil

        parseQueue.async {
            do {
                let track = try GPXParser().parse(url: file.url)
                DispatchQueue.main.async {
                    self.currentTrack = track
                    self.currentError = nil
                    self.trackStats[file.url] = track.stats
                    self.parseErrors[file.url] = nil
                }
            } catch {
                DispatchQueue.main.async {
                    self.currentTrack = nil
                    self.currentError = "Invalid GPX"
                    self.parseErrors[file.url] = "Invalid GPX"
                    self.trackStats[file.url] = nil
                }
            }
        }
    }

    func deselect() {
        selectedFile = nil
        currentTrack = nil
        currentError = nil
    }

    func deleteFiles(_ filesToDelete: [GPXFile]) {
        guard !filesToDelete.isEmpty else { return }
        let urls = Set(filesToDelete.map { $0.url })

        scanQueue.async {
            for file in filesToDelete {
                try? FileManager.default.removeItem(at: file.url)
            }

            DispatchQueue.main.async {
                self.files.removeAll { urls.contains($0.url) }
                self.parseErrors = self.parseErrors.filter { !urls.contains($0.key) }
                self.trackStats = self.trackStats.filter { !urls.contains($0.key) }
                if let selected = self.selectedFile, urls.contains(selected.url) {
                    self.deselect()
                }
            }
        }
    }

    private func validateFiles(_ files: [GPXFile]) {
        validationQueue.async {
            var errors: [URL: String] = [:]
            var stats: [URL: TrackStats] = [:]
            for file in files {
                do {
                    let track = try GPXParser().parse(url: file.url)
                    stats[file.url] = track.stats
                } catch {
                    errors[file.url] = "Invalid GPX"
                }
            }

            DispatchQueue.main.async {
                self.parseErrors = errors
                self.trackStats = stats
            }
        }
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/tmp")
    }

    private func uniqueURL(for url: URL) -> URL {
        var candidate = url
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let base = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            candidate = url.deletingLastPathComponent().appendingPathComponent("\(base)-\(counter)").appendingPathExtension(ext)
            counter += 1
        }
        return candidate
    }

    private func startFilePresenter() {
        let presenter = DocumentsFilePresenter(presentedItemURL: documentsDirectory()) { [weak self] in
            self?.scanDocuments()
        }
        presenter.presentedItemOperationQueue = presenterQueue
        NSFileCoordinator.addFilePresenter(presenter)
        filePresenter = presenter
    }

    private static func dateFromFilename(_ name: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if name.count >= 10 {
            let prefix = String(name.prefix(10))
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: prefix) {
                return date
            }
        }

        if name.count >= 8 {
            let prefix = String(name.prefix(8))
            formatter.dateFormat = "yyyyMMdd"
            if let date = formatter.date(from: prefix) {
                return date
            }
        }

        return nil
    }

    private func relativePath(for fileURL: URL, docsURL: URL) -> String {
        let filePath = normalizedPath(fileURL)
        let docsPath = normalizedPath(docsURL)
        if filePath.hasPrefix(docsPath + "/") {
            return String(filePath.dropFirst(docsPath.count + 1))
        }
        if filePath.hasPrefix(docsPath) {
            return String(filePath.dropFirst(docsPath.count))
        }
        return fileURL.lastPathComponent
    }

    private func normalizedPath(_ url: URL) -> String {
        let standardized = url.standardizedFileURL.path
        if standardized.hasPrefix("/private") {
            return String(standardized.dropFirst("/private".count))
        }
        return standardized
    }
}

final class DocumentsFilePresenter: NSObject, NSFilePresenter {
    let presentedItemURL: URL?
    var presentedItemOperationQueue: OperationQueue = OperationQueue()
    private let onChange: () -> Void

    init(presentedItemURL: URL, onChange: @escaping () -> Void) {
        self.presentedItemURL = presentedItemURL
        self.onChange = onChange
        super.init()
    }

    func presentedItemDidChange() {
        onChange()
    }

    func presentedSubitemDidAppear(at url: URL) {
        onChange()
    }

    func presentedSubitemDidChange(at url: URL) {
        onChange()
    }

    func presentedSubitemDidDisappear(at url: URL) {
        onChange()
    }
}
