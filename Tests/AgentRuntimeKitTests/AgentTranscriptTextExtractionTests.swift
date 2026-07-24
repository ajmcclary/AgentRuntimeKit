import XCTest
@testable import AgentRuntimeKit

/// Behavior pins for the transcript text-extraction tranche promoted into
/// AgentRuntimeCore (2026-07-16): `AgentTranscriptTextExtraction` preview/error
/// extractors and `AgentTranscriptDurableFrontierSupport`. Transcripts are built
/// only through real public API; literals are frozen from actual move-time behavior.
final class AgentTranscriptTextExtractionTests: XCTestCase {

	// MARK: - Builders (public API only)

	private func activity(
		_ kind: AgentChatItemKind,
		_ text: String,
		sequence: Int,
		id: UUID = UUID()
	) -> AgentTranscriptActivity {
		let role: AgentTranscriptActivityRole
		switch kind {
		case .assistant, .assistantInline: role = .assistant
		case .error: role = .error
		default: role = .note
		}
		return AgentTranscriptActivity(
			id: id,
			timestamp: Date(timeIntervalSinceReferenceDate: Double(sequence)),
			sequenceIndex: sequence,
			role: role,
			itemKind: kind,
			text: text
		)
	}

	private func turn(
		id: UUID = UUID(),
		activities: [AgentTranscriptActivity],
		retentionTier: AgentTranscriptRetentionTier = .full
	) -> AgentTranscriptTurn {
		let span = AgentTranscriptProviderResponseSpan(
			lifecycle: .completed,
			startedAt: Date(timeIntervalSinceReferenceDate: 0),
			activities: activities
		)
		return AgentTranscriptTurn(
			id: id,
			responseSpans: [span],
			retentionTier: retentionTier,
			startedAt: Date(timeIntervalSinceReferenceDate: 0)
		)
	}

	private func transcript(_ turns: [AgentTranscriptTurn]) -> AgentTranscript {
		var t = AgentTranscript()
		t.turns = turns
		return t
	}

	// MARK: - (a) latestAssistantPreviewText(from:)

	func testLatestAssistantPreviewTextReturnsLatestSubstantiveAssistantAndTrims() {
		// Turn 2's most-recent assistant body is whitespace-only (non-displayable) and
		// must be skipped; the extractor falls back to the prior substantive body and trims it.
		let turn1 = turn(activities: [
			activity(.assistant, "first turn answer", sequence: 1)
		])
		let turn2 = turn(activities: [
			activity(.assistant, "  final answer  ", sequence: 2),
			activity(.assistant, "   \n  ", sequence: 3) // non-displayable, ignored
		])

		let preview = AgentTranscriptTextExtraction.latestAssistantPreviewText(
			from: transcript([turn1, turn2])
		)
		XCTAssertEqual(preview, "final answer")
	}

	func testLatestAssistantPreviewTextReturnsNilWhenNoDisplayableAssistantBodies() {
		let onlyBlank = turn(activities: [
			activity(.assistant, "   ", sequence: 1),
			activity(.error, "boom", sequence: 2)
		])
		XCTAssertNil(
			AgentTranscriptTextExtraction.latestAssistantPreviewText(from: transcript([onlyBlank]))
		)
	}

	// MARK: - (b) latestErrorText(from:latestTurnOnly:)

	func testLatestErrorTextRespectsLatestTurnOnlyFlag() {
		// Error lives in the EARLIER turn; the latest turn has no error.
		let errorTurn = turn(activities: [
			activity(.assistant, "working on it", sequence: 1),
			activity(.error, "  disk full  ", sequence: 2)
		])
		let cleanTurn = turn(activities: [
			activity(.assistant, "done", sequence: 3)
		])
		let t = transcript([errorTurn, cleanTurn])

		XCTAssertNil(
			AgentTranscriptTextExtraction.latestErrorText(from: t, latestTurnOnly: true)
		)
		XCTAssertEqual(
			AgentTranscriptTextExtraction.latestErrorText(from: t, latestTurnOnly: false),
			"disk full"
		)
	}

	// MARK: - (c) AgentTranscriptDurableFrontierSupport primary entry point

	func testDurableFrontierNormalizedTranscriptEstablishesFrontierOverFrozenPrefix() {
		// One frozen (summary-tier) prefix turn followed by a full turn.
		let frozenID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
		let frozenTurn = turn(
			id: frozenID,
			activities: [activity(.assistant, "old answer", sequence: 1)],
			retentionTier: .summary
		)
		let liveTurn = turn(
			activities: [activity(.assistant, "new answer", sequence: 2)],
			retentionTier: .full
		)
		let source = transcript([frozenTurn, liveTurn])

		let normalized = AgentTranscriptDurableFrontierSupport.normalizedTranscript(source)
		let frontier = normalized.compactionFrontier
		XCTAssertNotNil(frontier)
		XCTAssertEqual(frontier?.version, 1)                 // frozen: supportedVersion
		XCTAssertEqual(frontier?.frozenPrefixTurnCount, 1)   // frozen: single frozen prefix turn
		XCTAssertEqual(frontier?.lastFrozenTurnID, frozenID)

		// The established frontier validates for incremental reuse.
		XCTAssertEqual(
			AgentTranscriptDurableFrontierSupport.validatedFrozenPrefixTurnCountForIncrementalReuse(in: normalized),
			1
		)
	}
}
