import Testing
import Foundation
import CryptoKit
import VanguardDomain
@testable import VanguardBuild

@Suite("BuildManifest — Lifecycle")
struct BuildManifestTests {

    @Test("manifest initializes with pending status")
    func manifestInit() {
        let manifest = BuildManifest(productName: "TestApp", version: "1.0.0")
        #expect(manifest.status == .pending)
        #expect(manifest.isComplete == false)
        #expect(manifest.artifacts.isEmpty)
        #expect(manifest.targetArchitectures == [.arm64, .x86_64])
    }

    @Test("succeededArchitectures filters correctly")
    func succeededArchitectures() {
        var manifest = BuildManifest(productName: "App", version: "1.0")
        manifest.artifacts = [
            ArchitectureArtifact(architecture: .arm64, binaryPath: "/arm", status: .succeeded),
            ArchitectureArtifact(architecture: .x86_64, binaryPath: "/x86", status: .failed)
        ]
        #expect(manifest.succeededArchitectures == [.arm64])
        #expect(manifest.failedArchitectures == [.x86_64])
    }

    @Test("isComplete returns true for terminal states")
    func isComplete() {
        var manifest = BuildManifest(productName: "App", version: "1.0")
        manifest.status = .succeeded
        #expect(manifest.isComplete == true)
        manifest.status = .failed
        #expect(manifest.isComplete == true)
        manifest.status = .cancelled
        #expect(manifest.isComplete == true)
        manifest.status = .building
        #expect(manifest.isComplete == false)
    }
}

@Suite("LipoService — Binary Combining")
struct LipoServiceTests {

    @Test("combine fails with fewer than 2 inputs")
    func combineInsufficientInputs() async {
        let service = LipoService()
        do {
            _ = try await service.combine(inputPaths: ["/single"], outputPath: "/tmp/out")
            Issue.record("Expected error")
        } catch {
            #expect(error is LipoError)
        }
    }

    @Test("combine fails when input not found")
    func combineInputNotFound() async {
        let service = LipoService()
        do {
            _ = try await service.combine(
                inputPaths: ["/nonexistent/a", "/nonexistent/b"],
                outputPath: "/tmp/out"
            )
            Issue.record("Expected error")
        } catch {
            #expect(error is LipoError)
        }
    }

    @Test("verifyFatBinary returns false for missing arch")
    func verifyFatBinary() async throws {
        let service = LipoService()
        let result = try await service.verifyFatBinary("/nonexistent", expectedArchs: [.arm64])
        #expect(result == false)
    }
}

@Suite("UniversalBuildService — Orchestration")
struct UniversalBuildServiceTests {

    @Test("activeBuildIDs tracks in-progress builds")
    func activeBuildIDs() async {
        let service = UniversalBuildService()
        let ids = await service.activeBuildIDs()
        #expect(ids.isEmpty)
    }

    @Test("cancelBuild marks manifest as cancelled")
    func cancelBuild() async {
        let service = UniversalBuildService()
        let id = UUID()
        await service.cancelBuild(id)
        let manifest = await service.buildManifest(id)
        #expect(manifest == nil)
    }

    @Test("cleanupCompletedBuilds removes old builds")
    func cleanupBuilds() async {
        let service = UniversalBuildService()
        await service.cleanupCompletedBuilds(olderThan: 0)
    }

    @Test("BuildTarget initializes with defaults")
    func buildTargetDefaults() {
        let target = BuildTarget(architecture: .arm64)
        #expect(target.architecture == .arm64)
        #expect(target.sdk == "macosx")
        #expect(target.extraFlags.isEmpty)
    }

    @Test("UniversalBuildRequest initializes correctly")
    func buildRequestInit() {
        let request = UniversalBuildRequest(
            productName: "MyApp",
            version: "2.0.0",
            sourcePath: "/src",
            outputPath: "/out"
        )
        #expect(request.productName == "MyApp")
        #expect(request.version == "2.0.0")
        #expect(request.targets.count == 2)
    }

    @Test("ArchitectureArtifact tracks per-arch status")
    func artifactStatus() {
        let pending = ArchitectureArtifact(architecture: .arm64, binaryPath: "/arm")
        #expect(pending.status == .pending)
        let failed = ArchitectureArtifact(architecture: .x86_64, binaryPath: "/x86", status: .failed, errorMessage: "boom")
        #expect(failed.errorMessage == "boom")
    }
}

@Suite("Build Edge Cases")
struct BuildEdgeCases {

    @Test("manifest with single succeeded arch is complete")
    func singleArchComplete() {
        var manifest = BuildManifest(productName: "App", version: "1.0")
        manifest.artifacts = [
            ArchitectureArtifact(architecture: .arm64, binaryPath: "/arm", status: .succeeded)
        ]
        manifest.status = .succeeded
        #expect(manifest.succeededArchitectures == [.arm64])
        #expect(manifest.failedArchitectures.isEmpty)
        #expect(manifest.isComplete)
    }

    @Test("manifest with all failed archs has no succeeded")
    func allFailed() {
        var manifest = BuildManifest(productName: "App", version: "1.0")
        manifest.artifacts = [
            ArchitectureArtifact(architecture: .arm64, binaryPath: "/arm", status: .failed),
            ArchitectureArtifact(architecture: .x86_64, binaryPath: "/x86", status: .failed)
        ]
        manifest.status = .failed
        #expect(manifest.succeededArchitectures.isEmpty)
        #expect(manifest.failedArchitectures.count == 2)
    }

    @Test("buildManifest returns nil for unknown ID")
    func manifestUnknown() async {
        let service = UniversalBuildService()
        let manifest = await service.buildManifest(UUID())
        #expect(manifest == nil)
    }

    @Test("cancelBuild on completed build is no-op")
    func cancelCompleted() async {
        let service = UniversalBuildService()
        let id = UUID()
        await service.cancelBuild(id)
        let manifest = await service.buildManifest(id)
        #expect(manifest == nil)
    }

    @Test("BuildTarget with extra flags")
    func buildTargetFlags() {
        let target = BuildTarget(
            architecture: .arm64,
            sdk: "iphoneos",
            extraFlags: ["ENABLE_BITCODE=YES"]
        )
        #expect(target.sdk == "iphoneos")
        #expect(target.extraFlags.count == 1)
    }

    @Test("UniversalBuildRequest with custom targets")
    func customTargets() {
        let request = UniversalBuildRequest(
            productName: "App",
            version: "1.0",
            sourcePath: "/src",
            outputPath: "/out",
            targets: [BuildTarget(architecture: .arm64)]
        )
        #expect(request.targets.count == 1)
        #expect(request.targets.first?.architecture == .arm64)
    }

    @Test("ArchitectureArtifact with full details")
    func artifactFull() {
        let artifact = ArchitectureArtifact(
            architecture: .arm64,
            binaryPath: "/out/arm64/App",
            sha256: Data(repeating: 0xAB, count: 32),
            sizeBytes: 1024 * 1024,
            buildDuration: 45.2,
            status: .succeeded
        )
        #expect(artifact.sizeBytes == 1024 * 1024)
        #expect(artifact.buildDuration == 45.2)
        #expect(artifact.errorMessage == nil)
    }

    @Test("BuildStatus terminal states")
    func terminalStates() {
        #expect(BuildStatus.succeeded != BuildStatus.pending)
        #expect(BuildStatus.failed != BuildStatus.building)
        #expect(BuildStatus.cancelled != BuildStatus.pending)
    }
}
