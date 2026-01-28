import Foundation

final class LibraryStore: ObservableObject {
    @Published private(set) var files: [GPXFile] = []
    @Published var selectedFile: GPXFile?
    @Published var currentTrack: GPXTrack?
    @Published var currentError: String?
    @Published var parseErrors: [URL: String] = [:]
    @Published var trackStats: [URL: TrackStats] = [:]
    @Published var isScanning: Bool = false
    @Published private(set) var starredRelativePaths: Set<String> = [] {
        didSet { saveStarredFiles() }
    }

    private let scanQueue = DispatchQueue(label: "LibraryStore.scan", qos: .userInitiated)
    private let parseQueue = DispatchQueue(label: "LibraryStore.parse", qos: .userInitiated)
    private let validationQueue = DispatchQueue(label: "LibraryStore.validation", qos: .utility)
    private let presenterQueue = OperationQueue()
    private var filePresenter: DocumentsFilePresenter?
    private let starredKey = "starredRelativePaths"

    enum RenameError: LocalizedError, Equatable {
        case emptyName
        case invalidCharacters
        case fileMissing
        case moveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .emptyName:
                return "Enter a name to continue."
            case .invalidCharacters:
                return "Names can’t include “/” or “:”."
            case .fileMissing:
                return "That file is no longer in your library."
            case .moveFailed:
                return "Couldn’t rename this track. Try a different name."
            }
        }
        
        static func == (lhs: RenameError, rhs: RenameError) -> Bool {
            switch (lhs, rhs) {
            case (.emptyName, .emptyName),
                 (.invalidCharacters, .invalidCharacters),
                 (.fileMissing, .fileMissing):
                return true
            case (.moveFailed, .moveFailed):
                return true
            default:
                return false
            }
        }
    }

    init() {
        presenterQueue.maxConcurrentOperationCount = 1
        loadStarredFiles()
        startFilePresenter()
        seedUITestDataIfNeeded()
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
                self.pruneStarredFiles(keeping: results)
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
                let uniqueDestination = Self.uniqueURL(for: destination)
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
        let relativePaths = Set(filesToDelete.map { $0.relativePath })

        scanQueue.async {
            for file in filesToDelete {
                try? FileManager.default.removeItem(at: file.url)
            }

            DispatchQueue.main.async {
                self.files.removeAll { urls.contains($0.url) }
                self.parseErrors = self.parseErrors.filter { !urls.contains($0.key) }
                self.trackStats = self.trackStats.filter { !urls.contains($0.key) }
                self.starredRelativePaths.subtract(relativePaths)
                if let selected = self.selectedFile, urls.contains(selected.url) {
                    self.deselect()
                }
            }
        }
    }

    func isStarred(_ file: GPXFile) -> Bool {
        starredRelativePaths.contains(file.relativePath)
    }

    func toggleStar(for file: GPXFile) {
        if isStarred(file) {
            starredRelativePaths.remove(file.relativePath)
        } else {
            starredRelativePaths.insert(file.relativePath)
        }
    }

    func resetStarred() {
        starredRelativePaths = []
    }

    func renameFile(_ file: GPXFile, to proposedName: String, completion: @escaping (Result<GPXFile, RenameError>) -> Void) {
        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(.emptyName))
            return
        }
        if trimmed.contains("/") || trimmed.contains(":") {
            completion(.failure(.invalidCharacters))
            return
        }

        let normalizedName: String
        if trimmed.lowercased().hasSuffix(".gpx") {
            normalizedName = String(trimmed.dropLast(4))
        } else {
            normalizedName = trimmed
        }

        guard !normalizedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion(.failure(.emptyName))
            return
        }
        if normalizedName.caseInsensitiveCompare(file.displayName) == .orderedSame {
            completion(.success(file))
            return
        }

        let docsURL = documentsDirectory()
        let destination = file.url.deletingLastPathComponent()
            .appendingPathComponent(normalizedName)
            .appendingPathExtension("gpx")

        scanQueue.async {
            guard FileManager.default.fileExists(atPath: file.url.path) else {
                DispatchQueue.main.async {
                    completion(.failure(.fileMissing))
                }
                return
            }

            let uniqueDestination = Self.uniqueURL(for: destination)
            do {
                try FileManager.default.moveItem(at: file.url, to: uniqueDestination)
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.moveFailed(error)))
                }
                return
            }

            let displayName = uniqueDestination.deletingPathExtension().lastPathComponent
            let relativePath = self.relativePath(for: uniqueDestination, docsURL: docsURL)
            let sortDate = Self.dateFromFilename(displayName) ?? (try? uniqueDestination.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            let year = sortDate.flatMap { Calendar.current.dateComponents([.year], from: $0).year }
            let renamedFile = GPXFile(id: uniqueDestination, url: uniqueDestination, displayName: displayName, relativePath: relativePath, sortDate: sortDate, year: year)

            DispatchQueue.main.async {
                let wasStarred = self.starredRelativePaths.contains(file.relativePath)
                if wasStarred {
                    self.starredRelativePaths.remove(file.relativePath)
                    self.starredRelativePaths.insert(relativePath)
                }

                if let index = self.files.firstIndex(where: { $0.url == file.url }) {
                    self.files[index] = renamedFile
                    self.files.sort { lhs, rhs in
                        let left = lhs.sortDate ?? .distantPast
                        let right = rhs.sortDate ?? .distantPast
                        if left == right {
                            return lhs.displayName > rhs.displayName
                        }
                        return left > right
                    }
                }

                if let stats = self.trackStats.removeValue(forKey: file.url) {
                    self.trackStats[renamedFile.url] = stats
                }
                if let error = self.parseErrors.removeValue(forKey: file.url) {
                    self.parseErrors[renamedFile.url] = error
                }

                if self.selectedFile?.url == file.url {
                    self.selectedFile = renamedFile
                }

                completion(.success(renamedFile))
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

    static func uniqueURL(for url: URL) -> URL {
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

    static func dateFromFilename(_ name: String) -> Date? {
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

    private func loadStarredFiles() {
        if let stored = UserDefaults.standard.array(forKey: starredKey) as? [String] {
            starredRelativePaths = Set(stored)
        } else {
            starredRelativePaths = []
        }
    }

    private func saveStarredFiles() {
        UserDefaults.standard.set(Array(starredRelativePaths), forKey: starredKey)
    }

    private func pruneStarredFiles(keeping files: [GPXFile]) {
        let valid = Set(files.map { $0.relativePath })
        if !starredRelativePaths.isSubset(of: valid) {
            starredRelativePaths = starredRelativePaths.intersection(valid)
        }
    }

    private func seedUITestDataIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing") else { return }
        let docsURL = documentsDirectory()
        let originalURL = docsURL.appendingPathComponent("UI Test Track.gpx")
        let renamedURL = docsURL.appendingPathComponent("UI Test Track Renamed.gpx")

        try? FileManager.default.removeItem(at: originalURL)
        try? FileManager.default.removeItem(at: renamedURL)

        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="GPXViewer UITests">
          <trk>
            <name>UI Test Track</name>
            <trkseg>
              <trkpt lat="37.33182" lon="-122.03118"><ele>10</ele></trkpt>
              <trkpt lat="37.33200" lon="-122.03000"><ele>12</ele></trkpt>
            </trkseg>
          </trk>
        </gpx>
        """

        if let data = gpx.data(using: .utf8) {
            try? data.write(to: originalURL, options: .atomic)
        }
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
