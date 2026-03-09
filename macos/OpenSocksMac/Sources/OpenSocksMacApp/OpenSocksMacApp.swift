import SwiftUI
import OpenSocksMacCore

@main
struct OpenSocksMacApp: App {
    @StateObject private var viewModel = BootstrapViewModel(
        apiClient: OpenSocksAPIClient(),
        tokenStore: KeychainClientTokenStore(
            service: "com.opensocks.macos",
            account: "client-token"
        ),
        baseURLStore: UserDefaultsBaseURLStore()
    )

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .windowResizability(.contentSize)
    }
}
