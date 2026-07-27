import SwiftUI
import VanguardUI

struct TrustedPeersPanel: View {
    @EnvironmentObject private var state: ConsoleAppState
    @State private var showRemoveConfirmation = false
    @State private var peerToRemove: ConsoleAppState.TrustedPeer?

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider().background(Color.white.opacity(0.04))
            if state.trustedPeers.isEmpty {
                emptyState
            } else {
                peerList
            }
        }
        .alert("Remove Trusted Peer", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) { peerToRemove = nil }
            Button("Remove", role: .destructive) {
                if let peer = peerToRemove {
                    state.removeTrustedPeer(peer)
                    peerToRemove = nil
                }
            }
        } message: {
            if let peer = peerToRemove {
                Text("Remove \(peer.name) from trusted peers? You'll need to re-pair to connect again.")
            }
        }
    }

    private var panelHeader: some View {
        HStack {
            Label("TRUSTED PEERS", systemImage: "lock.shield")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.accent)
            Spacer()
            Text("\(state.trustedPeers.count) peers")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textQuaternary)
        }
        .padding(DS.Spacing.lg)
    }

    private var peerList: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.sm) {
                ForEach(state.trustedPeers) { peer in
                    peerRow(peer)
                }
            }
            .padding(DS.Spacing.md)
        }
    }

    private func peerRow(_ peer: ConsoleAppState.TrustedPeer) -> some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle().fill(DS.Colors.accent.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Colors.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(peer.name).font(DS.Typography.headline).foregroundColor(DS.Colors.textPrimary)
                Text(peer.host).font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
                Text("Paired \(peer.pairedAt.formatted(.relative(presentation: .named)))")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textQuaternary)
            }
            Spacer()
            Button {
                peerToRemove = peer
                showRemoveConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(DS.Colors.error)
            }
            .buttonStyle(.plain)
            .help("Remove trusted peer")
        }
        .padding(DS.Spacing.md)
        .glass(style: .ultraThin, cornerRadius: DS.Radius.md)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer().frame(height: 60)
            Image(systemName: "lock.shield")
                .font(.system(size: 28))
                .foregroundColor(DS.Colors.textQuaternary)
            Text("No trusted peers")
                .font(DS.Typography.subheadline)
                .foregroundColor(DS.Colors.textTertiary)
            Text("Pair with a node to add it as a trusted peer")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colors.textQuaternary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
