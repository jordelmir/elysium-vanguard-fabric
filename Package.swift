// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ElysiumVanguardFabric",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "VanguardNodeMac", targets: ["VanguardNodeMac"]),
        .executable(name: "VanguardConsoleMac", targets: ["VanguardConsoleMac"]),
        .library(name: "VanguardDomain", targets: ["VanguardDomain"]),
        .library(name: "VanguardProtocol", targets: ["VanguardProtocol"]),
        .library(name: "VanguardTransport", targets: ["VanguardTransport"]),
        .library(name: "VanguardDiscovery", targets: ["VanguardDiscovery"]),
        .library(name: "VanguardIdentity", targets: ["VanguardIdentity"]),
        .library(name: "VanguardSecurity", targets: ["VanguardSecurity"]),
        .library(name: "VanguardPermissions", targets: ["VanguardPermissions"]),
        .library(name: "VanguardCapture", targets: ["VanguardCapture"]),
        .library(name: "VanguardVideo", targets: ["VanguardVideo"]),
        .library(name: "VanguardInput", targets: ["VanguardInput"]),
        .library(name: "VanguardTerminal", targets: ["VanguardTerminal"]),
        .library(name: "VanguardClipboard", targets: ["VanguardClipboard"]),
        .library(name: "VanguardFiles", targets: ["VanguardFiles"]),
        .library(name: "VanguardAudio", targets: ["VanguardAudio"]),
        .library(name: "VanguardProcesses", targets: ["VanguardProcesses"]),
        .library(name: "VanguardTelemetry", targets: ["VanguardTelemetry"]),
        .library(name: "VanguardAudit", targets: ["VanguardAudit"]),
        .library(name: "VanguardPersistence", targets: ["VanguardPersistence"]),
        .library(name: "VanguardSession", targets: ["VanguardSession"]),
        .library(name: "VanguardRender", targets: ["VanguardRender"]),
        .library(name: "VanguardTestSupport", targets: ["VanguardTestSupport"]),
        .library(name: "VanguardUI", targets: ["VanguardUI"]),
        .library(name: "VanguardArtifacts", targets: ["VanguardArtifacts"]),
        .library(name: "VanguardCompute", targets: ["VanguardCompute"]),
        .library(name: "VanguardScheduler", targets: ["VanguardScheduler"]),
        .library(name: "VanguardWorkspace", targets: ["VanguardWorkspace"]),
        .library(name: "VanguardExecutors", targets: ["VanguardExecutors"]),
        .library(name: "VanguardAgents", targets: ["VanguardAgents"]),
        .library(name: "VanguardPolicy", targets: ["VanguardPolicy"]),
        .library(name: "VanguardObservability", targets: ["VanguardObservability"]),
        .library(name: "VanguardUpdates", targets: ["VanguardUpdates"]),
        .library(name: "CSystemMetrics", targets: ["CSystemMetrics"]),
    ],
    targets: [
        .target(
            name: "CSystemMetrics",
            path: "Packages/SystemMetrics/Sources/CSystemMetrics",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ]
        ),
        .target(
            name: "VanguardDomain",
            path: "Packages/VanguardDomain/Sources/VanguardDomain"
        ),
        .target(
            name: "VanguardProtocol",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardProtocol/Sources/VanguardProtocol"
        ),
        .target(
            name: "VanguardTransport",
            dependencies: ["VanguardDomain", "VanguardProtocol", "VanguardIdentity"],
            path: "Packages/VanguardTransport/Sources/VanguardTransport"
        ),
        .target(
            name: "VanguardDiscovery",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardDiscovery/Sources/VanguardDiscovery"
        ),
        .target(
            name: "VanguardIdentity",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardIdentity/Sources/VanguardIdentity"
        ),
        .target(
            name: "VanguardSecurity",
            dependencies: ["VanguardDomain", "VanguardIdentity", "VanguardProtocol"],
            path: "Packages/VanguardSecurity/Sources/VanguardSecurity"
        ),
        .target(
            name: "VanguardPermissions",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardPermissions/Sources/VanguardPermissions"
        ),
        .target(
            name: "VanguardCapture",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardCapture/Sources/VanguardCapture"
        ),
        .target(
            name: "VanguardVideo",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardVideo/Sources/VanguardVideo"
        ),
        .target(
            name: "VanguardInput",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardInput/Sources/VanguardInput"
        ),
        .target(
            name: "VanguardTerminal",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardTerminal/Sources/VanguardTerminal"
        ),
        .target(
            name: "VanguardClipboard",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardClipboard/Sources/VanguardClipboard"
        ),
        .target(
            name: "VanguardFiles",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardFiles/Sources/VanguardFiles"
        ),
        .target(
            name: "VanguardAudio",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardAudio/Sources/VanguardAudio",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
            ]
        ),
        .target(
            name: "VanguardProcesses",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardProcesses/Sources/VanguardProcesses"
        ),
        .target(
            name: "VanguardTelemetry",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardTelemetry/Sources/VanguardTelemetry"
        ),
        .target(
            name: "VanguardAudit",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardAudit/Sources/VanguardAudit"
        ),
        .target(
            name: "VanguardPersistence",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardPersistence/Sources/VanguardPersistence"
        ),
        .testTarget(
            name: "VanguardSessionTests",
            dependencies: [
                "VanguardSession",
                "VanguardDomain",
                "VanguardProtocol",
                "VanguardTransport",
                "VanguardDiscovery",
                "VanguardIdentity",
                "VanguardPermissions",
                "VanguardCapture",
                "VanguardVideo",
                "VanguardInput",
                "VanguardTerminal",
            ],
            path: "Packages/VanguardSession/Tests"
        ),
        .target(
            name: "VanguardSession",
            dependencies: [
                "VanguardDomain",
                "VanguardProtocol",
                "VanguardTransport",
                "VanguardDiscovery",
                "VanguardIdentity",
                "VanguardPermissions",
                "VanguardCapture",
                "VanguardVideo",
                "VanguardInput",
                "VanguardTerminal",
                "VanguardRender",
                "VanguardSecurity",
                "VanguardAudit",
            ],
            path: "Packages/VanguardSession/Sources/VanguardSession"
        ),
        .target(
            name: "VanguardRender",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardRender/Sources/VanguardRender"
        ),
        .target(
            name: "VanguardUI",
            path: "Packages/VanguardUI/Sources/VanguardUI"
        ),
        .target(
            name: "VanguardTestSupport",
            dependencies: [
                "VanguardDomain",
                "VanguardProtocol",
                "VanguardTransport",
                "VanguardIdentity",
                "VanguardSecurity",
                "VanguardPermissions",
            ],
            path: "Packages/VanguardTestSupport/Sources/VanguardTestSupport"
        ),
        .target(
            name: "VanguardArtifacts",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardArtifacts/Sources/VanguardArtifacts"
        ),
        .testTarget(
            name: "VanguardArtifactsTests",
            dependencies: ["VanguardArtifacts", "VanguardTestSupport"],
            path: "Packages/VanguardArtifacts/Tests"
        ),
        .target(
            name: "VanguardCompute",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardCompute/Sources/VanguardCompute"
        ),
        .testTarget(
            name: "VanguardComputeTests",
            dependencies: ["VanguardCompute", "VanguardTestSupport"],
            path: "Packages/VanguardCompute/Tests"
        ),
        .target(
            name: "VanguardScheduler",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardScheduler/Sources/VanguardScheduler"
        ),
        .testTarget(
            name: "VanguardSchedulerTests",
            dependencies: ["VanguardScheduler", "VanguardTestSupport"],
            path: "Packages/VanguardScheduler/Tests"
        ),
        .target(
            name: "VanguardWorkspace",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardWorkspace/Sources/VanguardWorkspace"
        ),
        .testTarget(
            name: "VanguardWorkspaceTests",
            dependencies: ["VanguardWorkspace", "VanguardTestSupport"],
            path: "Packages/VanguardWorkspace/Tests"
        ),
        .target(
            name: "VanguardExecutors",
            dependencies: ["VanguardDomain", "VanguardCompute"],
            path: "Packages/VanguardExecutors/Sources/VanguardExecutors"
        ),
        .target(
            name: "VanguardAgents",
            dependencies: ["VanguardDomain", "VanguardCompute"],
            path: "Packages/VanguardAgents/Sources/VanguardAgents"
        ),
        .testTarget(
            name: "VanguardAgentsTests",
            dependencies: ["VanguardAgents", "VanguardTestSupport"],
            path: "Packages/VanguardAgents/Tests"
        ),
        .target(
            name: "VanguardPolicy",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardPolicy/Sources/VanguardPolicy"
        ),
        .target(
            name: "VanguardObservability",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardObservability/Sources/VanguardObservability"
        ),
        .testTarget(
            name: "VanguardObservabilityTests",
            dependencies: ["VanguardObservability", "VanguardTestSupport"],
            path: "Packages/VanguardObservability/Tests"
        ),
        .target(
            name: "VanguardUpdates",
            dependencies: ["VanguardDomain"],
            path: "Packages/VanguardUpdates/Sources/VanguardUpdates"
        ),
        .testTarget(
            name: "VanguardUpdatesTests",
            dependencies: ["VanguardUpdates", "VanguardTestSupport"],
            path: "Packages/VanguardUpdates/Tests"
        ),

        // Tests
        .testTarget(
            name: "VanguardDomainTests",
            dependencies: ["VanguardDomain", "VanguardTestSupport"],
            path: "Packages/VanguardDomain/Tests"
        ),
        .testTarget(
            name: "VanguardProtocolTests",
            dependencies: ["VanguardProtocol", "VanguardTestSupport"],
            path: "Packages/VanguardProtocol/Tests"
        ),
        .testTarget(
            name: "VanguardTransportTests",
            dependencies: ["VanguardTransport", "VanguardTestSupport"],
            path: "Packages/VanguardTransport/Tests"
        ),
        .testTarget(
            name: "VanguardDiscoveryTests",
            dependencies: ["VanguardDiscovery", "VanguardTestSupport"],
            path: "Packages/VanguardDiscovery/Tests"
        ),
        .testTarget(
            name: "VanguardIdentityTests",
            dependencies: ["VanguardIdentity", "VanguardTestSupport"],
            path: "Packages/VanguardIdentity/Tests"
        ),
        .testTarget(
            name: "VanguardSecurityTests",
            dependencies: ["VanguardSecurity", "VanguardTestSupport"],
            path: "Packages/VanguardSecurity/Tests"
        ),
        .testTarget(
            name: "VanguardPermissionsTests",
            dependencies: ["VanguardPermissions", "VanguardTestSupport"],
            path: "Packages/VanguardPermissions/Tests"
        ),
        .testTarget(
            name: "VanguardCaptureTests",
            dependencies: ["VanguardCapture", "VanguardTestSupport"],
            path: "Packages/VanguardCapture/Tests"
        ),
        .testTarget(
            name: "VanguardVideoTests",
            dependencies: ["VanguardVideo", "VanguardTestSupport"],
            path: "Packages/VanguardVideo/Tests"
        ),
        .testTarget(
            name: "VanguardInputTests",
            dependencies: ["VanguardInput", "VanguardTestSupport"],
            path: "Packages/VanguardInput/Tests"
        ),
        .testTarget(
            name: "VanguardTerminalTests",
            dependencies: ["VanguardTerminal", "VanguardTestSupport"],
            path: "Packages/VanguardTerminal/Tests"
        ),
        .testTarget(
            name: "VanguardProcessesTests",
            dependencies: ["VanguardProcesses", "VanguardTestSupport"],
            path: "Packages/VanguardProcesses/Tests"
        ),
        .testTarget(
            name: "VanguardTelemetryTests",
            dependencies: ["VanguardTelemetry", "VanguardTestSupport"],
            path: "Packages/VanguardTelemetry/Tests"
        ),
        .testTarget(
            name: "VanguardAuditTests",
            dependencies: ["VanguardAudit", "VanguardTestSupport"],
            path: "Packages/VanguardAudit/Tests"
        ),
        .testTarget(
            name: "VanguardPersistenceTests",
            dependencies: ["VanguardPersistence", "VanguardTestSupport"],
            path: "Packages/VanguardPersistence/Tests"
        ),
        .testTarget(
            name: "VanguardFilesTests",
            dependencies: ["VanguardFiles", "VanguardTestSupport"],
            path: "Packages/VanguardFiles/Tests"
        ),

        // MARK: - App Targets

        .executableTarget(
            name: "VanguardNodeMac",
            dependencies: [
                "VanguardDomain",
                "VanguardSession",
                "VanguardDiscovery",
                "VanguardTransport",
                "VanguardIdentity",
                "VanguardPermissions",
                "VanguardCapture",
                "VanguardVideo",
                "VanguardInput",
                "VanguardTerminal",
                "VanguardUI",
                "VanguardClipboard",
                "VanguardSecurity",
                "VanguardAudit",
                "VanguardTelemetry",
            ],
            path: "Apps/VanguardNodeMac/Sources/VanguardNodeMac",
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("Network"),
                .linkedFramework("CryptoKit"),
            ]
        ),
        .executableTarget(
            name: "VanguardConsoleMac",
            dependencies: [
                "VanguardDomain",
                "VanguardProtocol",
                "VanguardSession",
                "VanguardDiscovery",
                "VanguardTransport",
                "VanguardIdentity",
                "VanguardPermissions",
                "VanguardVideo",
                "VanguardInput",
                "VanguardTerminal",
                "VanguardRender",
                "VanguardUI",
                "VanguardClipboard",
                "VanguardSecurity",
                "VanguardAudit",
                "VanguardScheduler",
                "VanguardCompute",
                "VanguardWorkspace",
                "VanguardObservability",
                "VanguardAgents",
                "VanguardPolicy",
                "VanguardFiles",
                "CSystemMetrics",
            ],
            path: "Apps/VanguardConsoleMac/Sources/VanguardConsoleMac",
            linkerSettings: [
                .linkedFramework("Network"),
                .linkedFramework("CryptoKit"),
            ]
        ),
    ]
)
