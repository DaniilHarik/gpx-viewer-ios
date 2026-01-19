import Foundation
import MapKit
import UIKit

final class CachedTileOverlay: MKTileOverlay {
    let provider: BaseMapProvider
    var offlineMode: Bool

    private let cache = TileCache.shared
    private let session: URLSession

    private static let emptyTileData: Data = {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData() ?? Data()
    }()

    init(provider: BaseMapProvider, offlineMode: Bool) {
        self.provider = provider
        self.offlineMode = offlineMode
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
        super.init(urlTemplate: nil)
        tileSize = CGSize(width: 256, height: 256)
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        if path.z > provider.maxZoom {
            result(Self.emptyTileData, nil)
            return
        }

        if let cached = cache.load(provider: provider, path: path) {
            result(cached, nil)
            return
        }

        if offlineMode {
            result(Self.emptyTileData, nil)
            return
        }

        let url = provider.tileURL(z: path.z, x: path.x, y: path.y)
        let task = session.dataTask(with: url) { data, response, error in
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let data, !data.isEmpty {
                self.cache.store(data: data, provider: self.provider, path: path)
                result(data, nil)
            } else {
                DispatchQueue.main.async {
                    self.cache.stats.recordError()
                    BannerCenter.shared.show("Tile load failed")
                }
                result(Self.emptyTileData, nil)
            }
        }
        task.resume()
    }
}
