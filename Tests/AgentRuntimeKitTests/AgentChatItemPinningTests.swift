import XCTest
@testable import AgentRuntimeKit

/// Pins the persisted chat-item contract at promotion time (2026-07-16).
///
/// These raw values and the legacy-decode defaulting are written into every saved
/// agent session. Renaming a case, or changing which keys are required vs defaulted,
/// is a data migration — this suite freezes the current on-disk contract.
final class AgentChatItemPinningTests: XCTestCase {
	func testChatItemKindRawValuesArePinned() {
		// AgentChatItemKind is not CaseIterable in source; enumerate every declared
		// case in declaration order. Raw values equal the case names.
		XCTAssertEqual(AgentChatItemKind.user.rawValue, "user")
		XCTAssertEqual(AgentChatItemKind.assistant.rawValue, "assistant")
		XCTAssertEqual(AgentChatItemKind.assistantInline.rawValue, "assistantInline")
		XCTAssertEqual(AgentChatItemKind.toolCall.rawValue, "toolCall")
		XCTAssertEqual(AgentChatItemKind.toolResult.rawValue, "toolResult")
		XCTAssertEqual(AgentChatItemKind.system.rawValue, "system")
		XCTAssertEqual(AgentChatItemKind.error.rawValue, "error")
		XCTAssertEqual(AgentChatItemKind.thinking.rawValue, "thinking")

		// Round-trip every raw value back to its case to pin the decode side too.
		XCTAssertEqual(AgentChatItemKind(rawValue: "user"), .user)
		XCTAssertEqual(AgentChatItemKind(rawValue: "assistant"), .assistant)
		XCTAssertEqual(AgentChatItemKind(rawValue: "assistantInline"), .assistantInline)
		XCTAssertEqual(AgentChatItemKind(rawValue: "toolCall"), .toolCall)
		XCTAssertEqual(AgentChatItemKind(rawValue: "toolResult"), .toolResult)
		XCTAssertEqual(AgentChatItemKind(rawValue: "system"), .system)
		XCTAssertEqual(AgentChatItemKind(rawValue: "error"), .error)
		XCTAssertEqual(AgentChatItemKind(rawValue: "thinking"), .thinking)
	}

	func testCodexGoalModeActionRawValuesArePinned() {
		// Action is not CaseIterable in source; pin the ordered case list via a
		// literal array (do not add CaseIterable to the moved type).
		let orderedActions: [AgentCodexGoalModeMetadata.Action] = [
			.setObjective, .show, .pause, .resume, .clear
		]
		XCTAssertEqual(
			orderedActions.map(\.rawValue),
			["setObjective", "show", "pause", "resume", "clear"]
		)
	}

	func testChatItemDecodesLegacyPayloadWithDefaults() throws {
		// Minimal legacy shape: the custom init(from:) requires id/timestamp/kind/
		// text/sequenceIndex (decode) and defaults every other key (decodeIfPresent).
		// A bare JSONDecoder uses .deferredToDate, so timestamp is a numeric interval.
		let json = """
		{"id":"33333333-3333-3333-3333-333333333333","timestamp":0,"kind":"user","text":"hi","sequenceIndex":1}
		"""
		let item = try JSONDecoder().decode(AgentChatItem.self, from: Data(json.utf8))

		// Required fields decoded.
		XCTAssertEqual(item.id, UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
		XCTAssertEqual(item.timestamp, Date(timeIntervalSinceReferenceDate: 0))
		XCTAssertEqual(item.kind, .user)
		XCTAssertEqual(item.text, "hi")
		XCTAssertEqual(item.sequenceIndex, 1)

		// Defaulted optional collections / flags / nested types.
		XCTAssertTrue(item.attachments.isEmpty)
		XCTAssertTrue(item.taggedFileAttachments.isEmpty)
		XCTAssertNil(item.toolName)
		XCTAssertNil(item.toolInvocationID)
		XCTAssertNil(item.toolArgsJSON)
		XCTAssertNil(item.toolResultJSON)
		XCTAssertNil(item.toolIsError)
		XCTAssertNil(item.reasoning)
		XCTAssertFalse(item.isStreaming)
		XCTAssertNil(item.workflow)
		XCTAssertNil(item.codexGoalMode)
		XCTAssertFalse(item.isLocalControlPlaneEcho)
	}

	func testChatItemPersistDecodesLegacyPayloadWithDefaults() throws {
		// AgentChatItemPersist's persisted shape decodes with the same required-key set
		// as AgentChatItem (id/timestamp/kind/text/sequenceIndex) plus defaulted optionals,
		// including the persist-only toolResultStatus (nil when absent).
		let json = """
		{"id":"44444444-4444-4444-4444-444444444444","timestamp":0,"kind":"assistant","text":"hey","sequenceIndex":2}
		"""
		let persist = try JSONDecoder().decode(AgentChatItemPersist.self, from: Data(json.utf8))

		XCTAssertEqual(persist.id, UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
		XCTAssertEqual(persist.kind, .assistant)
		XCTAssertEqual(persist.text, "hey")
		XCTAssertEqual(persist.sequenceIndex, 2)
		XCTAssertTrue(persist.attachments.isEmpty)
		XCTAssertTrue(persist.taggedFileAttachments.isEmpty)
		XCTAssertNil(persist.toolResultStatus)
		XCTAssertNil(persist.workflow)
		XCTAssertNil(persist.codexGoalMode)
		XCTAssertFalse(persist.isLocalControlPlaneEcho)
	}
}
