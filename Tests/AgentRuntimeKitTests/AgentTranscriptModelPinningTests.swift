import XCTest
@testable import AgentRuntimeKit

/// Pins the persisted transcript contract at promotion time (2026-07-16,
/// transcript-core step 5).
///
/// The raw values and emitted key sets frozen here are written into every saved
/// agent session (`AgentSession` embeds an `AgentTranscript`; the projection-count
/// summary and grouped/collapsed summaries are persisted alongside spans and turns).
/// Renaming a case or a coding key is a data migration — these literals are frozen
/// from the shipping encoder's actual output at move time.
final class AgentTranscriptModelPinningTests: XCTestCase {

	// MARK: - Raw-value truth tables (String-raw Codable enums)

	func testRetentionTierRawValuesArePinned() {
		// Persisted at `AgentTranscriptTurn.retentionTier` (durable per-turn tier)
		// and echoed on `AgentTranscriptRenderBlock` (transient render side).
		XCTAssertEqual(AgentTranscriptRetentionTier.full.rawValue, "full")
		XCTAssertEqual(AgentTranscriptRetentionTier.condensed.rawValue, "condensed")
		XCTAssertEqual(AgentTranscriptRetentionTier.summary.rawValue, "summary")
		XCTAssertEqual(AgentTranscriptRetentionTier.archived.rawValue, "archived")
		XCTAssertEqual(
			AgentTranscriptRetentionTier.allCases.map(\.rawValue),
			["full", "condensed", "summary", "archived"]
		)
		XCTAssertEqual(AgentTranscriptRetentionTier(rawValue: "full"), .full)
		XCTAssertEqual(AgentTranscriptRetentionTier(rawValue: "condensed"), .condensed)
		XCTAssertEqual(AgentTranscriptRetentionTier(rawValue: "summary"), .summary)
		XCTAssertEqual(AgentTranscriptRetentionTier(rawValue: "archived"), .archived)
	}

	func testSpanLifecycleRawValuesArePinned() {
		// Persisted at `AgentTranscriptProviderResponseSpan.lifecycle`.
		let ordered: [AgentTranscriptSpanLifecycle] = [.open, .completed, .failed, .cancelled]
		XCTAssertEqual(ordered.map(\.rawValue), ["open", "completed", "failed", "cancelled"])
		XCTAssertEqual(AgentTranscriptSpanLifecycle(rawValue: "open"), .open)
		XCTAssertEqual(AgentTranscriptSpanLifecycle(rawValue: "completed"), .completed)
		XCTAssertEqual(AgentTranscriptSpanLifecycle(rawValue: "failed"), .failed)
		XCTAssertEqual(AgentTranscriptSpanLifecycle(rawValue: "cancelled"), .cancelled)
	}

	func testActivityRoleRawValuesArePinned() {
		// Persisted at `AgentTranscriptActivity.role` (inside each span's activities).
		let ordered: [AgentTranscriptActivityRole] = [
			.assistant, .progress, .toolExecution, .note, .system, .error, .thinking
		]
		XCTAssertEqual(
			ordered.map(\.rawValue),
			["assistant", "progress", "toolExecution", "note", "system", "error", "thinking"]
		)
		XCTAssertEqual(AgentTranscriptActivityRole(rawValue: "toolExecution"), .toolExecution)
		XCTAssertEqual(AgentTranscriptActivityRole(rawValue: "thinking"), .thinking)
	}

	func testToolStatusRawValuesArePinned() {
		// Persisted at `AgentTranscriptToolExecution.status`.
		let ordered: [AgentTranscriptToolStatus] = [
			.pending, .running, .success, .warning, .failed, .cancelled, .unknown
		]
		XCTAssertEqual(
			ordered.map(\.rawValue),
			["pending", "running", "success", "warning", "failed", "cancelled", "unknown"]
		)
		XCTAssertEqual(AgentTranscriptToolStatus(rawValue: "warning"), .warning)
		XCTAssertEqual(AgentTranscriptToolStatus(rawValue: "unknown"), .unknown)
	}

	func testCollapsedSummaryStatusRawValuesArePinned() {
		// Codable render-enum promoted with the persisted chain: persists inside
		// `AgentTranscriptCollapsedSummaryDisplay.status`, which is embedded in the
		// durable `AgentTranscriptGroupedHistorySummary` (span `collapsedSummary`).
		let ordered: [AgentTranscriptCollapsedSummaryStatus] = [.neutral, .running, .warning, .failure]
		XCTAssertEqual(ordered.map(\.rawValue), ["neutral", "running", "warning", "failure"])
		XCTAssertEqual(AgentTranscriptCollapsedSummaryStatus(rawValue: "neutral"), .neutral)
		XCTAssertEqual(AgentTranscriptCollapsedSummaryStatus(rawValue: "failure"), .failure)
	}

	// MARK: - Round-trip pin

	func testTranscriptRoundTripsMinimalShape() throws {
		// Build one fully-formed turn via the moved public API, then round-trip the
		// whole transcript through a bare JSONEncoder/JSONDecoder and assert equality.
		let itemID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
		let request = AgentTranscriptRequestAnchor(
			from: AgentChatItem(
				id: itemID,
				timestamp: Date(timeIntervalSinceReferenceDate: 10),
				kind: .user,
				text: "hello",
				sequenceIndex: 0
			)
		)
		let activity = AgentTranscriptActivity(
			id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
			timestamp: Date(timeIntervalSinceReferenceDate: 20),
			sequenceIndex: 1,
			role: .assistant,
			itemKind: .assistant,
			text: "hi back"
		)
		let span = AgentTranscriptProviderResponseSpan(
			id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
			lifecycle: .completed,
			startedAt: Date(timeIntervalSinceReferenceDate: 15),
			completedAt: Date(timeIntervalSinceReferenceDate: 30),
			activities: [activity]
		)
		let turn = AgentTranscriptTurn(
			id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
			request: request,
			responseSpans: [span],
			retentionTier: .full,
			terminalState: .completed,
			startedAt: Date(timeIntervalSinceReferenceDate: 10),
			completedAt: Date(timeIntervalSinceReferenceDate: 30)
		)
		var transcript = AgentTranscript()
		transcript.turns = [turn]
		transcript.nextSequenceIndex = 2
		transcript.compactionFrontier = AgentTranscriptCompactionFrontier(
			frozenPrefixTurnCount: 0,
			lastFrozenTurnID: turn.id
		)

		let data = try JSONEncoder().encode(transcript)
		let decoded = try JSONDecoder().decode(AgentTranscript.self, from: data)
		XCTAssertEqual(decoded, transcript)
	}

	// MARK: - Emitted-key-set pins (mirror the manual CodingKeys)

	func testTurnCodingKeysArePinned() throws {
		// Encode a fully-populated turn (every encodeIfPresent field non-nil) and pin
		// the emitted top-level key set. Field renames are migrations. Literal frozen
		// from the first real encode (2026-07-16).
		let turn = AgentTranscriptTurn(
			id: UUID(),
			request: AgentTranscriptRequestAnchor(
				from: AgentChatItem(id: UUID(), timestamp: Date(), kind: .user, text: "hi", sequenceIndex: 0)
			),
			responseSpans: [AgentTranscriptProviderResponseSpan(startedAt: Date())],
			conclusionActivityID: UUID(),
			retentionTier: .full,
			summary: AgentTranscriptTurnSummary(
				requestText: "r",
				conclusionText: "c",
				compactConclusionText: "cc",
				middleSummaryText: "m",
				toolCount: 1,
				notableToolNames: ["a"],
				keyPaths: ["k"],
				compactedActivityCount: 0,
				hadWarning: false,
				hadError: false
			),
			terminalState: .completed,
			startedAt: Date(),
			lastActivityAt: Date(),
			completedAt: Date(),
			frozenDetailedToolTailLimit: 3
		)
		let data = try JSONEncoder().encode(turn)
		let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
		let keys = (object?.keys).map { Array($0).sorted() } ?? []
		XCTAssertEqual(
			keys,
			[
				"completedAt",
				"conclusionActivityID",
				"frozenDetailedToolTailLimit",
				"id",
				"lastActivityAt",
				"request",
				"responseSpans",
				"retentionTier",
				"startedAt",
				"summary",
				"terminalState"
			]
		)
	}

	func testProviderResponseSpanCodingKeysArePinned() throws {
		// The span's manual CodingKeys deliberately EXCLUDE the transient
		// `fullRenderGroupedHistoryCache` (a compile-closure move that is never
		// persisted). Pin the emitted key set to guard that exclusion.
		var span = AgentTranscriptProviderResponseSpan(startedAt: Date())
		span.collapsedSummary = AgentTranscriptGroupedHistorySummary(
			hiddenToolCardCount: 0,
			hiddenAssistantCount: 0,
			hiddenProgressCount: 0,
			hiddenNoteCount: 0,
			toolSummary: nil
		)
		span.fullRenderGroupedHistoryCache = AgentTranscriptFullRenderGroupedHistoryCache(
			detailedToolTailLimit: 5,
			collapseDigest: "digest",
			summary: span.collapsedSummary!
		)
		let data = try JSONEncoder().encode(span)
		let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
		let keys = (object?.keys).map { Array($0).sorted() } ?? []
		XCTAssertEqual(
			keys,
			["activities", "collapsedSummary", "id", "lifecycle", "startedAt"]
		)
		XCTAssertFalse(keys.contains("fullRenderGroupedHistoryCache"))
	}
}
