import XCTest
@testable import AgentRuntimeKit

/// Pinning tests for the turn-preparation pure policies promoted from
/// AgentModeViewModel (phase 2, slice 1). These document the promoted
/// bodies' existing behavior — the verbatim-moved implementation is the
/// spec; if an expectation here disagrees with it, the test is wrong.
final class AgentTurnPreparationPolicyTests: XCTestCase {
	// MARK: - SlashSkillTokenizer

	func testTokenAtStart() {
		let tokens = SlashSkillTokenizer.extractTokens(from: "/review-code do it well")
		XCTAssertEqual(tokens.map(\.name), ["review-code"])
		XCTAssertEqual(tokens[0].tokenRange, NSRange(location: 0, length: 12))
	}

	func testLeadingWhitespaceAllowed() {
		XCTAssertEqual(SlashSkillTokenizer.extractTokens(from: "  \n/fix args").map(\.name), ["fix"])
	}

	func testSlashDeeperInTextIsNotAToken() {
		XCTAssertTrue(SlashSkillTokenizer.extractTokens(from: "see path/to/file").isEmpty)
		XCTAssertTrue(SlashSkillTokenizer.extractTokens(from: "a /skill").isEmpty)
	}

	func testExplicitSkillNamespaceColonAccepted() {
		XCTAssertEqual(SlashSkillTokenizer.extractTokens(from: "/skill:foo bar").map(\.name), ["skill:foo"])
	}

	func testInvalidCharacterRejectsToken() {
		XCTAssertTrue(SlashSkillTokenizer.extractTokens(from: "/bad$name x").isEmpty)
		XCTAssertTrue(SlashSkillTokenizer.extractTokens(from: "/").isEmpty)
	}

	func testArgumentsRangeCoversRemainder() {
		let text = "/name the args"
		let token = SlashSkillTokenizer.extractTokens(from: text)[0]
		XCTAssertEqual((text as NSString).substring(with: token.argumentsRange), " the args")
	}

	// MARK: - PendingSlashSkillInvocationEnvelopeCodec

	func testEnvelopeRoundTrip() {
		let source = "/skill do § unicode ✓"
		let encoded = PendingSlashSkillInvocationEnvelopeCodec.encode(sourceText: source)
		let envelopes = PendingSlashSkillInvocationEnvelopeCodec.decodeEnvelopes(in: "prefix \(encoded) suffix")
		XCTAssertEqual(envelopes.count, 1)
		XCTAssertEqual(envelopes[0].sourceText, source)
	}

	func testMultipleEnvelopesDecodeInOrder() {
		let a = PendingSlashSkillInvocationEnvelopeCodec.encode(sourceText: "one")
		let b = PendingSlashSkillInvocationEnvelopeCodec.encode(sourceText: "two")
		let decoded = PendingSlashSkillInvocationEnvelopeCodec.decodeEnvelopes(in: "\(a) mid \(b)")
		XCTAssertEqual(decoded.map(\.sourceText), ["one", "two"])
	}

	func testInvalidBase64PayloadIsSkipped() {
		let bad = "{{REPOPROMPT_PENDING_SLASH_SKILL_BASE64:!!notbase64!!}}"
		XCTAssertTrue(PendingSlashSkillInvocationEnvelopeCodec.decodeEnvelopes(in: bad).isEmpty)
	}

	// MARK: - AgentTaggedPathParser

	func testExtractSimpleTaggedPath() {
		XCTAssertEqual(AgentTaggedPathParser.extractTaggedPaths(from: "see @src/main.swift please"), ["src/main.swift"])
	}

	func testAtMidWordIsIgnored() {
		XCTAssertTrue(AgentTaggedPathParser.extractTaggedPaths(from: "user@example.com").isEmpty)
	}

	func testEscapedSpaceIsUnescapedDuringScan() {
		// The scanner consumes the escape backslash and appends the escaped
		// character raw; unescapeTaggedPath exists for attachment paths that
		// arrive still-escaped.
		XCTAssertEqual(AgentTaggedPathParser.extractTaggedPaths(from: "@My\\ File.txt"), ["My File.txt"])
	}

	func testTrailingPunctuationTrimmed() {
		XCTAssertEqual(AgentTaggedPathParser.extractTaggedPaths(from: "check @a/b.txt, thanks"), ["a/b.txt"])
	}

	func testAbsoluteTildeAndFileURLExcluded() {
		XCTAssertTrue(AgentTaggedPathParser.extractTaggedPaths(from: "@/abs @~/home @file://x").isEmpty)
	}

	func testDeduplicationPreservesFirstOrder() {
		XCTAssertEqual(AgentTaggedPathParser.extractTaggedPaths(from: "@a.txt @b.txt @a.txt"), ["a.txt", "b.txt"])
	}

	func testUnescapeTaggedPath() {
		XCTAssertEqual(AgentTaggedPathParser.unescapeTaggedPath("My\\ File\\,v2.txt"), "My File,v2.txt")
		XCTAssertEqual(AgentTaggedPathParser.unescapeTaggedPath("plain.txt"), "plain.txt")
		XCTAssertEqual(AgentTaggedPathParser.unescapeTaggedPath("keep\\d"), "keep\\d")
	}

	// MARK: - AgentTurnMessageComposition

	func testComposeInitialThreadMessageAllSections() {
		let out = AgentTurnMessageComposition.composeInitialThreadMessage(initialMessage: "do it", fileTree: "tree", promptText: "prompt")
		XCTAssertTrue(out.hasPrefix("do it\n\n<file_map>\ntree\n</file_map>"))
		XCTAssertTrue(out.contains("<current_prompt_content>\nprompt\n</current_prompt_content>"))
	}

	func testComposeInitialThreadMessageNoContextReturnsMessage() {
		XCTAssertEqual(AgentTurnMessageComposition.composeInitialThreadMessage(initialMessage: "m", fileTree: "  ", promptText: nil), "m")
	}

	func testComposeInitialThreadMessageEmptyInstructionReturnsContextOnly() {
		let out = AgentTurnMessageComposition.composeInitialThreadMessage(initialMessage: "  ", fileTree: "t", promptText: nil)
		XCTAssertTrue(out.hasPrefix("<file_map>"))
	}

	func testComposeSessionHandoffPayloadShape() {
		let out = AgentTurnMessageComposition.composeSessionHandoffPayload(sourceTabName: "Tab", sourceAgentName: "Claude Code", sourceModelName: "opus", fileContentsBlock: "files", transcriptXML: "<t/>", deliveryID: "D1")
		XCTAssertTrue(out.contains("<forked_session source=\"Tab\" delivery_id=\"D1\">"))
		XCTAssertTrue(out.contains("Claude Code (opus)"))
		XCTAssertTrue(out.contains("files\n\n<t/>"))
		XCTAssertTrue(out.contains("</forked_session>"))
	}

	func testComposeClaudeResumeRecoveryPayloadShape() {
		let out = AgentTurnMessageComposition.composeClaudeResumeRecoveryHandoffPayload(sourceTabName: "Tab", sourceAgentName: "Claude Code", transcriptXML: "<t/>", initialThreadContextBlock: "ctx", deliveryID: "D2")
		XCTAssertTrue(out.contains("delivery_id=\"D2\""))
		XCTAssertTrue(out.contains("<original_thread_context>\nctx\n</original_thread_context>"))
		XCTAssertTrue(out.contains("restarted after a native resume failed for Claude Code"))
	}

	func testEscapePromptXMLAttribute() {
		XCTAssertEqual(AgentTurnMessageComposition.escapePromptXMLAttribute(#"a&"<>"#), "a&amp;&quot;&lt;&gt;")
	}

	func testRenderSlashSkillUserInstructions() {
		XCTAssertEqual(AgentTurnMessageComposition.renderSlashSkillUserInstructions("  "), "")
		XCTAssertEqual(AgentTurnMessageComposition.renderSlashSkillUserInstructions("go"), "<user_instructions>\ngo\n</user_instructions>")
	}
}
