import Foundation

/// Neutral tagged-path (`@path`) parsing policy promoted to AgentRuntimeCore
/// (turn-preparation slice 1). Bodies verbatim from the facade's
/// `extractTaggedPaths(from:)` / `unescapeTaggedPath(_:)`; the trim and
/// terminator character sets move with the parser.
public enum AgentTaggedPathParser {
	private static let trailingTrimSet = CharacterSet(charactersIn: ").,;:!?]}")
	private static let terminatingScalars = CharacterSet.whitespacesAndNewlines

	public static func extractTaggedPaths(from text: String) -> [String] {
		guard !text.isEmpty else { return [] }
		let scalars = Array(text.unicodeScalars)
		var ordered: [String] = []
		ordered.reserveCapacity(8)
		var seen = Set<String>()
		var index = 0

		while index < scalars.count {
			let scalar = scalars[index]
			guard scalar == "@" else {
				index += 1
				continue
			}
			if index > 0 {
				let previous = scalars[index - 1]
				if !terminatingScalars.contains(previous) {
					index += 1
					continue
				}
			}

			var cursor = index + 1
			var tokenScalars: [UnicodeScalar] = []
			var isEscaped = false

			while cursor < scalars.count {
				let current = scalars[cursor]
				if isEscaped {
					tokenScalars.append(current)
					isEscaped = false
					cursor += 1
					continue
				}
				if current == "\\" {
					isEscaped = true
					cursor += 1
					continue
				}
				if terminatingScalars.contains(current) {
					break
				}
				tokenScalars.append(current)
				cursor += 1
			}

			var token = String(String.UnicodeScalarView(tokenScalars))
			token = token.trimmingCharacters(in: trailingTrimSet)
			if !token.isEmpty {
				let lowered = token.lowercased()
				if !lowered.hasPrefix("/")
					&& !lowered.hasPrefix("~")
					&& !lowered.hasPrefix("file://")
					&& seen.insert(token).inserted {
					ordered.append(token)
				}
			}

			index = cursor
		}

		return ordered
	}

	public static func unescapeTaggedPath(_ value: String) -> String {
		guard value.contains("\\") else {
			return value.trimmingCharacters(in: .whitespacesAndNewlines)
		}
		let scalars = Array(value.unicodeScalars)
		var output: [UnicodeScalar] = []
		output.reserveCapacity(scalars.count)
		var index = 0
		while index < scalars.count {
			let current = scalars[index]
			if current == "\\", index + 1 < scalars.count {
				let next = scalars[index + 1]
				switch next {
				case "\\", " ", ",", ";", "!", "?", "(", ")", "[", "]", "{", "}":
					output.append(next)
				default:
					output.append(current)
					output.append(next)
				}
				index += 2
				continue
			}
			output.append(current)
			index += 1
		}
		return String(String.UnicodeScalarView(output)).trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
