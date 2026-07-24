import Foundation

// MARK: - Agent Chat Item Types

/// The type/category of an agent chat item
public enum AgentChatItemKind: String, Codable, Sendable {
	case user
	case assistant
	case assistantInline
	case toolCall
	case toolResult
	case system
	case error
	case thinking
}

public enum AgentDisplayableText {
	public static func hasDisplayableBody(_ text: String) -> Bool {
		text.unicodeScalars.contains { scalar in
			isDisplayableScalar(scalar)
		}
	}

	private static func isDisplayableScalar(_ scalar: UnicodeScalar) -> Bool {
		if CharacterSet.whitespacesAndNewlines.contains(scalar) {
			return false
		}
		if CharacterSet.controlCharacters.contains(scalar) || CharacterSet.illegalCharacters.contains(scalar) {
			return false
		}
		if isInvisibleFormatScalar(scalar) {
			return false
		}
		return true
	}

	private static func isInvisibleFormatScalar(_ scalar: UnicodeScalar) -> Bool {
		switch scalar.value {
		case 0x00AD,       // SOFT HYPHEN
			0x034F,        // COMBINING GRAPHEME JOINER
			0x061C,        // ARABIC LETTER MARK
			0x2800,        // BRAILLE PATTERN BLANK
			0x3164,        // HANGUL FILLER
			0x115F...0x1160,
			0x17B4...0x17B5,
			0x180E,        // MONGOLIAN VOWEL SEPARATOR
			0x200B...0x200F,
			0x202A...0x202E,
			0x2060...0x206F,
			0xFE00...0xFE0F,
			0xFEFF,
			0xFFA0,        // HALFWIDTH HANGUL FILLER
			0xFFF9...0xFFFB,
			0x1BCA0...0x1BCA3,
			0x1D173...0x1D17A,
			0xE0000...0xE0FFF:
			return true
		default:
			return false
		}
	}
}

// MARK: - Codex Goal Mode Metadata

public struct AgentCodexGoalModeMetadata: Codable, Sendable, Equatable {
	public enum Action: String, Codable, Sendable, Equatable {
		case setObjective
		case show
		case pause
		case resume
		case clear
	}

	public let action: Action

	public init(action: Action) {
		self.action = action
	}
}

// MARK: - Agent Chat Item

/// A single item in an agent chat transcript (user message, assistant message, tool call, etc.)
public struct AgentChatItem: Codable, Identifiable, Sendable, Equatable {
	public let id: UUID
	public let timestamp: Date
	public var kind: AgentChatItemKind

	/// Human-readable text shown in bubbles (for user/assistant/system/error kinds)
	public var text: String

	/// User-provided image attachments for this turn
	public var attachments: [AgentImageAttachment]

	/// Tagged file attachments (@ mentioned files) for this user turn
	public var taggedFileAttachments: [AgentTaggedFileAttachment]

	/// Tool metadata (for toolCall/toolResult kinds)
	public var toolName: String?
	public var toolInvocationID: UUID?
	public var toolArgsJSON: String?   // JSON string of tool arguments
	public var toolResultJSON: String? // Tool execution result JSON (for toolResult kind)
	public var toolIsError: Bool?

	/// Optional reasoning text (for models with extended thinking)
	public var reasoning: String?

	/// Sequence index for ordering within a session
	public var sequenceIndex: Int

	/// Whether this item is still being streamed (for partial updates)
	public var isStreaming: Bool

	/// Workflow used for this user message (nil for non-workflow messages)
	public var workflow: AgentWorkflowDefinition?

	/// Codex goal-mode metadata for user bubbles that represent `/goal` control-plane actions.
	public var codexGoalMode: AgentCodexGoalModeMetadata?

	/// True for local control-plane echoes that should display in chat but are not provider-backed user turns.
	public var isLocalControlPlaneEcho: Bool

	public init(
		id: UUID = UUID(),
		timestamp: Date = Date(),
		kind: AgentChatItemKind,
		text: String,
		attachments: [AgentImageAttachment] = [],
		taggedFileAttachments: [AgentTaggedFileAttachment] = [],
		toolName: String? = nil,
		toolInvocationID: UUID? = nil,
		toolArgsJSON: String? = nil,
		toolResultJSON: String? = nil,
		toolIsError: Bool? = nil,
		reasoning: String? = nil,
		sequenceIndex: Int = 0,
		isStreaming: Bool = false,
		workflow: AgentWorkflowDefinition? = nil,
		codexGoalMode: AgentCodexGoalModeMetadata? = nil,
		isLocalControlPlaneEcho: Bool = false
	) {
		self.id = id
		self.timestamp = timestamp
		self.kind = kind
		self.text = text
		self.attachments = attachments
		self.taggedFileAttachments = taggedFileAttachments
		self.toolName = toolName
		self.toolInvocationID = toolInvocationID
		self.toolArgsJSON = toolArgsJSON
		self.toolResultJSON = toolResultJSON
		self.toolIsError = toolIsError
		self.reasoning = reasoning
		self.sequenceIndex = sequenceIndex
		self.isStreaming = isStreaming
		self.workflow = workflow
		self.codexGoalMode = codexGoalMode
		self.isLocalControlPlaneEcho = isLocalControlPlaneEcho
	}

	public var hasDisplayableAssistantBody: Bool {
		guard kind == .assistant || kind == .assistantInline else { return false }
		return AgentDisplayableText.hasDisplayableBody(text)
	}

	// MARK: - Codable (backwards-compatible decoding for new fields)

	private enum CodingKeys: String, CodingKey {
		case id, timestamp, kind, text, attachments, taggedFileAttachments
		case toolName, toolInvocationID, toolArgsJSON, toolResultJSON, toolIsError
		case reasoning, sequenceIndex, isStreaming, workflow, codexGoalMode, isLocalControlPlaneEcho
	}

	public init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		id = try c.decode(UUID.self, forKey: .id)
		timestamp = try c.decode(Date.self, forKey: .timestamp)
		kind = try c.decode(AgentChatItemKind.self, forKey: .kind)
		text = try c.decode(String.self, forKey: .text)
		attachments = try c.decodeIfPresent([AgentImageAttachment].self, forKey: .attachments) ?? []
		taggedFileAttachments = try c.decodeIfPresent([AgentTaggedFileAttachment].self, forKey: .taggedFileAttachments) ?? []
		toolName = try c.decodeIfPresent(String.self, forKey: .toolName)
		toolInvocationID = try c.decodeIfPresent(UUID.self, forKey: .toolInvocationID)
		toolArgsJSON = try c.decodeIfPresent(String.self, forKey: .toolArgsJSON)
		toolResultJSON = try c.decodeIfPresent(String.self, forKey: .toolResultJSON)
		toolIsError = try c.decodeIfPresent(Bool.self, forKey: .toolIsError)
		reasoning = try c.decodeIfPresent(String.self, forKey: .reasoning)
		sequenceIndex = try c.decode(Int.self, forKey: .sequenceIndex)
		isStreaming = try c.decodeIfPresent(Bool.self, forKey: .isStreaming) ?? false
		workflow = try c.decodeIfPresent(AgentWorkflowDefinition.self, forKey: .workflow)
		codexGoalMode = try c.decodeIfPresent(AgentCodexGoalModeMetadata.self, forKey: .codexGoalMode)
		isLocalControlPlaneEcho = try c.decodeIfPresent(Bool.self, forKey: .isLocalControlPlaneEcho) ?? false
	}

	// MARK: - Factory Methods

	public static func user(_ text: String, attachments: [AgentImageAttachment] = [], taggedFileAttachments: [AgentTaggedFileAttachment] = [], sequenceIndex: Int = 0, workflow: AgentWorkflowDefinition? = nil, codexGoalMode: AgentCodexGoalModeMetadata? = nil, isLocalControlPlaneEcho: Bool = false) -> AgentChatItem {
		AgentChatItem(kind: .user, text: text, attachments: attachments, taggedFileAttachments: taggedFileAttachments, sequenceIndex: sequenceIndex, workflow: workflow, codexGoalMode: codexGoalMode, isLocalControlPlaneEcho: isLocalControlPlaneEcho)
	}

	public static func assistant(_ text: String, reasoning: String? = nil, sequenceIndex: Int = 0, isStreaming: Bool = false) -> AgentChatItem {
		AgentChatItem(kind: .assistant, text: text, reasoning: reasoning, sequenceIndex: sequenceIndex, isStreaming: isStreaming)
	}

	public static func assistantInline(_ text: String, sequenceIndex: Int = 0) -> AgentChatItem {
		AgentChatItem(kind: .assistantInline, text: text, sequenceIndex: sequenceIndex)
	}

	public static func toolCall(name: String, invocationID: UUID? = nil, argsJSON: String?, sequenceIndex: Int = 0) -> AgentChatItem {
		AgentChatItem(kind: .toolCall, text: "Using tool: \(name)", toolName: name, toolInvocationID: invocationID, toolArgsJSON: argsJSON, sequenceIndex: sequenceIndex)
	}

	public static func toolResult(name: String, invocationID: UUID? = nil, resultJSON: String, isError: Bool? = nil, sequenceIndex: Int = 0) -> AgentChatItem {
		AgentChatItem(kind: .toolResult, text: resultJSON, toolName: name, toolInvocationID: invocationID, toolResultJSON: resultJSON, toolIsError: isError, sequenceIndex: sequenceIndex)
	}

	public static func system(_ text: String, sequenceIndex: Int = 0) -> AgentChatItem {
		AgentChatItem(kind: .system, text: text, sequenceIndex: sequenceIndex)
	}

	public static func error(_ text: String, sequenceIndex: Int = 0) -> AgentChatItem {
		AgentChatItem(kind: .error, text: text, sequenceIndex: sequenceIndex)
	}

	public static func thinking(_ text: String, sequenceIndex: Int = 0) -> AgentChatItem {
		AgentChatItem(kind: .thinking, text: text, sequenceIndex: sequenceIndex)
	}
}

// MARK: - Persistence Model

/// Persisted version of AgentChatItem for storage
public struct AgentChatItemPersist: Codable, Identifiable, Sendable, Equatable {
	public let id: UUID
	public let timestamp: Date
	public var kind: AgentChatItemKind
	public var text: String
	public var attachments: [AgentImageAttachment]
	public var taggedFileAttachments: [AgentTaggedFileAttachment]
	public var toolName: String?
	public var toolInvocationID: UUID?
	public var toolArgsJSON: String?
	public var toolResultJSON: String?
	public var toolIsError: Bool?
	public var toolResultStatus: String?
	public var reasoning: String?
	public var sequenceIndex: Int
	public var workflow: AgentWorkflowDefinition?
	public var codexGoalMode: AgentCodexGoalModeMetadata?
	public var isLocalControlPlaneEcho: Bool

	/// Memberwise storage initializer.
	///
	/// Added when the persisted shape moved into AgentRuntimeCore (transcript-core
	/// extraction, 2026-07-16). The transcript-coupled conversion initializer
	/// `init(from item:sanitizeToolResults:)` lives app-side in
	/// `AgentChatItemPersist+Conversion.swift`; because a cross-module extension
	/// cannot assign this struct's stored `let` properties directly, that
	/// initializer computes the sanitized field values and delegates here with
	/// identical property values (zero behavior change).
	public init(
		id: UUID,
		timestamp: Date,
		kind: AgentChatItemKind,
		text: String,
		attachments: [AgentImageAttachment],
		taggedFileAttachments: [AgentTaggedFileAttachment],
		toolName: String?,
		toolInvocationID: UUID?,
		toolArgsJSON: String?,
		toolResultJSON: String?,
		toolIsError: Bool?,
		toolResultStatus: String?,
		reasoning: String?,
		sequenceIndex: Int,
		workflow: AgentWorkflowDefinition?,
		codexGoalMode: AgentCodexGoalModeMetadata?,
		isLocalControlPlaneEcho: Bool
	) {
		self.id = id
		self.timestamp = timestamp
		self.kind = kind
		self.text = text
		self.attachments = attachments
		self.taggedFileAttachments = taggedFileAttachments
		self.toolName = toolName
		self.toolInvocationID = toolInvocationID
		self.toolArgsJSON = toolArgsJSON
		self.toolResultJSON = toolResultJSON
		self.toolIsError = toolIsError
		self.toolResultStatus = toolResultStatus
		self.reasoning = reasoning
		self.sequenceIndex = sequenceIndex
		self.workflow = workflow
		self.codexGoalMode = codexGoalMode
		self.isLocalControlPlaneEcho = isLocalControlPlaneEcho
	}

	enum CodingKeys: String, CodingKey {
		case id
		case timestamp
		case kind
		case text
		case attachments
		case taggedFileAttachments
		case toolName
		case toolInvocationID
		case toolArgsJSON
		case toolResultJSON
		case toolIsError
		case toolResultStatus
		case reasoning
		case sequenceIndex
		case workflow
		case codexGoalMode
		case isLocalControlPlaneEcho
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		timestamp = try container.decode(Date.self, forKey: .timestamp)
		kind = try container.decode(AgentChatItemKind.self, forKey: .kind)
		text = try container.decode(String.self, forKey: .text)
		attachments = try container.decodeIfPresent([AgentImageAttachment].self, forKey: .attachments) ?? []
		taggedFileAttachments = try container.decodeIfPresent([AgentTaggedFileAttachment].self, forKey: .taggedFileAttachments) ?? []
		toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
		toolInvocationID = try container.decodeIfPresent(UUID.self, forKey: .toolInvocationID)
		toolArgsJSON = try container.decodeIfPresent(String.self, forKey: .toolArgsJSON)
		toolResultJSON = try container.decodeIfPresent(String.self, forKey: .toolResultJSON)
		toolIsError = try container.decodeIfPresent(Bool.self, forKey: .toolIsError)
		toolResultStatus = try container.decodeIfPresent(String.self, forKey: .toolResultStatus)
		reasoning = try container.decodeIfPresent(String.self, forKey: .reasoning)
		sequenceIndex = try container.decode(Int.self, forKey: .sequenceIndex)
		workflow = try container.decodeIfPresent(AgentWorkflowDefinition.self, forKey: .workflow)
		codexGoalMode = try container.decodeIfPresent(AgentCodexGoalModeMetadata.self, forKey: .codexGoalMode)
		isLocalControlPlaneEcho = try container.decodeIfPresent(Bool.self, forKey: .isLocalControlPlaneEcho) ?? false
	}
}
