import Foundation
import MapKit

final class TileCacheStats: ObservableObject {
    @Published private(set) var hits: Int = 0
    @Published private(set) var misses: Int = 0
    @Published private(set) var errors: Int = 0

    func recordHit() {
        hits += 1
    }

    func recordMiss() {
        misses += 1
    }

    func recordError() {
        errors += 1
    }

    func reset() {
        hits = 0
        misses = 0
        errors = 0
    }
}

final class TileCache {
    static let shared = TileCache()

    let stats = TileCacheStats()

    private let fileManager: FileManager
    private let ioQueue: DispatchQueue
    private let sizeLimit: Int64
    private let trimInterval: TimeInterval
    private var lastTrimTime: Date
    private let baseDirectory: URL?

    init(
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil,
        sizeLimit: Int64 = 1_073_741_824,
        trimInterval: TimeInterval = 30
    ) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
        self.sizeLimit = sizeLimit
        self.trimInterval = trimInterval
        self.ioQueue = DispatchQueue(label: "TileCache.IO", qos: .utility)
        self.lastTrimTime = .distantPast
    }

    func load(provider: BaseMapProvider, path: MKTileOverlayPath) -> Data? {
        ioQueue.sync {
            let url = cacheURL(provider: provider, path: path)
            guard fileManager.fileExists(atPath: url.path) else {
                DispatchQueue.main.async { self.stats.recordMiss() }
                return nil
            }

            do {
                let data = try Data(contentsOf: url)
                try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
                DispatchQueue.main.async { self.stats.recordHit() }
                return data
            } catch {
                DispatchQueue.main.async { self.stats.recordError() }
                return nil
            }
        }
    }

    func store(data: Data, provider: BaseMapProvider, path: MKTileOverlayPath) {
        ioQueue.async {
            let url = self.cacheURL(provider: provider, path: path)
            let dirURL = url.deletingLastPathComponent()
            do {
                try self.fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
            } catch {
                DispatchQueue.main.async { self.stats.recordError() }
            }
            self.trimIfNeeded()
        }
    }

    func clearAll(completion: (() -> Void)? = nil) {
        ioQueue.async {
            let base = self.baseCacheDirectory()
            try? self.fileManager.removeItem(at: base)
            DispatchQueue.main.async {
                self.stats.reset()
                completion?()
            }
        }
    }

    func currentSize(completion: @escaping (Int64) -> Void) {
        ioQueue.async {
            let size = self.calculateSize()
            DispatchQueue.main.async {
                completion(size)
            }
        }
    }

    func trimNow(completion: (() -> Void)? = nil) {
        ioQueue.async {
            self.lastTrimTime = Date()
            self.trimCache()
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    private func cacheURL(provider: BaseMapProvider, path: MKTileOverlayPath) -> URL {
        let base = baseCacheDirectory()
        let providerDir = base.appendingPathComponent(provider.cacheKey, isDirectory: true)
        let zDir = providerDir.appendingPathComponent(String(path.z), isDirectory: true)
        let xDir = zDir.appendingPathComponent(String(path.x), isDirectory: true)
        let filename = "\(path.y).\(provider.tileFileExtension)"
        return xDir.appendingPathComponent(filename)
    }

    private func baseCacheDirectory() -> URL {
        if let baseDirectory {
            return baseDirectory
        }
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/tmp")
        return caches.appendingPathComponent("TileCache", isDirectory: true)
    }

    private func calculateSize() -> Int64 {
        let base = baseCacheDirectory()
        guard let enumerator = fileManager.enumerator(at: base, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]) else {
                continue
            }
            if values.isDirectory == true { continue }
            totalSize += Int64(values.fileSize ?? 0)
        }
        return totalSize
    }

    private func trimIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastTrimTime) > trimInterval else { return }
        lastTrimTime = now

        ioQueue.async {
            self.trimCache()
        }
    }

    private func trimCache() {
        let base = baseCacheDirectory()
        guard let enumerator = fileManager.enumerator(at: base, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return
        }

        var files: [(url: URL, size: Int64, date: Date)] = []
        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]) else {
                continue
            }
            if values.isDirectory == true { continue }
            let size = Int64(values.fileSize ?? 0)
            let date = values.contentModificationDate ?? .distantPast
            files.append((fileURL, size, date))
            totalSize += size
        }

        guard totalSize > sizeLimit else { return }

        let sorted = files.sorted { $0.date < $1.date }
        var bytesToRemove = totalSize - sizeLimit

        for entry in sorted where bytesToRemove > 0 {
            try? fileManager.removeItem(at: entry.url)
            bytesToRemove -= entry.size
        }
    }
}
