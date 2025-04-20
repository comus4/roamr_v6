import SwiftUI

@main
struct OperatorApp: App {
    /// Flip this to `false` when you’re ready to point at your real backend.
    private static let useMock = true

    @StateObject private var viewModel: MapViewModel

    init() {
        // Choose one provider for both polling & action calls
        let provider: APIServiceProtocol = OperatorApp.useMock
            ? MockDataProvider()
            : APIService()

        _viewModel = StateObject(
            wrappedValue: MapViewModel(
                apiService: provider,
                dataProvider: provider
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            MapContainerView()
                .environmentObject(viewModel)
                .onAppear { viewModel.startPolling() }
        }
    }
}
