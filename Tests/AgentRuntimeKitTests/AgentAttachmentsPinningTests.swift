import XCTest
@testable import AgentRuntimeKit

/// Pins the persisted JSON contract the attachment types shipped with when
/// they moved out of the app (transcript-core promotion, 2026-07-16).
///
/// `AgentSessionDataService` persists these via a plain `JSONEncoder()` (no
/// date-encoding strategy configured), so these tests use the same default
/// encoder to freeze what production actually emits.
final class AgentAttachmentsPinningTests: XCTestCase {
	func testImageAttachmentRoundTripsStableShape() throws {
		let attachment = AgentImageAttachment(
			id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
			source: .url("https://example.com/x.png"),
			title: "x",
			createdAt: Date(timeIntervalSince1970: 0)
		)
		let data = try JSONEncoder().encode(attachment)
		let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
		XCTAssertEqual(object.keys.sorted(), ["createdAt", "id", "source", "title"])

		// `AgentImageSource` is an enum with a single unlabeled/labeled
		// associated value; Swift's synthesized Codable emits it as a
		// single-key object keyed by case name, whose payload is itself a
		// keyed container (`_0` for the unlabeled `.url(String)` case).
		let source = try XCTUnwrap(object["source"] as? [String: Any])
		XCTAssertEqual(source.keys.sorted(), ["url"])
		let urlPayload = try XCTUnwrap(source["url"] as? [String: Any])
		XCTAssertEqual(urlPayload["_0"] as? String, "https://example.com/x.png")

		let decoded = try JSONDecoder().decode(AgentImageAttachment.self, from: data)
		XCTAssertEqual(decoded, attachment)
	}

	func testImageAttachmentLocalFileSourceRoundTripsStableShape() throws {
		let attachment = AgentImageAttachment(
			id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
			source: .localFile(path: "/tmp/x.png"),
			title: nil,
			createdAt: Date(timeIntervalSince1970: 0)
		)
		let data = try JSONEncoder().encode(attachment)
		let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
		// `title` is nil and JSONEncoder omits nil-valued optional keys by
		// default, so the key set shrinks relative to the populated case.
		XCTAssertEqual(object.keys.sorted(), ["createdAt", "id", "source"])

		let source = try XCTUnwrap(object["source"] as? [String: Any])
		XCTAssertEqual(source.keys.sorted(), ["localFile"])
		let localFilePayload = try XCTUnwrap(source["localFile"] as? [String: Any])
		XCTAssertEqual(localFilePayload["path"] as? String, "/tmp/x.png")

		let decoded = try JSONDecoder().decode(AgentImageAttachment.self, from: data)
		XCTAssertEqual(decoded, attachment)
	}

	func testTaggedFileAttachmentRoundTripsStableShape() throws {
		let file = AgentTaggedFileAttachment(
			id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
			relativePath: "Sources/App/File.swift",
			displayName: "File.swift",
			createdAt: Date(timeIntervalSince1970: 0)
		)
		let data = try JSONEncoder().encode(file)
		let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
		XCTAssertEqual(object.keys.sorted(), ["createdAt", "displayName", "id", "relativePath"])

		let decoded = try JSONDecoder().decode(AgentTaggedFileAttachment.self, from: data)
		XCTAssertEqual(decoded, file)
	}
}
