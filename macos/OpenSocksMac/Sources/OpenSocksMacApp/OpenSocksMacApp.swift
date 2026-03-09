import AppKit
import OpenSocksMacCore
import SwiftUI

final class OpenSocksAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}

@main
struct OpenSocksMacApp: App {
    @NSApplicationDelegateAdaptor(OpenSocksAppDelegate.self) private var appDelegate
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
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
        }
        .windowResizability(.contentSize)
    }
}
