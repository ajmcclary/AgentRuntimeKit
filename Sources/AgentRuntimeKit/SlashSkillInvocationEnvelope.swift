import Foundation

/// Staged slash-skill invocation envelope decoded from workflow input text.
/// Promoted verbatim from AgentModeViewModel (turn-preparation slice 1).
public struct PendingSlashSkillInvocationEnvelope: Sendable {
	public let range: Range<String.Index>
	public let sourceText: String

	public init(range: Range<String.Index>, sourceText: String) {
		self.range = range
		self.sourceText = sourceText
	}
}

/// Neutral envelope codec for deferring slash-skill expansion through
/// workflow templating. Bodies verbatim from the facade's private
/// `PendingSlashSkillInvocationEnvelopeCodec` (turn-preparation slice 1).
public enum PendingSlashSkillInvocationEnvelopeCodec {
	public static let prefix = "{{REPOPROMPT_PENDING_SLASH_SKILL_BASE64:"
	public static let suffix = "}}"

	public static func encode(sourceText: String) -> String {
		let payload = Data(sourceText.utf8).base64EncodedString()
		return "\(prefix)\(payload)\(suffix)"
	}

	public static func decodeEnvelopes(in text: String) -> [PendingSlashSkillInvocationEnvelope] {
		var envelopes: [PendingSlashSkillInvocationEnvelope] = []
		var searchStart = text.startIndex
		while searchStart < text.endIndex,
			let prefixRange = text.range(of: prefix, range: searchStart..<text.endIndex) {
			let payloadStart = prefixRange.upperBound
			guard let suffixRange = text.range(of: suffix, range: payloadStart..<text.endIndex) else {
				break
			}
			let payload = String(text[payloadStart..<suffixRange.lowerBound])
			if let data = Data(base64Encoded: payload),
				let sourceText = String(data: data, encoding: .utf8) {
				envelopes.append(PendingSlashSkillInvocationEnvelope(
					range: prefixRange.lowerBound..<suffixRange.upperBound,
					sourceText: sourceText
				))
			}
			searchStart = suffixRange.upperBound
		}
		return envelopes
	}
}
