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

enum BaseMapProvider: String, CaseIterable, Identifiable {
    case maaKaart
    case maaFoto
    case openTopo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .maaKaart: return "Maa-amet kaart"
        case .maaFoto: return "Maa-amet foto"
        case .openTopo: return "OpenTopoMap"
        }
    }

    var tileFileExtension: String {
        switch self {
        case .maaFoto: return "jpg"
        default: return "png"
        }
    }

    var maxZoom: Int {
        switch self {
        case .openTopo: return 15
        case .maaKaart, .maaFoto: return 19
        }
    }

    var usesTMS: Bool {
        switch self {
        case .maaKaart, .maaFoto: return true
        case .openTopo: return false
        }
    }

    func tileURL(z: Int, x: Int, y: Int) -> URL {
        let yValue: Int
        if usesTMS {
            let maxIndex = (1 << z) - 1
            yValue = maxIndex - y
        } else {
            yValue = y
        }

        let template: String
        switch self {
        case .openTopo:
            template = "https://a.tile.opentopomap.org/{z}/{x}/{y}.png"
        case .maaKaart:
            template = "https://tiles.maaamet.ee/tm/tms/1.0.0/kaart@GMC/{z}/{x}/{y}.png&ASUTUS=MAAAMET&KESKKOND=LIVE&IS=TMSNAIDE"
        case .maaFoto:
            template = "https://tiles.maaamet.ee/tm/tms/1.0.0/foto@GMC/{z}/{x}/{y}.jpg&ASUTUS=MAAAMET&KESKKOND=LIVE&IS=TMSNAIDE"
        }

        let urlString = template
            .replacingOccurrences(of: "{z}", with: String(z))
            .replacingOccurrences(of: "{x}", with: String(x))
            .replacingOccurrences(of: "{y}", with: String(yValue))

        return URL(string: urlString) ?? URL(fileURLWithPath: "/")
    }

    var attributionText: String? {
        nil
    }
}

final class AppSettings: ObservableObject {
    private enum Keys {
        static let theme = "theme"
        static let offlineMode = "offlineMode"
        static let baseMap = "baseMap"
        static let distanceMarkersEnabled = "distanceMarkersEnabled"
    }

    @Published var theme: ThemeSetting {
        didSet { saveTheme() }
    }

    @Published var offlineMode: Bool {
        didSet { UserDefaults.standard.set(offlineMode, forKey: Keys.offlineMode) }
    }

    @Published var baseMap: BaseMapProvider {
        didSet { saveBaseMap() }
    }

    @Published var distanceMarkersEnabled: Bool {
        didSet { UserDefaults.standard.set(distanceMarkersEnabled, forKey: Keys.distanceMarkersEnabled) }
    }

    var colorScheme: ColorScheme? {
        theme.colorScheme
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.theme), let theme = ThemeSetting(rawValue: raw) {
            self.theme = theme
        } else {
            self.theme = .light
        }

        self.offlineMode = UserDefaults.standard.bool(forKey: Keys.offlineMode)

        if let raw = UserDefaults.standard.string(forKey: Keys.baseMap), let map = BaseMapProvider(rawValue: raw) {
            self.baseMap = map
        } else {
            self.baseMap = .maaKaart
        }

        if UserDefaults.standard.object(forKey: Keys.distanceMarkersEnabled) != nil {
            self.distanceMarkersEnabled = UserDefaults.standard.bool(forKey: Keys.distanceMarkersEnabled)
        } else {
            self.distanceMarkersEnabled = true
        }
    }

    func reset() {
        let domain = Bundle.main.bundleIdentifier ?? "ee.impero.gpxviewer"
        UserDefaults.standard.removePersistentDomain(forName: domain)
        theme = .light
        offlineMode = false
        baseMap = .maaKaart
        distanceMarkersEnabled = true
    }

    private func saveTheme() {
        UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme)
    }

    private func saveBaseMap() {
        UserDefaults.standard.set(baseMap.rawValue, forKey: Keys.baseMap)
    }
}
