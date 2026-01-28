import CoreLocation
import SwiftUI

struct PointsView: View {
    @EnvironmentObject private var pointsStore: PointsStore
    @Binding var selectedTab: Int

    @State private var showingAdd = false
    @State private var editingPoint: SavedPoint?
    @State private var pendingDeletion: [SavedPoint] = []
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                if pointsStore.points.isEmpty {
                    emptyState
                } else {
                    if !starredPoints.isEmpty {
                        Section(header: Text("Starred")) {
                            ForEach(starredPoints) { point in
                                PointsRow(
                                    point: point,
                                    isSelected: pointsStore.selectedPoint?.id == point.id,
                                    onSelect: { toggleSelection(for: point) },
                                    onToggleStar: { pointsStore.toggleStar(for: point) },
                                    onEdit: { beginEdit(for: point) }
                                )
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    starAction(for: point)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    editAction(for: point)
                                }
                            }
                            .onDelete { offsets in
                                confirmDelete(in: starredPoints, offsets: offsets)
                            }
                        }
                    }

                    if !unstarredPoints.isEmpty {
                        Section(header: Text("Points")) {
                            ForEach(unstarredPoints) { point in
                                PointsRow(
                                    point: point,
                                    isSelected: pointsStore.selectedPoint?.id == point.id,
                                    onSelect: { toggleSelection(for: point) },
                                    onToggleStar: { pointsStore.toggleStar(for: point) },
                                    onEdit: { beginEdit(for: point) }
                                )
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    starAction(for: point)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    editAction(for: point)
                                }
                            }
                            .onDelete { offsets in
                                confirmDelete(in: unstarredPoints, offsets: offsets)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Points")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack {
                    AddPointView(mode: .add) { title, iconName, latitude, longitude in
                        pointsStore.addPoint(
                            title: title,
                            iconName: iconName,
                            latitude: latitude,
                            longitude: longitude
                        )
                    }
                }
            }
            .sheet(item: $editingPoint) { point in
                NavigationStack {
                    AddPointView(mode: .edit(point: point)) { title, iconName, latitude, longitude in
                        pointsStore.updatePoint(
                            point,
                            title: title,
                            iconName: iconName,
                            latitude: latitude,
                            longitude: longitude
                        )
                    }
                }
            }
            .alert("Delete Point", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    pointsStore.deletePoints(pendingDeletion)
                    pendingDeletion = []
                }
                Button("Cancel", role: .cancel) {
                    pendingDeletion = []
                }
            } message: {
                if pendingDeletion.count == 1, let title = pendingDeletion.first?.title {
                    Text("This will permanently delete \"\(title)\" from your points.")
                } else {
                    Text("This will permanently delete the selected points from your points.")
                }
            }
        }
    }

    private var starredPoints: [SavedPoint] {
        pointsStore.points.filter { $0.isStarred }
    }

    private var unstarredPoints: [SavedPoint] {
        pointsStore.points.filter { !$0.isStarred }
    }

    private func toggleSelection(for point: SavedPoint) {
        if pointsStore.selectedPoint?.id == point.id {
            pointsStore.deselect()
        } else {
            pointsStore.select(point)
            selectedTab = 0
        }
    }

    private func confirmDelete(in points: [SavedPoint], offsets: IndexSet) {
        let toDelete = offsets.compactMap { index -> SavedPoint? in
            guard points.indices.contains(index) else { return nil }
            return points[index]
        }
        guard !toDelete.isEmpty else { return }
        pendingDeletion = toDelete
        showingDeleteConfirm = true
    }

    private func beginEdit(for point: SavedPoint) {
        editingPoint = point
    }

    @ViewBuilder
    private func starAction(for point: SavedPoint) -> some View {
        if point.isStarred {
            Button {
                pointsStore.toggleStar(for: point)
            } label: {
                Label("Unstar", systemImage: "star.slash")
            }
            .tint(.gray)
        } else {
            Button {
                pointsStore.toggleStar(for: point)
            } label: {
                Label("Star", systemImage: "star.fill")
            }
            .tint(.yellow)
        }
    }

    private func editAction(for point: SavedPoint) -> some View {
        Button {
            beginEdit(for: point)
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        .tint(.blue)
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No points yet")
                .font(.headline)
            Text("Add your first point to keep favorite locations handy.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

private struct PointsRow: View {
    let point: SavedPoint
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleStar: () -> Void
    let onEdit: () -> Void
    private static let coordinateFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 6
        formatter.numberStyle = .decimal
        return formatter
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(point.isStarred ? Color.yellow.opacity(0.85) : Color.blue.opacity(0.85))
                Image(systemName: point.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(point.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.blue : Color.primary)
                Text(coordinateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if point.isStarred {
                Image(systemName: "star.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.yellow)
                    .accessibilityLabel("Starred")
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button(action: onToggleStar) {
                Label(point.isStarred ? "Unstar" : "Star", systemImage: point.isStarred ? "star.slash" : "star.fill")
            }
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
        }
    }

    private var coordinateText: String {
        "Lat \(formatCoordinate(point.latitude))  Lon \(formatCoordinate(point.longitude))"
    }

    private func formatCoordinate(_ value: Double) -> String {
        PointsRow.coordinateFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.5f", value)
    }
}

private struct AddPointView: View {
    enum Mode {
        case add
        case edit(point: SavedPoint)

        var title: String {
            switch self {
            case .add:
                return "New Point"
            case .edit:
                return "Edit Point"
            }
        }

        var actionTitle: String {
            switch self {
            case .add:
                return "Add"
            case .edit:
                return "Save"
            }
        }

        var existingPoint: SavedPoint? {
            switch self {
            case .add:
                return nil
            case .edit(let point):
                return point
            }
        }
    }

    struct PointIconOption: Identifiable {
        let id: String
        let name: String
        let systemName: String
    }

    private let iconOptions: [PointIconOption] = [
        PointIconOption(id: "mappin.circle.fill", name: "Pin", systemName: "mappin.circle.fill"),
        PointIconOption(id: "flag.fill", name: "Flag", systemName: "flag.fill"),
        PointIconOption(id: "star.fill", name: "Star", systemName: "star.fill"),
        PointIconOption(id: "figure.hiking", name: "Hike", systemName: "figure.hiking"),
        PointIconOption(id: "tent.fill", name: "Camp", systemName: "tent.fill"),
        PointIconOption(id: "camera.fill", name: "Camera", systemName: "camera.fill"),
        PointIconOption(id: "binoculars.fill", name: "Lookout", systemName: "binoculars.fill"),
        PointIconOption(id: "mountain.2.fill", name: "Peak", systemName: "mountain.2.fill"),
        PointIconOption(id: "drop.fill", name: "Water", systemName: "drop.fill"),
        PointIconOption(id: "cup.and.saucer.fill", name: "Cafe", systemName: "cup.and.saucer.fill"),
        PointIconOption(id: "bicycle", name: "Bike", systemName: "bicycle"),
        PointIconOption(id: "car.fill", name: "Car", systemName: "car.fill"),
        PointIconOption(id: "flame.fill", name: "Fire", systemName: "flame.fill")
    ]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager
    @State private var title = ""
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var selectedIconName = "mappin.circle.fill"
    @State private var awaitingCurrentLocation = false

    private static let coordinateFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 6
        formatter.numberStyle = .decimal
        return formatter
    }()

    let mode: Mode
    let onSave: (String, String, Double, Double) -> Void

    init(mode: Mode, onSave: @escaping (String, String, Double, Double) -> Void) {
        self.mode = mode
        self.onSave = onSave

        let point = mode.existingPoint
        _title = State(initialValue: point?.title ?? "")
        _selectedIconName = State(initialValue: point?.iconName ?? "mappin.circle.fill")
        if let point {
            _latitudeText = State(initialValue: Self.formatCoordinate(point.latitude))
            _longitudeText = State(initialValue: Self.formatCoordinate(point.longitude))
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Title", text: $title)
                    .textInputAutocapitalization(.words)
                Picker("Icon", selection: $selectedIconName) {
                    ForEach(iconOptions) { option in
                        Label(option.name, systemImage: option.systemName)
                            .tag(option.systemName)
                    }
                }
            }

            Section(header: Text("Coordinates")) {
                TextField("Latitude", text: $latitudeText)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Longitude", text: $longitudeText)
                    .keyboardType(.numbersAndPunctuation)
                Button(action: useCurrentLocation) {
                    Label("Use Current Location", systemImage: "location.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!canRequestLocation)

                if awaitingCurrentLocation {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Waiting for location…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let locationStatusMessage {
                    Text(locationStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text("Decimal degrees, for example 37.33182, -122.03118")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let message = validationMessage {
                Section {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(mode.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(mode.actionTitle) {
                    guard let latitude = parsedLatitude,
                          let longitude = parsedLongitude else { return }
                    onSave(titleTrimmed, selectedIconName, latitude, longitude)
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
        .onChange(of: locationManager.location) { _, newValue in
            guard awaitingCurrentLocation, let newValue else { return }
            applyLocation(newValue)
        }
    }

    private var titleTrimmed: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedLatitude: Double? {
        parseCoordinate(latitudeText)
    }

    private var parsedLongitude: Double? {
        parseCoordinate(longitudeText)
    }

    private var canSave: Bool {
        isValid
    }

    private var validationMessage: String? {
        guard hasInput else { return nil }
        if titleTrimmed.isEmpty {
            return "Enter a title to continue."
        }
        guard let latitude = parsedLatitude else {
            return "Enter a valid latitude."
        }
        guard let longitude = parsedLongitude else {
            return "Enter a valid longitude."
        }
        if latitude < -90 || latitude > 90 {
            return "Latitude must be between -90 and 90."
        }
        if longitude < -180 || longitude > 180 {
            return "Longitude must be between -180 and 180."
        }
        return nil
    }

    private var isValid: Bool {
        guard !titleTrimmed.isEmpty,
              let latitude = parsedLatitude,
              let longitude = parsedLongitude else { return false }
        return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180
    }

    private var hasInput: Bool {
        !titleTrimmed.isEmpty || !latitudeText.isEmpty || !longitudeText.isEmpty
    }

    private func parseCoordinate(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private var canRequestLocation: Bool {
        switch locationManager.authorizationStatus {
        case .restricted, .denied:
            return false
        default:
            return true
        }
    }

    private var locationStatusMessage: String? {
        switch locationManager.authorizationStatus {
        case .restricted, .denied:
            return "Location access is disabled. Enable it in Settings to use current location."
        case .notDetermined:
            return "Allow location access to fill coordinates automatically."
        default:
            return nil
        }
    }

    private func useCurrentLocation() {
        awaitingCurrentLocation = true
        locationManager.requestWhenInUse()
        locationManager.startUpdating()
        if let location = locationManager.location {
            applyLocation(location)
        }
    }

    private func applyLocation(_ location: CLLocation) {
        latitudeText = Self.formatCoordinate(location.coordinate.latitude)
        longitudeText = Self.formatCoordinate(location.coordinate.longitude)
        awaitingCurrentLocation = false
        locationManager.stopUpdating()
    }

    private static func formatCoordinate(_ value: Double) -> String {
        coordinateFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.5f", value)
    }
}
