import XCTest
import AgentRuntimeKit

/// Public-API boundary contract for AgentRuntimeKit (the first migrate.md
/// extraction). The deep behavior pins live in the per-family suites that
/// moved with the code; this file pins two things those suites cannot:
/// (1) every vocabulary family RepoPrompt consumes stays PUBLIC — this file
/// deliberately imports WITHOUT `@testable`, so any accidental
/// de-publicizing breaks compilation — and (2) the identifier/raw-value
/// formats that cross the package boundary as persisted or wire identity.
final class AgentRuntimeKitPublicAPIContractTests: XCTestCase {
	// Compile-time public-visibility pins, one alias per vocabulary family.
	// A tuple type references each member type without needing constructible
	// values; removal or de-publicizing of any member is a compile error.
	private typealias SessionFamily = (AgentSessionRunState, AgentSessionMeta, AgentSessionDataError, AgentSessionIndexEntry, AgentContextUsage)
	private typealias TranscriptFamily = (AgentTranscript, AgentTranscriptTurn, AgentTranscriptActivity, AgentTranscriptToolExecution, AgentTranscriptCompactionFrontier, AgentTranscriptCompactionMode, AgentTranscriptImportPolicy)
	private typealias ChatFamily = (AgentChatItem, AgentChatItemPersist, AgentDisplayableText, AgentChatItemKind)
	private typealias AttachmentFamily = (AgentImageAttachment, AgentImageSource, AgentTaggedFileAttachment)
	private typealias ApprovalFamily = (AgentApprovalRequest, AgentApprovalDecision, AgentApprovalKind, AgentPermissionsRequest, AgentMCPElicitationRequest)
	private typealias InteractionFamily = (AgentAskUserInteraction, AgentAskUserQuestion, AgentAskUserResponse, AgentRequestUserInputRequest, AgentRequestUserInputResponse, UserQuestionResponse, UserInstructionResponse)
	private typealias WorkflowFamily = (AgentWorkflow, AgentWorkflowDefinition)
	private typealias IdentifierFamily = (AgentModelSelectionID, AgentProviderBindingID, AgentApprovalRequestID, CodexAppServerRequestID)
	private typealias PolicyFamily = (AgentTaggedPathParser, AgentTurnMessageComposition, AgentTranscriptTextExtraction, AgentTranscriptDurableFrontierSupport, SlashSkillTokenizer, PendingSlashSkillInvocationEnvelope, ClaudeAbortArtifactFilter, PerKeyTaskStore<String>)

	func testRunStateRawIdentitySurvivesCodableRoundTrip() throws {
		// AgentSessionRunState raw strings are persisted session identity.
		let states: [AgentSessionRunState] = [.idle, .waitingForApproval, .failed]
		let encoded = try JSONEncoder().encode(states)
		XCTAssertEqual(
			String(data: encoded, encoding: .utf8),
			"[\"idle\",\"waitingForApproval\",\"failed\"]"
		)
		XCTAssertEqual(try JSONDecoder().decode([AgentSessionRunState].self, from: encoded), states)
	}

	func testModelSelectionIDFormatContract() {
		// model_id crosses the MCP boundary: `<agentRaw>:<modelRaw>`, first
		// colon delimits, model raw may itself contain colons.
		let parsed = AgentModelSelectionID.parse("claudeCode:opus[1m]")
		XCTAssertEqual(parsed?.agentRaw, "claudeCode")
		XCTAssertEqual(parsed?.modelRaw, "opus[1m]")
		XCTAssertEqual(parsed?.rawValue, "claudeCode:opus[1m]")

		let colonModel = AgentModelSelectionID.parse("codexExec:profile:high")
		XCTAssertEqual(colonModel?.agentRaw, "codexExec")
		XCTAssertEqual(colonModel?.modelRaw, "profile:high")

		// Legacy versioned format stays accepted for backward compatibility.
		let legacy = AgentModelSelectionID.parse("agent-selection:v1:codexExec:default")
		XCTAssertEqual(legacy?.rawValue, "codexExec:default")

		XCTAssertNil(AgentModelSelectionID.parse("no-delimiter"))
		XCTAssertNil(AgentModelSelectionID.parse("   "))
	}

	func testProviderBindingRawValuesArePinned() {
		// Raw values are provider-binding identity; renaming a case is a
		// data migration for anything that persisted one.
		XCTAssertEqual(
			AgentProviderBindingID.allCases.map(\.rawValue),
			["codex", "claude", "gemini", "openCode", "cursor"]
		)
	}

	func testSlashSkillTokenizerLeadingSlashContract() {
		let tokens = SlashSkillTokenizer.extractTokens(from: "  /graphify some args")
		XCTAssertEqual(tokens.count, 1)
		XCTAssertEqual(tokens.first?.name, "graphify")
		// A slash that is not the first non-whitespace character never tokenizes.
		XCTAssertEqual(SlashSkillTokenizer.extractTokens(from: "path /not-a-skill"), [])
	}
}
