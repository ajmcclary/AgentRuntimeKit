import XCTest
@testable import AgentRuntimeKit

/// Behavior pins for the transcript policies promoted to AgentRuntimeCore in transcript-core step 6.
/// Only the two Foundation-only policies (`AgentTranscriptImportPolicy`,
/// `AgentTranscriptCompactionMode`) are package-owned; the other candidates
/// (`AgentTranscriptSummaryTextFormatter`, `AgentTranscriptCompactor`,
/// `AgentTranscriptToolStatusSemantics`) stay app-side and are pinned there.
final class AgentTranscriptPolicyTests: XCTestCase {

	// MARK: - AgentTranscriptImportPolicy

	func testCanonicalPolicyHidesAlwaysHiddenToolsButKeepsPendingQuestion() {
		let policy = AgentTranscriptImportPolicy.canonical
		XCTAssertTrue(policy.hideAlwaysHiddenTools)
		XCTAssertFalse(policy.hidePendingQuestionToolCall)
	}

	func testLiveSessionForcesAlwaysHiddenAndThreadsPendingQuestionFlag() {
		let hiding = AgentTranscriptImportPolicy.liveSession(hidePendingQuestionToolCall: true)
		XCTAssertTrue(hiding.hideAlwaysHiddenTools)
		XCTAssertTrue(hiding.hidePendingQuestionToolCall)

		let showing = AgentTranscriptImportPolicy.liveSession(hidePendingQuestionToolCall: false)
		XCTAssertTrue(showing.hideAlwaysHiddenTools)
		XCTAssertFalse(showing.hidePendingQuestionToolCall)
	}

	func testImportPolicyDefaultInitAndEquatability() {
		XCTAssertEqual(AgentTranscriptImportPolicy(), AgentTranscriptImportPolicy.canonical)
		XCTAssertEqual(
			AgentTranscriptImportPolicy(hideAlwaysHiddenTools: true, hidePendingQuestionToolCall: false),
			.liveSession(hidePendingQuestionToolCall: false)
		)
		XCTAssertNotEqual(
			AgentTranscriptImportPolicy(hideAlwaysHiddenTools: false),
			.canonical
		)
	}

	// MARK: - AgentTranscriptCompactionMode

	func testCompactionModeEqualityAndDistinctCases() {
		XCTAssertEqual(AgentTranscriptCompactionMode.recomputeAll, .recomputeAll)
		XCTAssertEqual(AgentTranscriptCompactionMode.preserveDurableFrontier, .preserveDurableFrontier)
		XCTAssertNotEqual(AgentTranscriptCompactionMode.recomputeAll, .preserveDurableFrontier)
	}
}
