import XCTest
@testable import AgentRuntimeKit

/// Pins the persisted workflow contract at promotion time (2026-07-16):
/// raw values, the dual legacy decode format, and the non-persisted template.
final class AgentWorkflowModelPinningTests: XCTestCase {
	func testWorkflowRawValuesArePinned() {
		// Persisted inside AgentChatItem.workflow and custom-workflow JSON —
		// renaming a case is a data migration.
		XCTAssertEqual(
			AgentWorkflow.allCases.map(\.rawValue),
			["build", "review", "refactor", "investigate", "oracleExport", "orchestrate", "optimize", "deepPlan"]
		)
	}

	func testBuiltInDefinitionEncodesAsBareString() throws {
		let definition = AgentWorkflowDefinition(builtIn: .build)
		let data = try JSONEncoder().encode(definition)
		XCTAssertEqual(String(data: data, encoding: .utf8), "\"build\"")
	}

	func testLegacyBareStringDecodesAsBuiltIn() throws {
		let decoded = try JSONDecoder().decode(AgentWorkflowDefinition.self, from: Data("\"review\"".utf8))
		XCTAssertEqual(decoded.builtInWorkflow, .review)
	}

	func testCustomDefinitionRoundTripsKeyedFormatWithoutTemplate() throws {
		let custom = AgentWorkflowDefinition(
			customID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
			displayName: "Mine",
			iconName: "star",
			accentColorHex: "#FF0000",
			tooltipText: "t",
			descriptionText: "d",
			template: "RUNTIME ONLY"
		)
		let data = try JSONEncoder().encode(custom)
		let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
		XCTAssertNil(object["template"], "template is runtime-only and must never persist")
		let decoded = try JSONDecoder().decode(AgentWorkflowDefinition.self, from: data)
		XCTAssertEqual(decoded.displayName, "Mine")
		XCTAssertEqual(decoded.accentColorHex, "#FF0000")
		XCTAssertNil(decoded.template)
	}
}
