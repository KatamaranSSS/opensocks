import AppKit
import OpenSocksMacCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: BootstrapViewModel
    @State private var baseURLDraft: String
    @State private var clientTokenDraft: String
    @State private var proxyBinaryPathDraft: String
    @State private var localSocksPortDraft: String
    @State private var autoConfigureSystemProxyDraft: Bool

    init(viewModel: BootstrapViewModel) {
        self.viewModel = viewModel
        _baseURLDraft = State(initialValue: viewModel.baseURLString)
        _clientTokenDraft = State(initialValue: viewModel.clientToken)
        _proxyBinaryPathDraft = State(initialValue: viewModel.proxyBinaryPath)
        _localSocksPortDraft = State(initialValue: viewModel.localSocksPort)
        _autoConfigureSystemProxyDraft = State(initialValue: viewModel.autoConfigureSystemProxy)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            connectionForm
            statusBlock
            proxyStatusBlock
            systemProxyStatusBlock
            configsList
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 560)
        .task {
            await viewModel.refreshLocalProxyState()
            await viewModel.refreshSystemProxyState()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OpenSocks macOS")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Текущий этап: загрузка профиля пользователя и выдача `ss://` конфигов.")
                .foregroundStyle(.secondary)
        }
    }

    private var connectionForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppKitTextField(
                placeholder: "API base URL",
                text: $baseURLDraft
            )
            .frame(height: 24)

            AppKitTextField(
                placeholder: "Client token",
                text: $clientTokenDraft
            )
            .frame(height: 24)

            HStack(spacing: 12) {
                AppKitTextField(
                    placeholder: "sslocal binary path",
                    text: $proxyBinaryPathDraft
                )
                .frame(height: 24)

                AppKitTextField(
                    placeholder: "Local SOCKS5 port",
                    text: $localSocksPortDraft
                )
                .frame(width: 140, height: 24)
            }

            Toggle("Enable macOS system SOCKS proxy after connect", isOn: $autoConfigureSystemProxyDraft)

            HStack(spacing: 12) {
                Button("Save Settings") {
                    syncDraftsToViewModel()
                    viewModel.persistSettings()
                }

                Button("Load Configs") {
                    Task {
                        syncDraftsToViewModel()
                        await viewModel.fetchBootstrap()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.isLoading)

                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private func syncDraftsToViewModel() {
        viewModel.baseURLString = baseURLDraft
        viewModel.clientToken = clientTokenDraft
        viewModel.proxyBinaryPath = proxyBinaryPathDraft
        viewModel.localSocksPort = localSocksPortDraft
        viewModel.autoConfigureSystemProxy = autoConfigureSystemProxyDraft
    }

    @ViewBuilder
    private var statusBlock: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .foregroundStyle(.red)
        } else if !viewModel.statusMessage.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.statusMessage)
                    .foregroundStyle(.secondary)

                if !viewModel.username.isEmpty {
                    Text("User: \(viewModel.username)")
                        .font(.headline)
                }
            }
        }
    }

    @ViewBuilder
    private var proxyStatusBlock: some View {
        GroupBox("Local Proxy") {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.proxyStatusMessage)
                    .font(.headline)

                if let proxyErrorMessage = viewModel.proxyErrorMessage {
                    Text(proxyErrorMessage)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                if !viewModel.proxyLogOutput.isEmpty {
                    Text(viewModel.proxyLogOutput)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var systemProxyStatusBlock: some View {
        GroupBox("System Proxy") {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.systemProxyStatusMessage)
                    .font(.headline)

                if let systemProxyErrorMessage = viewModel.systemProxyErrorMessage {
                    Text(systemProxyErrorMessage)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }

                HStack(spacing: 12) {
                    Button("Enable System Proxy") {
                        syncDraftsToViewModel()
                        Task {
                            await viewModel.enableSystemProxy()
                        }
                    }
                    .disabled(!viewModel.isLocalProxyListening)

                    Button("Disable System Proxy") {
                        Task {
                            await viewModel.disableSystemProxy()
                        }
                    }
                    .disabled(!viewModel.isSystemProxyEnabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var configsList: some View {
        GroupBox("Available Configs") {
            if viewModel.configs.isEmpty {
                ContentUnavailableView(
                    "No active configs",
                    systemImage: "network.slash",
                    description: Text(
                        "Load bootstrap data or activate at least one key on the server."
                    )
                )
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                List(viewModel.configs) { config in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(config.name)
                                .font(.headline)
                            Spacer()
                            Text("\(config.server):\(config.serverPort)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        LabeledContent("Cipher", value: config.method)
                        LabeledContent("Tag", value: config.tag)

                        Text(config.ssURL)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)

                        HStack {
                            if viewModel.isActive(config: config) {
                                Button("Disconnect") {
                                    Task {
                                        await viewModel.disconnect()
                                    }
                                }
                            } else if !viewModel.canConnect(config: config) {
                                Button("Port Busy") {}
                                    .disabled(true)
                            } else {
                                Button("Connect") {
                                    syncDraftsToViewModel()
                                    Task {
                                        await viewModel.connect(config: config)
                                    }
                                }
                            }

                            Button("Copy SS URL") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(config.ssURL, forType: .string)
                            }

                            Button("Copy Password") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(config.password, forType: .string)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.inset)
                .frame(minHeight: 280)
            }
        }
    }
}
