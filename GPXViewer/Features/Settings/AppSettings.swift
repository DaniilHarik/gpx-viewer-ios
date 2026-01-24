import Foundation
import SwiftUI

enum ThemeSetting: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }

    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

struct BaseMapProvider: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var urlTemplate: String
    var maxZoom: Int
    var usesTMS: Bool
    var tileFileExtension: String
    var attributionText: String?

    var title: String { name }

    var cacheKey: String {
        id.replacingOccurrences(of: "/", with: "_")
    }

    func tileURL(z: Int, x: Int, y: Int) -> URL {
        let yValue: Int
        if usesTMS {
            let maxIndex = (1 << z) - 1
            yValue = maxIndex - y
        } else {
            yValue = y
        }

        let urlString = urlTemplate
            .replacingOccurrences(of: "{z}", with: String(z))
            .replacingOccurrences(of: "{x}", with: String(x))
            .replacingOccurrences(of: "{y}", with: String(yValue))

        return URL(string: urlString) ?? URL(fileURLWithPath: "/")
    }

    static let maaKaart = BaseMapProvider(
        id: "maa-kaart",
        name: "Maa-amet kaart",
        urlTemplate: "https://tiles.maaamet.ee/tm/tms/1.0.0/kaart@GMC/{z}/{x}/{y}.png&ASUTUS=MAAAMET&KESKKOND=LIVE&IS=TMSNAIDE",
        maxZoom: 19,
        usesTMS: true,
        tileFileExtension: "png",
        attributionText: nil
    )

    static let maaFoto = BaseMapProvider(
        id: "maa-foto",
        name: "Maa-amet foto",
        urlTemplate: "https://tiles.maaamet.ee/tm/tms/1.0.0/foto@GMC/{z}/{x}/{y}.jpg&ASUTUS=MAAAMET&KESKKOND=LIVE&IS=TMSNAIDE",
        maxZoom: 19,
        usesTMS: true,
        tileFileExtension: "jpg",
        attributionText: nil
    )

    static let openTopo = BaseMapProvider(
        id: "open-topo",
        name: "OpenTopoMap",
        urlTemplate: "https://a.tile.opentopomap.org/{z}/{x}/{y}.png",
        maxZoom: 15,
        usesTMS: false,
        tileFileExtension: "png",
        attributionText: nil
    )

    static let openStreetMap = BaseMapProvider(
        id: "openstreetmap",
        name: "OpenStreetMap",
        urlTemplate: "https://c.tile.openstreetmap.org/{z}/{x}/{y}.png",
        maxZoom: 19,
        usesTMS: false,
        tileFileExtension: "png",
        attributionText: nil
    )

    static func builtInProviders() -> [BaseMapProvider] {
        [
            maaKaart,
            maaFoto,
            openTopo,
            openStreetMap
        ]
    }

    static func newCustom() -> BaseMapProvider {
        BaseMapProvider(
            id: UUID().uuidString,
            name: "Custom Provider",
            urlTemplate: "https://example.com/tiles/{z}/{x}/{y}.png",
            maxZoom: 19,
            usesTMS: false,
            tileFileExtension: "png",
            attributionText: nil
        )
    }
}

enum DistanceMarkerInterval: Int, CaseIterable, Identifiable {
    case one = 1
    case three = 3
    case five = 5
    case ten = 10

    var id: Int { rawValue }

    var title: String {
        "\(rawValue) km"
    }
}

final class AppSettings: ObservableObject {
    private enum Keys {
        static let theme = "theme"
        static let offlineMode = "offlineMode"
        static let baseMap = "baseMap"
        static let baseMapId = "baseMapId"
        static let tileProviders = "tileProviders"
        static let distanceMarkersEnabled = "distanceMarkersEnabled"
        static let distanceMarkerInterval = "distanceMarkerInterval"
    }

    @Published var theme: ThemeSetting {
        didSet { saveTheme() }
    }

    @Published var offlineMode: Bool {
        didSet { UserDefaults.standard.set(offlineMode, forKey: Keys.offlineMode) }
    }

    @Published var tileProviders: [BaseMapProvider] {
        didSet {
            saveTileProviders()
            ensureValidBaseMap()
        }
    }

    @Published var baseMapId: String {
        didSet { saveBaseMapId() }
    }

    @Published var distanceMarkersEnabled: Bool {
        didSet { UserDefaults.standard.set(distanceMarkersEnabled, forKey: Keys.distanceMarkersEnabled) }
    }

    @Published var distanceMarkerInterval: DistanceMarkerInterval {
        didSet { saveDistanceMarkerInterval() }
    }

    var colorScheme: ColorScheme? {
        theme.colorScheme
    }

    var baseMap: BaseMapProvider {
        get {
            tileProviders.first { $0.id == baseMapId } ?? tileProviders.first ?? BaseMapProvider.builtInProviders()[0]
        }
        set {
            baseMapId = newValue.id
        }
    }

    init() {
        let defaults = UserDefaults.standard
        if let raw = UserDefaults.standard.string(forKey: Keys.theme), let theme = ThemeSetting(rawValue: raw) {
            self.theme = theme
        } else {
            self.theme = .light
        }

        self.offlineMode = defaults.bool(forKey: Keys.offlineMode)

        let providers: [BaseMapProvider]
        if let data = defaults.data(forKey: Keys.tileProviders),
           let decoded = try? JSONDecoder().decode([BaseMapProvider].self, from: data),
           !decoded.isEmpty {
            providers = decoded
        } else {
            providers = BaseMapProvider.builtInProviders()
        }

        self.tileProviders = providers
        self.baseMapId = AppSettings.resolveBaseMapId(defaults: defaults, providers: providers)

        if UserDefaults.standard.object(forKey: Keys.distanceMarkersEnabled) != nil {
            self.distanceMarkersEnabled = UserDefaults.standard.bool(forKey: Keys.distanceMarkersEnabled)
        } else {
            self.distanceMarkersEnabled = true
        }

        if let raw = UserDefaults.standard.object(forKey: Keys.distanceMarkerInterval) as? Int,
           let interval = DistanceMarkerInterval(rawValue: raw) {
            self.distanceMarkerInterval = interval
        } else {
            self.distanceMarkerInterval = .one
        }
    }

    func reset() {
        let domain = Bundle.main.bundleIdentifier ?? "ee.impero.gpxviewer"
        UserDefaults.standard.removePersistentDomain(forName: domain)
        theme = .light
        offlineMode = false
        tileProviders = BaseMapProvider.builtInProviders()
        baseMapId = tileProviders.first?.id ?? BaseMapProvider.builtInProviders()[0].id
        distanceMarkersEnabled = true
        distanceMarkerInterval = .one
    }

    private func saveTheme() {
        UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme)
    }

    private func saveDistanceMarkerInterval() {
        UserDefaults.standard.set(distanceMarkerInterval.rawValue, forKey: Keys.distanceMarkerInterval)
    }

    private func saveTileProviders() {
        if let data = try? JSONEncoder().encode(tileProviders) {
            UserDefaults.standard.set(data, forKey: Keys.tileProviders)
        }
    }

    private func saveBaseMapId() {
        UserDefaults.standard.set(baseMapId, forKey: Keys.baseMapId)
    }

    private func ensureValidBaseMap() {
        guard tileProviders.contains(where: { $0.id == baseMapId }) else {
            baseMapId = tileProviders.first?.id ?? BaseMapProvider.builtInProviders()[0].id
            return
        }
    }

    private static func resolveBaseMapId(defaults: UserDefaults, providers: [BaseMapProvider]) -> String {
        if let savedId = defaults.string(forKey: Keys.baseMapId),
           providers.contains(where: { $0.id == savedId }) {
            return savedId
        }

        if let legacy = defaults.string(forKey: Keys.baseMap) {
            let legacyMap: [String: String] = [
                "maaKaart": "maa-kaart",
                "maaFoto": "maa-foto",
                "openTopo": "open-topo"
            ]
            if let mapped = legacyMap[legacy],
               providers.contains(where: { $0.id == mapped }) {
                return mapped
            }
        }

        return providers.first?.id ?? BaseMapProvider.builtInProviders()[0].id
    }
}
