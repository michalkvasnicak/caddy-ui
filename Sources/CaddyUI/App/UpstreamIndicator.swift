import SwiftUI

struct UpstreamIndicator: View {
    let upstream: String

    @State private var reachable: Bool?

    private var label: String {
        guard let reachable else { return "Checking…" }
        return reachable ? "Reachable" : "Unreachable"
    }

    private var color: Color {
        guard let reachable else { return .secondary }
        return reachable ? .green : .red
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Upstream: \(label)")
        .help("TCP reachability of the upstream, independent of Caddy")
        .task {
            reachable = nil
            while !Task.isCancelled {
                let result = await UpstreamProbe.isReachable(upstream)
                guard !Task.isCancelled else { return }
                reachable = result
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }
}
