// swift-tools-version: 6.0
import PackageDescription

// AgentRuntimeKit — provider-neutral agent-domain vocabulary.
//
// Promoted verbatim out of RepoPrompt's internal RepoPromptCore package
// (its AgentRuntimeCore target) as the first extraction of the migrate.md
// package map. RepoPromptCore's AgentRuntimeCore target is now an
// @_exported re-export shim over this package (the WorkspacePaths →
// WorkspacePathsCore promotion precedent).
//
// Scope: session, transcript, attachment, approval, model-selection,
// workflow, and run-state values; stable identifiers and user-interaction
// request/response models; pure transcript parsing, compaction, and
// tokenization policies. Deliberately OUT of scope: SwiftUI/AppKit and UI
// projection, provider transports, JSON-RPC, CLI launch, authentication,
// admission policy, process ownership, workspace mutation, persistence
// backends, app settings/coordinators, and provider-specific semantics
// (Codex/Claude/OpenCode/ACP layers sit above this package).
//
// Zero package dependencies (Foundation plus the CryptoKit system
// framework for SHA-256 stable-interaction identities). Swift 5 language
// mode keeps the moved code byte-behaviorally identical (RepoPromptCore /
// WorkspaceKit promoted-target precedent).
let package = Package(
    name: "AgentRuntimeKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "AgentRuntimeKit", targets: ["AgentRuntimeKit"])
    ],
    targets: [
        .target(
            name: "AgentRuntimeKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AgentRuntimeKitTests",
            dependencies: ["AgentRuntimeKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
