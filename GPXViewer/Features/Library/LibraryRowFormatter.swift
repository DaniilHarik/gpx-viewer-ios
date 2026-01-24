import Foundation

struct LibraryRowFormatter {
    static func subtitle(for file: GPXFile) -> String? {
        if let prefix = datePrefix(from: file.displayName) {
            return prefix
        }
        return file.relativePath
    }

    static func displayTitle(for name: String) -> String {
        guard let prefix = datePrefix(from: name) else { return name }
        var remainder = String(name.dropFirst(prefix.count))
        remainder = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        if remainder.hasPrefix("-") || remainder.hasPrefix("_") {
            remainder = String(remainder.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return remainder.isEmpty ? name : remainder
    }

    static func datePrefix(from name: String) -> String? {
        guard name.count >= 10 else { return nil }
        let prefix = String(name.prefix(10))
        guard isValidDatePrefix(prefix) else { return nil }
        return prefix
    }

    private static func isValidDatePrefix(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        return dateFormatter.date(from: value) != nil
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
