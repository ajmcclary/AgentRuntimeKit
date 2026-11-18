# AgentRuntimeKit

Provider-neutral vocabulary for coding-agent sessions: the values and pure policies every agent
layer above it shares.

An app that drives several coding agents (Codex, Claude Code, OpenCode, ACP agents, ...) needs
one way to talk about a session, a transcript turn, an approval prompt, or a model selection,
independent of which provider produced it. AgentRuntimeKit is that common language. It is pure
value types plus caseless policy namespaces, with no I/O and no provider transport, and it is
the base of the agent package stack: CodexRuntimeKit, CodexAppServerKit and AgentExecutionKit
all depend on it.

## What's inside

- **Sessions and run state** — `AgentSessionRunState` (`idle` ... `waitingForApproval` ...
  `failed`, with `isActive`), `AgentSessionIndexEntry`, `AgentSessionMeta`,
  `AgentSessionDataError`, `AgentContextUsage`.
- **Transcripts** — `AgentTranscript` / `AgentTranscriptTurn` / `AgentTranscriptActivity` with
  retention tiers and a compaction frontier (`AgentTranscriptCompactionFrontier`,
  `AgentTranscriptDurableFrontierSupport`, `AgentTranscriptCompactionMode`);
  `AgentTranscriptImportPolicy`; `AgentTranscriptTextExtraction` for preview and error text;
  the flat `AgentChatItem` / `AgentChatItemPersist` row model.
- **User interaction** — `AgentApprovalRequest` + `AgentApprovalDecision`,
  `AgentPermissionsRequest`, `AgentMCPElicitationRequest`, `AgentAskUserInteraction` (with
  validation via `AgentAskUserValidationError`), `AgentRequestUserInputRequest`, and the
  `UserQuestionResponse` / `UserInstructionResponse` answers. Request IDs are derived
  deterministically (SHA-256) from request content, so a replayed request keeps its identity.
- **Identity** — `AgentModelSelectionID` (`<agent>:<model>`, trapping and non-trapping
  constructors plus `parse`), `AgentProviderBindingID`, and `CodexAppServerRequestID`, which
  lives here because neutral approval values carry it.
- **Attachments and workflows** — `AgentImageAttachment`, `AgentTaggedFileAttachment`,
  `AgentWorkflow` (built-in templates) and `AgentWorkflowDefinition` (built-in or custom).
- **Turn-preparation policies** — `SlashSkillTokenizer`, `AgentTaggedPathParser` (`@path`
  mentions), `AgentTurnMessageComposition` (initial-thread and session-handoff payloads),
  `PendingSlashSkillInvocationEnvelopeCodec`.
- **Utilities** — `PerKeyTaskStore` (a `@MainActor` per-key `Task` registry whose removal tokens
  stop a stale worker from evicting its replacement).

### Provider-specific names in a neutral package

A few names here mention a provider or the original app. They are deliberate:

- `AgentApprovalRequestID` has `.codex`, `.claudeControl` and `.acp` cases. It is a routing
  tag: a neutral approval request must carry the provider's own request ID so the reply
  reaches the right transport. `CodexAppServerRequestID` lives here for the same reason, and
  because CodexAppServerKit needs it without depending on CodexRuntimeKit.
- `PendingSlashSkillInvocationEnvelopeCodec.prefix` (`{{REPOPROMPT_PENDING_SLASH_SKILL_BASE64:`)
  is a marker embedded in message text. Renaming it would stop existing envelopes from
  decoding, so it stays as is.

## When to use it

- You are building an agent host or an agent-layer package and need shared session, transcript,
  approval, or model-selection types that are not tied to one provider.
- You want deterministic, testable turn-preparation logic (slash skills, `@path` tags, handoff
  payloads) without pulling in a runtime.
- You persist transcripts or session indexes and want `Codable` value types with stable raw
  values.

## When not to use it

- **Provider-specific semantics** (event interpretation, compatibility manifests, admission,
  protocol locks): use CodexRuntimeKit, ClaudeRuntimeKit, or OpenCodeRuntimeKit.
- **Talking to the Codex app-server over JSON-RPC:** use CodexAppServerKit.
- **Actually running agents** — launching providers, session storage, transcript projection and
  persistence: use AgentExecutionKit, which builds on this package.
- Out of scope here: UI and SwiftUI/AppKit projection, provider transports, JSON-RPC, CLI launch,
  authentication, admission policy, process ownership, workspace mutation, persistence backends,
  and app settings.

## Installation

```swift
dependencies: [
    // 0.1.0-beta.4 is a prerelease identifier — SwiftPM only resolves
    // prerelease tags when the lower bound itself names one.
    .package(url: "https://github.com/ajmcclary/AgentRuntimeKit.git", .upToNextMinor(from: "0.1.0-beta.4"))
]
```

```swift
.target(
    name: "YourTarget",
    dependencies: [.product(name: "AgentRuntimeKit", package: "AgentRuntimeKit")]
)
```

## Usage

```swift
import Foundation
import AgentRuntimeKit

// Model selections that arrive from outside the process: parse, never trap.
let selection = AgentModelSelectionID.parse("claudeCode:opus[1m]")
print(selection?.agentRaw ?? "-", selection?.modelRaw ?? "-")   // claudeCode opus[1m]

// Turn preparation: a leading slash skill and @-tagged workspace paths.
let input = "/review @Sources/App.swift focus on error handling"
if let skill = SlashSkillTokenizer.extractTokens(from: input).first {
    let args = (input as NSString).substring(with: skill.argumentsRange)
    print(skill.name)                                                // review
    print(AgentTurnMessageComposition.renderSlashSkillUserInstructions(args))
}
print(AgentTaggedPathParser.extractTaggedPaths(from: input))     // ["Sources/App.swift"]

// An approval request gets a stable, content-derived identity.
let request = AgentApprovalRequest(
    requestID: .claudeControl("req-1"),
    method: "can_use_tool",
    kind: .commandExecution,
    threadID: "thread-1", turnID: "turn-1", itemID: "item-1",
    command: "swift test"
)
print(request.title)                                             // Command Approval

// Run state drives what the host shows.
let state: AgentSessionRunState = .waitingForApproval
print(state.isActive)                                            // true
```

## Requirements

- Swift tools 6.0, Swift 6 language mode with strict concurrency.
- macOS 27.0 / iOS 27.0.
- Dependencies: none. Uses Foundation and the CryptoKit system framework (for stable
  interaction IDs), so build with an Apple toolchain (Xcode); an open-source toolchain without
  CryptoKit will not compile it.

## Stability

Pre-1.0 (`0.1.0-beta.x`): the public API may change between minor versions, so pin with
`.upToNextMinor`.

## Development

```sh
swift build
swift test   # fast; pure value types and policies
```

## Origin

Extracted from the RepoPrompt app.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
