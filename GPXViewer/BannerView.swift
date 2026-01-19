import SwiftUI

final class BannerCenter: ObservableObject {
    static let shared = BannerCenter()

    @Published private(set) var message: String?
    private var hideWorkItem: DispatchWorkItem?

    func show(_ text: String, duration: TimeInterval = 3.0) {
        hideWorkItem?.cancel()
        withAnimation {
            message = text
        }

        let workItem = DispatchWorkItem { [weak self] in
            withAnimation {
                self?.message = nil
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }
}

struct BannerView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Color.black.opacity(0.8))
            )
            .shadow(radius: 6)
    }
}
