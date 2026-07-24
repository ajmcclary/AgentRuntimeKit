import Foundation

public enum AgentProviderBindingID: String, CaseIterable, Hashable, Sendable {
	case codex
	case claude
	case gemini
	case openCode
	case cursor

	public var displayName: String {
		switch self {
		case .codex:
			return "Codex CLI"
		case .claude:
			return "Claude Code"
		case .gemini:
			return "Gemini CLI"
		case .openCode:
			return "OpenCode"
		case .cursor:
			return "Cursor CLI"
		}
	}
}
