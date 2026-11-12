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

	func testParseLegacyFormatRejectsBlankOrColonBearingDecodedSegmentsWithoutTrapping() {
		// Decodes to a space (blank after trimming).
		XCTAssertNil(AgentModelSelectionID.parse("agent-selection:v1:%20:x"))
		XCTAssertNil(AgentModelSelectionID.parse("agent-selection:v1:x:%20%0A"))
		// Decodes to an agent containing ':'.
		XCTAssertNil(AgentModelSelectionID.parse("agent-selection:v1:a%3Ab:x"))
		// Percent-encoded surrounding whitespace is trimmed, not rejected.
		let id = AgentModelSelectionID.parse("agent-selection:v1:%20codexExec:default%20")
		XCTAssertEqual(id?.agentRaw, "codexExec")
		XCTAssertEqual(id?.modelRaw, "default")
	}

	func testValidatingInitializerReturnsNilInsteadOfTrapping() {
		XCTAssertNil(AgentModelSelectionID(validatingAgentRaw: "  ", modelRaw: "x"))
		XCTAssertNil(AgentModelSelectionID(validatingAgentRaw: "x", modelRaw: "\n"))
		XCTAssertNil(AgentModelSelectionID(validatingAgentRaw: "a:b", modelRaw: "x"))
		let id = AgentModelSelectionID(validatingAgentRaw: " claudeCode ", modelRaw: " opus:1m ")
		XCTAssertEqual(id?.rawValue, "claudeCode:opus:1m")
	}
}
