import SwiftUI
import VanguardUI
import VanguardDomain
import VanguardSecurity
import VanguardObservability

struct SecurityPanel: View {
    @EnvironmentObject private var state: ConsoleAppState
    @State private var selectedSection: SecuritySection = .capabilities

    enum SecuritySection: String, CaseIterable {
        case capabilities = "Capabilities"
        case events = "Events"
        case audit = "Audit"
        case chain = "Chain"
    }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            sectionPicker
            Divider().background(Color.white.opacity(0.04))
            content
        }
    }

    private var panelHeader: some View {
        HStack {
            Label("SECURITY", systemImage: "lock.shield.fill")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.error)
            Spacer()
            Text("ZERO TRUST")
                .font(DS.Typography.micro)
                .foregroundColor(DS.Colors.success)
            Circle().fill(DS.Colors.success).frame(width: 8, height: 8)
        }
        .padding(DS.Spacing.lg)
    }

    private var sectionPicker: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(SecuritySection.allCases, id: \.self) { section in
                Button { selectedSection = section } label: {
                    Text(section.rawValue)
                        .font(DS.Typography.caption)
                        .foregroundColor(selectedSection == section ? DS.Colors.accent : DS.Colors.textTertiary)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .glass(style: selectedSection == section ? .colored(DS.Colors.accent) : .ultraThin, cornerRadius: DS.Radius.pill)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSection {
        case .capabilities: capabilitiesSection
        case .events: eventsSection
        case .audit: auditSection
        case .chain: chainSection
        }
    }

    private var capabilitiesSection: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.sm) {
                HStack {
                    Text("\(state.grantedCapabilities.count) capabilities granted")
                        .font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
                    Spacer()
                }
                ForEach(NodeCapability.allCases, id: \.self) { cap in
                    CapabilityToggleRow(
                        capability: cap,
                        isGranted: state.grantedCapabilities.contains(cap),
                        onToggle: { toggleCapability(cap) }
                    )
                }
            }.padding(DS.Spacing.md)
        }
    }

    private func toggleCapability(_ cap: NodeCapability) {
        if state.grantedCapabilities.contains(cap) {
            state.grantedCapabilities.remove(cap)
        } else {
            state.grantedCapabilities.insert(cap)
        }
    }

    private var eventsSection: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.sm) {
                HStack {
                    Text("\(state.fabricEvents.count) events")
                        .font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
                    Spacer()
                    ElysiumButton(title: "Clear", icon: "trash", color: DS.Colors.error, style: .bordered) { state.clearFabricEvents() }
                        .controlSize(.small)
                }
                if state.fabricEvents.isEmpty {
                    emptySection("No events recorded")
                } else {
                    ForEach(state.fabricEvents.reversed()) { entry in
                        FabricEventRow(entry: entry)
                    }
                }
            }.padding(DS.Spacing.md)
        }
    }

    private var auditSection: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.sm) {
                if state.auditEntries.isEmpty {
                    emptySection("No audit entries")
                } else {
                    ForEach(state.auditEntries.prefix(50)) { entry in
                        AuditEntryRow(entry: entry)
                    }
                }
            }.padding(DS.Spacing.md)
        }
    }

    private var chainSection: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.md) {
                    ZStack {
                        Circle().fill(state.auditChainValid ? DS.Colors.success.opacity(0.15) : DS.Colors.error.opacity(0.15)).frame(width: 48, height: 48)
                        Image(systemName: state.auditChainValid ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(state.auditChainValid ? DS.Colors.success : DS.Colors.error)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.auditChainValid ? "Audit Chain VALID" : "Audit Chain BROKEN")
                            .font(DS.Typography.headline)
                            .foregroundColor(state.auditChainValid ? DS.Colors.success : DS.Colors.error)
                        Text("Tamper detection: SHA-256 hash chain")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.textQuaternary)
                    }
                    Spacer()
                }
                .padding(DS.Spacing.md)
                .glass(style: .ultraThin, cornerRadius: DS.Radius.md)

                metricInfoRow(label: "Audit Entries", value: "\(state.auditEntries.count)")
                metricInfoRow(label: "Chain Status", value: state.auditChainValid ? "Intact" : "Compromised", color: state.auditChainValid ? DS.Colors.success : DS.Colors.error)

                ElysiumButton(title: "Verify Chain", icon: "arrow.triangle.2.circlepath", color: DS.Colors.accent, style: .bordered) {
                    Task { await state.verifyAuditChain() }
                }
            }.padding(DS.Spacing.md)
        }
    }

    private func metricInfoRow(label: String, value: String, color: Color = DS.Colors.textPrimary) -> some View {
        HStack {
            Text(label).font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
            Spacer()
            Text(value).font(DS.Typography.mono).foregroundColor(color)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .glass(style: .ultraThin, cornerRadius: DS.Radius.sm)
    }

    private func emptySection(_ text: String) -> some View {
        HStack {
            Text(text).font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
            Spacer()
        }.padding(DS.Spacing.sm)
    }
}

struct CapabilityToggleRow: View {
    let capability: NodeCapability
    let isGranted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: capabilityIcon(for: capability))
                    .font(.system(size: 12)).foregroundColor(isGranted ? DS.Colors.warning : DS.Colors.textQuaternary).frame(width: 20)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(capability.displayName).font(DS.Typography.headline).foregroundColor(DS.Colors.textPrimary)
                    Text(requiredAction(for: capability)).font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
                }
                Spacer()
                Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14)).foregroundColor(isGranted ? DS.Colors.success : DS.Colors.textQuaternary)
            }
            .padding(DS.Spacing.md)
            .glass(style: .ultraThin, cornerRadius: DS.Radius.md)
            .adaptiveBorder(highlighted: false)
        }
        .buttonStyle(.plain)
    }

    private func capabilityIcon(for c: NodeCapability) -> String {
        switch c {
        case .screenView: return "rectangle.inset.filled.and.person.filled"
        case .screenControl: return "cursorarrow.click.2"
        case .processExecute: return "terminal.fill"
        case .fileRead: return "doc.fill"
        case .fileWrite: return "doc.badge.plus"
        case .nodeRestart: return "arrow.triangle.2.circlepath"
        case .clipboardRead: return "doc.on.clipboard"
        case .clipboardWrite: return "doc.on.clipboard"
        case .terminalOpen: return "terminal.fill"
        case .processTerminate: return "xmark.octagon"
        case .telemetryRead: return "chart.bar.fill"
        case .nodeShutdown: return "power"
        @unknown default: return "questionmark.circle"
        }
    }

    private func requiredAction(for c: NodeCapability) -> String {
        switch c {
        case .screenView: return "startScreenCapture"
        case .screenControl: return "startScreenControl"
        case .processExecute: return "executeProcess"
        case .fileRead: return "readFiles"
        case .fileWrite: return "writeFiles, transferFile"
        case .nodeRestart: return "restart"
        case .clipboardRead, .clipboardWrite: return "clipboard sync"
        case .terminalOpen: return "openTerminal"
        case .processTerminate: return "process termination"
        case .telemetryRead: return "telemetry access"
        case .nodeShutdown: return "shutdown"
        @unknown default: return "unknown"
        }
    }
}

struct FabricEventRow: View {
    let entry: ConsoleAppState.FabricEventEntry

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Circle().fill(categoryColor).frame(width: 6, height: 6)
            Image(systemName: categoryIcon).font(.system(size: 10)).foregroundColor(categoryColor).frame(width: 16)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(eventDescription).font(DS.Typography.mono).foregroundColor(DS.Colors.textSecondary).lineLimit(1)
                Text(entry.event.category.uppercased())
                    .font(DS.Typography.micro).foregroundColor(DS.Colors.textQuaternary)
            }
            Spacer()
            Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                .font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
        }.padding(.vertical, DS.Spacing.xxs)
    }

    private var eventDescription: String {
        switch entry.event {
        case .nodeDiscovered(let id): return "Node discovered: \(id.rawValue.uuidString.prefix(8))"
        case .nodeConnected(let id): return "Node connected: \(id.rawValue.uuidString.prefix(8))"
        case .nodeDisconnected(let id): return "Node disconnected: \(id.rawValue.uuidString.prefix(8))"
        case .pairingStarted(let id): return "Pairing started: \(id.rawValue.uuidString.prefix(8))"
        case .pairingCompleted(let id): return "Pairing completed: \(id.rawValue.uuidString.prefix(8))"
        case .sessionOpened(let id): return "Session opened: \(id.rawValue.uuidString.prefix(8))"
        case .sessionClosed(let id): return "Session closed: \(id.rawValue.uuidString.prefix(8))"
        case .captureStarted: return "Screen capture started"
        case .captureStopped: return "Screen capture stopped"
        case .frameDropped(let reason): return "Frame dropped: \(reason)"
        case .inputDispatched(let action): return "Input dispatched: \(action)"
        case .terminalOpened(let id): return "Terminal opened: \(id.rawValue.uuidString.prefix(8))"
        case .terminalClosed(let id): return "Terminal closed: \(id.rawValue.uuidString.prefix(8))"
        case .clipboardSynced: return "Clipboard synced"
        case .clipboardChanged: return "Clipboard changed"
        case .artifactReceived(let name, let version): return "Artifact: \(name) v\(version)"
        case .jobStarted(let name): return "Job started: \(name)"
        case .jobCompleted(let name, let code): return "Job completed: \(name) (exit \(code))"
        case .jobFailed(let name, let error): return "Job failed: \(name) - \(error)"
        case .emergencyStop: return "EMERGENCY STOP triggered"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    private var categoryColor: Color {
        switch entry.event.category {
        case "node": return DS.Colors.info
        case "pairing": return DS.Colors.warning
        case "session": return DS.Colors.accent
        case "capture": return DS.Colors.success
        case "input": return DS.Colors.textTertiary
        case "terminal": return DS.Colors.success
        case "clipboard": return DS.Colors.textQuaternary
        case "artifact": return DS.Colors.accent
        case "job": return DS.Colors.warning
        case "error": return DS.Colors.error
        default: return DS.Colors.textQuaternary
        }
    }

    private var categoryIcon: String {
        switch entry.event.category {
        case "node": return "network"
        case "pairing": return "link"
        case "session": return "rectangle.connected.to.line.below"
        case "capture": return "rectangle.dashed.badge.record"
        case "input": return "cursorarrow"
        case "terminal": return "terminal"
        case "clipboard": return "doc.on.clipboard"
        case "artifact": return "archivebox"
        case "job": return "hammer"
        case "error": return "exclamationmark.triangle"
        default: return "circle"
        }
    }
}

struct AuditEntryRow: View {
    let entry: ConsoleAppState.AuditLogEntry

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Circle().fill(entry.severity.color).frame(width: 6, height: 6)
            Text(entry.action).font(DS.Typography.mono).foregroundColor(DS.Colors.textSecondary).lineLimit(1)
            Spacer()
            Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                .font(DS.Typography.caption).foregroundColor(DS.Colors.textQuaternary)
        }.padding(.vertical, DS.Spacing.xxs)
    }
}
