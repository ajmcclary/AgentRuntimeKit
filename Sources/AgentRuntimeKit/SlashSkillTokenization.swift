import Foundation

/// Slash-skill token surfaced by `SlashSkillTokenizer`. Promoted verbatim
/// from `AgentModeViewModel.SlashSkillToken` (turn-preparation slice 1);
/// the app keeps a same-named typealias.
public struct SlashSkillToken: Equatable, Sendable {
	public let name: String
	public let tokenRange: NSRange
	public let argumentsRange: NSRange

	public init(name: String, tokenRange: NSRange, argumentsRange: NSRange) {
		self.name = name
		self.tokenRange = tokenRange
		self.argumentsRange = argumentsRange
	}
}

/// Neutral slash-skill tokenization policy promoted to AgentRuntimeCore
/// (turn-preparation slice 1). Body verbatim from the facade's
/// `extractSlashSkillTokens(from:)`.
public enum SlashSkillTokenizer {
	public static let nameScalars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))

	/// Extract a slash-skill token only when `/` is the first non-whitespace character in the text.
	/// This allows literal slashes deeper in the input (e.g. file paths) without triggering skill expansion.
	public static func extractTokens(from text: String) -> [SlashSkillToken] {
		guard !text.isEmpty else { return [] }
		let fullText = text as NSString
		let length = fullText.length
		guard length > 0 else { return [] }

		// Find the first non-whitespace character; it must be `/` for a skill token.
		var slashIndex = 0
		while slashIndex < length {
			let ch = fullText.character(at: slashIndex)
			if let scalar = UnicodeScalar(ch), CharacterSet.whitespacesAndNewlines.contains(scalar) {
				slashIndex += 1
				continue
			}
			break
		}
		guard slashIndex < length, fullText.character(at: slashIndex) == 47 /* "/" */ else {
			return []
		}

		// Scan the skill name immediately after the `/`
		var cursor = slashIndex + 1
		var hasNameCharacter = false
		var isInvalidToken = false
		while cursor < length {
			let current = fullText.character(at: cursor)
			guard let scalar = UnicodeScalar(current) else {
				isInvalidToken = true
				break
			}
			if CharacterSet.whitespacesAndNewlines.contains(scalar) {
				break
			}
			if Self.nameScalars.contains(scalar) {
				hasNameCharacter = true
				cursor += 1
				continue
			}
			if scalar == ":",
				fullText.substring(with: NSRange(location: slashIndex + 1, length: cursor - slashIndex - 1)).lowercased() == "skill" {
				hasNameCharacter = true
				cursor += 1
				continue
			}
			isInvalidToken = true
			break
		}

		guard hasNameCharacter, !isInvalidToken else { return [] }

		let nameRange = NSRange(location: slashIndex + 1, length: cursor - slashIndex - 1)
		let name = fullText.substring(with: nameRange)
		let tokenRange = NSRange(location: slashIndex, length: cursor - slashIndex)
		let argumentsRange = NSRange(location: cursor, length: length - cursor)
		return [SlashSkillToken(name: name, tokenRange: tokenRange, argumentsRange: argumentsRange)]
	}
}
