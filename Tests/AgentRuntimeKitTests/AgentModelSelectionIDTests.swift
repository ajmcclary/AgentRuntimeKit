import XCTest
@testable import AgentRuntimeKit

final class AgentModelSelectionIDTests: XCTestCase {
	func testRawValueRoundTrip() {
		let id = AgentModelSelectionID(agentRaw: "claudeCode", modelRaw: "opus[1m]")
		XCTAssertEqual(id.rawValue, "claudeCode:opus[1m]")
		XCTAssertEqual(id.description, "claudeCode:opus[1m]")
	}

	func testParseShortFormatSplitsOnFirstColonOnly() {
		let id = AgentModelSelectionID.parse("codexExec:gpt-5.4:high")
		XCTAssertEqual(id?.agentRaw, "codexExec")
		XCTAssertEqual(id?.modelRaw, "gpt-5.4:high")
	}

	func testParseLegacyFormat() {
		let id = AgentModelSelectionID.parse("agent-selection:v1:claudeCode:sonnet")
		XCTAssertEqual(id?.agentRaw, "claudeCode")
		XCTAssertEqual(id?.modelRaw, "sonnet")
	}

	func testParseRejectsInvalid() {
		XCTAssertNil(AgentModelSelectionID.parse(""))
		XCTAssertNil(AgentModelSelectionID.parse("no-colon"))
	}
}
