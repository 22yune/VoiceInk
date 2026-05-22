import SwiftUI

struct PythonLocalModelCardView: View {
    let displayName: String
    let language: String
    let size: String
    let description: String
    let speed: Double
    let accuracy: Double
    let ramUsage: Double
    let requiresAppleSilicon: Bool
    let isRuntimeInstalled: Bool
    let isDownloaded: Bool
    let isCurrent: Bool
    let isBusy: Bool
    let status: PythonBackedModelStatus?
    let installRuntimeAction: () -> Void
    let downloadAction: () -> Void
    let setDefaultAction: () -> Void
    let deleteAction: () -> Void
    let showInFinderAction: () -> Void

    private var isArchitectureSupported: Bool {
        !requiresAppleSilicon || SystemArchitecture.isAppleSilicon
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                headerSection
                metadataSection
                descriptionSection
                progressSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actionSection
        }
        .padding(16)
        .background(CardBackground(isSelected: isCurrent, useAccentGradientWhenSelected: isCurrent))
        .opacity(isArchitectureSupported ? 1.0 : 0.55)
    }

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.labelColor))

            if requiresAppleSilicon {
                Label("Apple Silicon", systemImage: "cpu")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                Label("CPU", systemImage: "cpu")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var metadataSection: some View {
        HStack(spacing: 12) {
            Label(language, systemImage: "globe")
            Label(size, systemImage: "internaldrive")
            Label("\(String(format: "%.1f", ramUsage)) GB RAM", systemImage: "memorychip")
            HStack(spacing: 3) {
                Text("Speed")
                progressDotsWithNumber(value: speed * 10)
            }
            .fixedSize(horizontal: true, vertical: false)
            HStack(spacing: 3) {
                Text("Accuracy")
                progressDotsWithNumber(value: accuracy * 10)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .font(.system(size: 11))
        .foregroundColor(Color(.secondaryLabelColor))
        .lineLimit(1)
    }

    private var descriptionSection: some View {
        Text(isArchitectureSupported ? description : "MLX Audio requires Apple Silicon.")
            .font(.system(size: 11))
            .foregroundColor(Color(.secondaryLabelColor))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }

    private var progressSection: some View {
        Group {
            if let status {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(status.message)
                            .lineLimit(1)

                        Spacer()

                        Text("\(Int(status.fractionCompleted * 100))%")
                            .fontDesign(.monospaced)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(.secondaryLabelColor))

                    ProgressView(value: status.fractionCompleted)
                        .progressViewStyle(LinearProgressViewStyle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .animation(.smooth, value: status.fractionCompleted)
            }
        }
    }

    private var actionSection: some View {
        HStack(spacing: 8) {
            if isCurrent {
                Text("Default Model")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabelColor))
            } else if !isArchitectureSupported {
                Text("Unavailable")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabelColor))
            } else if isDownloaded {
                Button("Set as Default", action: setDefaultAction)
                    .font(.system(size: 12))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Button(action: downloadAction) {
                    HStack(spacing: 4) {
                        Text(buttonTitle)
                        Image(systemName: isRuntimeInstalled ? "arrow.down.circle" : "shippingbox")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }

            if isDownloaded {
                Menu {
                    Button(action: deleteAction) {
                        Label("Delete Model", systemImage: "trash")
                    }

                    Button(action: showInFinderAction) {
                        Label("Show in Finder", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 20, height: 20)
            }
        }
    }

    private var buttonTitle: String {
        if isBusy {
            return isRuntimeInstalled ? "Downloading..." : "Installing..."
        }
        return isRuntimeInstalled ? "Download" : "Install & Download"
    }
}
