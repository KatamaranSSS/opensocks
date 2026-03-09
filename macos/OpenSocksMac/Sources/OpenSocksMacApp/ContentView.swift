import AppKit
import OpenSocksMacCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: BootstrapViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            connectionForm
            statusBlock
            configsList
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 560)
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
            TextField("API base URL", text: $viewModel.baseURLString)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            SecureField("Client token", text: $viewModel.clientToken)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

            HStack(spacing: 12) {
                Button("Save Settings") {
                    viewModel.persistSettings()
                }

                Button("Load Configs") {
                    Task {
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
