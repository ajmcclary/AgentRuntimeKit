import XCTest
@testable import AgentRuntimeKit

/// Characterization tests pinning the run-state contract the enum shipped
/// with when it moved out of the app (session-type promotion).
final class AgentSessionRunStateTests: XCTestCase {
	func testRawValuesArePinned() {
		// Persisted in session JSON via AgentSession.lastRunState — renaming a
		// case is a data migration.
		let allCases: [AgentSessionRunState] = [
			.idle, .running, .waitingForUser, .waitingForQuestion,
			.waitingForApproval, .completed, .cancelled, .failed,
		]
		XCTAssertEqual(
			allCases.map(\.rawValue),
			["idle", "running", "waitingForUser", "waitingForQuestion", "waitingForApproval", "completed", "cancelled", "failed"]
		)
	}

	func testIsActiveTruthTable() {
		XCTAssertFalse(AgentSessionRunState.idle.isActive)
		XCTAssertTrue(AgentSessionRunState.running.isActive)
		XCTAssertTrue(AgentSessionRunState.waitingForUser.isActive)
		XCTAssertTrue(AgentSessionRunState.waitingForQuestion.isActive)
		XCTAssertTrue(AgentSessionRunState.waitingForApproval.isActive)
		XCTAssertFalse(AgentSessionRunState.completed.isActive)
		XCTAssertFalse(AgentSessionRunState.cancelled.isActive)
		XCTAssertFalse(AgentSessionRunState.failed.isActive)
	}

	func testTouchesSidebarVisibleActivityOnTransitionTruthTable() {
		XCTAssertFalse(AgentSessionRunState.idle.touchesSidebarVisibleActivityOnTransition)
		XCTAssertFalse(AgentSessionRunState.running.touchesSidebarVisibleActivityOnTransition)
		XCTAssertTrue(AgentSessionRunState.waitingForUser.touchesSidebarVisibleActivityOnTransition)
		XCTAssertTrue(AgentSessionRunState.waitingForQuestion.touchesSidebarVisibleActivityOnTransition)
		XCTAssertTrue(AgentSessionRunState.waitingForApproval.touchesSidebarVisibleActivityOnTransition)
		XCTAssertTrue(AgentSessionRunState.completed.touchesSidebarVisibleActivityOnTransition)
		XCTAssertTrue(AgentSessionRunState.cancelled.touchesSidebarVisibleActivityOnTransition)
		XCTAssertTrue(AgentSessionRunState.failed.touchesSidebarVisibleActivityOnTransition)
	}
}
