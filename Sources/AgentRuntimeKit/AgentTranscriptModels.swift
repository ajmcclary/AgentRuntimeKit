import Foundation

public enum AgentTranscriptRetentionTier: String, Codable, Sendable, CaseIterable {
	case full
	case condensed
	case summary
	case archived
}

public enum AgentTranscriptSpanLifecycle: String, Codable, Sendable, Equatable {
	case open
	case completed
	case failed
	case cancelled
}

public enum AgentTranscriptActivityRole: String, Codable, Sendable, Equatable {
	case assistant
	case progress
	case toolExecution
	case note
	case system
	case error
	case thinking
}

public enum AgentTranscriptToolStatus: String, Codable, Sendable, Equatable {
	case pending
	case running
	case success
	case warning
	case failed
	case cancelled
	case unknown
}

public struct AgentTranscriptToolExecution: Codable, Sendable, Equatable {
	public var stableExecutionID: String
	public var toolName: String?
	public var invocationID: UUID?
	public var argsJSON: String?
	public var resultJSON: String?
	public var toolIsError: Bool?
	public var status: AgentTranscriptToolStatus
	public var summaryOnly: Bool
	public var processID: String?
	public var exitCode: Int?
	public var summaryText: String?
	public var keyPaths: [String]

	public init(
		stableExecutionID: String,
		toolName: String?,
		invocationID: UUID?,
		argsJSON: String?,
		resultJSON: String?,
		toolIsError: Bool?,
		status: AgentTranscriptToolStatus,
		summaryOnly: Bool = false,
		processID: String? = nil,
		exitCode: Int? = nil,
		summaryText: String? = nil,
		keyPaths: [String] = []
	) {
		self.stableExecutionID = stableExecutionID
		self.toolName = toolName
		self.invocationID = invocationID
		self.argsJSON = argsJSON
		self.resultJSON = resultJSON
		self.toolIsError = toolIsError
		self.status = status
		self.summaryOnly = summaryOnly
		self.processID = processID
		self.exitCode = exitCode
		self.summaryText = summaryText
		self.keyPaths = keyPaths
	}
}

public struct AgentTranscriptActivity: Codable, Identifiable, Sendable, Equatable {
	public let id: UUID
	public var timestamp: Date
	public var sequenceIndex: Int
	public var role: AgentTranscriptActivityRole
	public var itemKind: AgentChatItemKind
	public var text: String
	public var attachments: [AgentImageAttachment]
	public var taggedFileAttachments: [AgentTaggedFileAttachment]
	public var workflow: AgentWorkflowDefinition?
	public var codexGoalMode: AgentCodexGoalModeMetadata?
	public var isLocalControlPlaneEcho: Bool?
	public var isStreaming: Bool
	public var toolExecution: AgentTranscriptToolExecution?
	public var reasoning: String?
	public var isSubstantiveAssistant: Bool
	public var sealsAssistantBoundary: Bool

	public init(
		id: UUID,
		timestamp: Date,
		sequenceIndex: Int,
		role: AgentTranscriptActivityRole,
		itemKind: AgentChatItemKind,
		text: String,
		attachments: [AgentImageAttachment] = [],
		taggedFileAttachments: [AgentTaggedFileAttachment] = [],
		workflow: AgentWorkflowDefinition? = nil,
		codexGoalMode: AgentCodexGoalModeMetadata? = nil,
		isLocalControlPlaneEcho: Bool? = nil,
		isStreaming: Bool = false,
		toolExecution: AgentTranscriptToolExecution? = nil,
		reasoning: String? = nil,
		isSubstantiveAssistant: Bool = false,
		sealsAssistantBoundary: Bool = false
	) {
		self.id = id
		self.timestamp = timestamp
		self.sequenceIndex = sequenceIndex
		self.role = role
		self.itemKind = itemKind
		self.text = text
		self.attachments = attachments
		self.taggedFileAttachments = taggedFileAttachments
		self.workflow = workflow
		self.codexGoalMode = codexGoalMode
		self.isLocalControlPlaneEcho = isLocalControlPlaneEcho
		self.isStreaming = isStreaming
		self.toolExecution = toolExecution
		self.reasoning = reasoning
		self.isSubstantiveAssistant = isSubstantiveAssistant
		self.sealsAssistantBoundary = sealsAssistantBoundary
	}

	public init(from item: AgentChatItem, toolExecution: AgentTranscriptToolExecution? = nil, role: AgentTranscriptActivityRole? = nil, sealsAssistantBoundary: Bool = false) {
		self.id = item.id
		self.timestamp = item.timestamp
		self.sequenceIndex = item.sequenceIndex
		self.role = role ?? Self.defaultRole(for: item)
		self.itemKind = item.kind
		self.text = item.text
		self.attachments = item.attachments
		self.taggedFileAttachments = item.taggedFileAttachments
		self.workflow = item.workflow
		self.codexGoalMode = item.codexGoalMode
		self.isLocalControlPlaneEcho = item.isLocalControlPlaneEcho ? true : nil
		self.isStreaming = item.isStreaming
		self.toolExecution = toolExecution
		self.reasoning = item.reasoning
		self.isSubstantiveAssistant = Self.defaultIsSubstantiveAssistant(for: item)
		self.sealsAssistantBoundary = sealsAssistantBoundary
	}

	public func toItem(text overrideText: String? = nil, isStreaming overrideStreaming: Bool? = nil) -> AgentChatItem {
		AgentChatItem(
			id: id,
			timestamp: timestamp,
			kind: itemKind,
			text: overrideText ?? text,
			attachments: attachments,
			taggedFileAttachments: taggedFileAttachments,
			toolName: toolExecution?.toolName,
			toolInvocationID: toolExecution?.invocationID,
			toolArgsJSON: toolExecution?.argsJSON,
			toolResultJSON: toolExecution?.resultJSON,
			toolIsError: toolExecution?.toolIsError,
			reasoning: reasoning,
			sequenceIndex: sequenceIndex,
			isStreaming: overrideStreaming ?? isStreaming,
			workflow: workflow,
			codexGoalMode: codexGoalMode,
			isLocalControlPlaneEcho: isLocalControlPlaneEcho ?? false
		)
	}

	private static func defaultRole(for item: AgentChatItem) -> AgentTranscriptActivityRole {
		switch item.kind {
		case .assistant, .assistantInline:
			return .assistant
		case .toolCall, .toolResult:
			return .toolExecution
		case .system:
			return .system
		case .error:
			return .error
		case .thinking:
			return .thinking
		case .user:
			return .note
		}
	}

	private static func defaultIsSubstantiveAssistant(for item: AgentChatItem) -> Bool {
		guard item.kind == .assistant || item.kind == .assistantInline else { return false }
		guard AgentDisplayableText.hasDisplayableBody(item.text) else { return false }
		let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
		if !item.attachments.isEmpty || !item.taggedFileAttachments.isEmpty || item.workflow != nil {
			return true
		}
		if trimmed.contains("\n") || trimmed.count >= 80 || trimmed.contains("```") {
			return true
		}
		let markdownHeavyMarkers = ["- ", "* ", "1. ", "## ", "### "]
		if markdownHeavyMarkers.contains(where: { trimmed.contains($0) }) {
			return true
		}
		let lowered = trimmed.lowercased()
		let lowSignalPrefixes = [
			"checking", "looking", "searching", "reading", "running", "thinking",
			"inspecting", "opening", "fetching", "planning", "using tool", "verifying",
			"validating", "confirming", "reviewing", "scanning", "probing", "trying",
			"applying", "editing", "updating"
		]
		if lowSignalPrefixes.contains(where: { lowered.hasPrefix($0) }) {
			return false
		}
		if let lastCharacter = trimmed.last, ".!?".contains(lastCharacter) {
			return true
		}
		if trimmed.contains(":") && trimmed.count >= 24 {
			return true
		}
		return false
	}
}

public struct AgentTranscriptRequestAnchor: Codable, Identifiable, Sendable, Equatable {
	public let id: UUID
	public var timestamp: Date
	public var sequenceIndex: Int
	public var text: String
	public var attachments: [AgentImageAttachment]
	public var taggedFileAttachments: [AgentTaggedFileAttachment]
	public var workflow: AgentWorkflowDefinition?
	public var codexGoalMode: AgentCodexGoalModeMetadata?
	public var isLocalControlPlaneEcho: Bool?

	public init(from item: AgentChatItem) {
		self.id = item.id
		self.timestamp = item.timestamp
		self.sequenceIndex = item.sequenceIndex
		self.text = item.text
		self.attachments = item.attachments
		self.taggedFileAttachments = item.taggedFileAttachments
		self.workflow = item.workflow
		self.codexGoalMode = item.codexGoalMode
		self.isLocalControlPlaneEcho = item.isLocalControlPlaneEcho ? true : nil
	}

	public func toItem() -> AgentChatItem {
		AgentChatItem(
			id: id,
			timestamp: timestamp,
			kind: .user,
			text: text,
			attachments: attachments,
			taggedFileAttachments: taggedFileAttachments,
			sequenceIndex: sequenceIndex,
			workflow: workflow,
			codexGoalMode: codexGoalMode,
			isLocalControlPlaneEcho: isLocalControlPlaneEcho ?? false
		)
	}
}

public struct AgentTranscriptTurnSummary: Codable, Sendable, Equatable {
	public var middleSummaryItemID: UUID
	public var requestText: String?
	public var conclusionText: String?
	public var compactConclusionText: String?
	public var middleSummaryText: String?
	public var toolCount: Int
	public var notableToolNames: [String]
	public var keyPaths: [String]
	public var compactedActivityCount: Int
	public var hadWarning: Bool
	public var hadError: Bool
	public var lastUserInteractionAt: Date?

	public init(
		middleSummaryItemID: UUID = UUID(),
		requestText: String?,
		conclusionText: String?,
		compactConclusionText: String?,
		middleSummaryText: String?,
		toolCount: Int,
		notableToolNames: [String],
		keyPaths: [String],
		compactedActivityCount: Int,
		hadWarning: Bool,
		hadError: Bool,
		lastUserInteractionAt: Date? = nil
	) {
		self.middleSummaryItemID = middleSummaryItemID
		self.requestText = requestText
		self.conclusionText = conclusionText
		self.compactConclusionText = compactConclusionText
		self.middleSummaryText = middleSummaryText
		self.toolCount = toolCount
		self.notableToolNames = notableToolNames
		self.keyPaths = keyPaths
		self.compactedActivityCount = compactedActivityCount
		self.hadWarning = hadWarning
		self.hadError = hadError
		self.lastUserInteractionAt = lastUserInteractionAt
	}
}

// Moved to core (transcript-core step 5): this cache is a stored property of the
// persisted `AgentTranscriptProviderResponseSpan`, so it is in the span's compile
// closure even though it is itself transient (excluded from CodingKeys). Access is
// widened to `public` so the app-side projection/compaction code that reads and
// writes `span.fullRenderGroupedHistoryCache` continues to compile across the
// package boundary.
public struct AgentTranscriptFullRenderGroupedHistoryCache: Sendable, Equatable {
	public let detailedToolTailLimit: Int
	public let collapseDigest: String
	public let summary: AgentTranscriptGroupedHistorySummary

	public init(
		detailedToolTailLimit: Int,
		collapseDigest: String,
		summary: AgentTranscriptGroupedHistorySummary
	) {
		self.detailedToolTailLimit = detailedToolTailLimit
		self.collapseDigest = collapseDigest
		self.summary = summary
	}
}

public struct AgentTranscriptProviderResponseSpan: Codable, Identifiable, Sendable, Equatable {
	public let id: UUID
	public var providerTurnID: String?
	public var runID: UUID?
	public var lifecycle: AgentTranscriptSpanLifecycle
	public var startedAt: Date
	public var lastActivityAt: Date?
	public var completedAt: Date?
	public var activities: [AgentTranscriptActivity]
	/// Durable for compacted turns; rebuildable cache for full turns.
	public var collapsedSummary: AgentTranscriptGroupedHistorySummary?
	/// Transient in-memory cache for completed full-turn grouped-history rendering.
	public var fullRenderGroupedHistoryCache: AgentTranscriptFullRenderGroupedHistoryCache?

	public init(
		id: UUID = UUID(),
		providerTurnID: String? = nil,
		runID: UUID? = nil,
		lifecycle: AgentTranscriptSpanLifecycle = .open,
		startedAt: Date,
		lastActivityAt: Date? = nil,
		completedAt: Date? = nil,
		activities: [AgentTranscriptActivity] = [],
		collapsedSummary: AgentTranscriptGroupedHistorySummary? = nil
	) {
		self.id = id
		self.providerTurnID = providerTurnID
		self.runID = runID
		self.lifecycle = lifecycle
		self.startedAt = startedAt
		self.lastActivityAt = lastActivityAt
		self.completedAt = completedAt
		self.activities = activities
		self.collapsedSummary = collapsedSummary
		self.fullRenderGroupedHistoryCache = nil
	}

	enum CodingKeys: String, CodingKey {
		case id
		case providerTurnID
		case runID
		case lifecycle
		case startedAt
		case lastActivityAt
		case completedAt
		case activities
		case collapsedSummary
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		providerTurnID = try container.decodeIfPresent(String.self, forKey: .providerTurnID)
		runID = try container.decodeIfPresent(UUID.self, forKey: .runID)
		lifecycle = try container.decode(AgentTranscriptSpanLifecycle.self, forKey: .lifecycle)
		startedAt = try container.decode(Date.self, forKey: .startedAt)
		lastActivityAt = try container.decodeIfPresent(Date.self, forKey: .lastActivityAt)
		completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
		activities = try container.decodeIfPresent([AgentTranscriptActivity].self, forKey: .activities) ?? []
		collapsedSummary = try container.decodeIfPresent(AgentTranscriptGroupedHistorySummary.self, forKey: .collapsedSummary)
		fullRenderGroupedHistoryCache = nil
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(id, forKey: .id)
		try container.encodeIfPresent(providerTurnID, forKey: .providerTurnID)
		try container.encodeIfPresent(runID, forKey: .runID)
		try container.encode(lifecycle, forKey: .lifecycle)
		try container.encode(startedAt, forKey: .startedAt)
		try container.encodeIfPresent(lastActivityAt, forKey: .lastActivityAt)
		try container.encodeIfPresent(completedAt, forKey: .completedAt)
		try container.encode(activities, forKey: .activities)
		try container.encodeIfPresent(collapsedSummary, forKey: .collapsedSummary)
	}

	public static func == (lhs: AgentTranscriptProviderResponseSpan, rhs: AgentTranscriptProviderResponseSpan) -> Bool {
		lhs.id == rhs.id
			&& lhs.providerTurnID == rhs.providerTurnID
			&& lhs.runID == rhs.runID
			&& lhs.lifecycle == rhs.lifecycle
			&& lhs.startedAt == rhs.startedAt
			&& lhs.lastActivityAt == rhs.lastActivityAt
			&& lhs.completedAt == rhs.completedAt
			&& lhs.activities == rhs.activities
			&& lhs.collapsedSummary == rhs.collapsedSummary
	}

	public var hasStoredActivities: Bool {
		!activities.isEmpty
	}
}

public struct AgentTranscriptTurn: Codable, Identifiable, Sendable, Equatable {
	public let id: UUID
	public var request: AgentTranscriptRequestAnchor?
	public var responseSpans: [AgentTranscriptProviderResponseSpan]
	public var conclusionActivityID: UUID?
	public var retentionTier: AgentTranscriptRetentionTier
	/// Durable for non-full turns; rebuildable cache for full turns.
	public var summary: AgentTranscriptTurnSummary?
	public var terminalState: AgentSessionRunState?
	public var startedAt: Date
	public var lastActivityAt: Date?
	public var completedAt: Date?
	/// Durable visibility cap for completed full turns whose tool history collapsed.
	/// `nil` means no cap was needed; frozen caps limit this turn but do not reserve global tail budget.
	public var frozenDetailedToolTailLimit: Int?

	public init(
		id: UUID = UUID(),
		request: AgentTranscriptRequestAnchor? = nil,
		responseSpans: [AgentTranscriptProviderResponseSpan] = [],
		conclusionActivityID: UUID? = nil,
		retentionTier: AgentTranscriptRetentionTier = .full,
		summary: AgentTranscriptTurnSummary? = nil,
		terminalState: AgentSessionRunState? = nil,
		startedAt: Date,
		lastActivityAt: Date? = nil,
		completedAt: Date? = nil,
		frozenDetailedToolTailLimit: Int? = nil
	) {
		self.id = id
		self.request = request
		self.responseSpans = responseSpans
		self.conclusionActivityID = conclusionActivityID
		self.retentionTier = retentionTier
		self.summary = summary
		self.terminalState = terminalState
		self.startedAt = startedAt
		self.lastActivityAt = lastActivityAt
		self.completedAt = completedAt
		self.frozenDetailedToolTailLimit = frozenDetailedToolTailLimit
	}

	enum CodingKeys: String, CodingKey {
		case id
		case request
		case responseSpans
		case conclusionActivityID
		case retentionTier
		case summary
		case terminalState
		case startedAt
		case lastActivityAt
		case completedAt
		case frozenDetailedToolTailLimit
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		id = try container.decode(UUID.self, forKey: .id)
		request = try container.decodeIfPresent(AgentTranscriptRequestAnchor.self, forKey: .request)
		responseSpans = try container.decodeIfPresent([AgentTranscriptProviderResponseSpan].self, forKey: .responseSpans) ?? []
		conclusionActivityID = try container.decodeIfPresent(UUID.self, forKey: .conclusionActivityID)
		retentionTier = try container.decode(AgentTranscriptRetentionTier.self, forKey: .retentionTier)
		summary = try container.decodeIfPresent(AgentTranscriptTurnSummary.self, forKey: .summary)
		terminalState = try container.decodeIfPresent(AgentSessionRunState.self, forKey: .terminalState)
		startedAt = try container.decode(Date.self, forKey: .startedAt)
		lastActivityAt = try container.decodeIfPresent(Date.self, forKey: .lastActivityAt)
		completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
		frozenDetailedToolTailLimit = try container.decodeIfPresent(Int.self, forKey: .frozenDetailedToolTailLimit)
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(id, forKey: .id)
		try container.encodeIfPresent(request, forKey: .request)
		try container.encode(responseSpans, forKey: .responseSpans)
		try container.encodeIfPresent(conclusionActivityID, forKey: .conclusionActivityID)
		try container.encode(retentionTier, forKey: .retentionTier)
		try container.encodeIfPresent(summary, forKey: .summary)
		try container.encodeIfPresent(terminalState, forKey: .terminalState)
		try container.encode(startedAt, forKey: .startedAt)
		try container.encodeIfPresent(lastActivityAt, forKey: .lastActivityAt)
		try container.encodeIfPresent(completedAt, forKey: .completedAt)
		try container.encodeIfPresent(frozenDetailedToolTailLimit, forKey: .frozenDetailedToolTailLimit)
	}

	public var isCompleted: Bool {
		completedAt != nil || !(terminalState?.isActive ?? false)
	}

	public var allActivities: [AgentTranscriptActivity] {
		responseSpans.flatMap(\.activities).sorted { lhs, rhs in
			if lhs.sequenceIndex == rhs.sequenceIndex {
				return lhs.timestamp < rhs.timestamp
			}
			return lhs.sequenceIndex < rhs.sequenceIndex
		}
	}

	public var hasStoredActivities: Bool {
		responseSpans.contains(where: { !$0.activities.isEmpty })
	}

	public var isStructurallyCompacted: Bool {
		retentionTier != .full && !hasStoredActivities
	}
}

public struct AgentTranscriptCompactionFrontier: Codable, Sendable, Equatable {
	public var version: Int
	public var frozenPrefixTurnCount: Int
	public var lastFrozenTurnID: UUID

	public init(version: Int = 1, frozenPrefixTurnCount: Int, lastFrozenTurnID: UUID) {
		self.version = version
		self.frozenPrefixTurnCount = frozenPrefixTurnCount
		self.lastFrozenTurnID = lastFrozenTurnID
	}
}

public struct AgentTranscript: Codable, Sendable, Equatable {
	public var version: Int
	public var turns: [AgentTranscriptTurn]
	public var nextSequenceIndex: Int
	public var compactionFrontier: AgentTranscriptCompactionFrontier?

	public init(
		version: Int = 3,
		turns: [AgentTranscriptTurn] = [],
		nextSequenceIndex: Int = 0,
		compactionFrontier: AgentTranscriptCompactionFrontier? = nil
	) {
		self.version = version
		self.turns = turns
		self.nextSequenceIndex = nextSequenceIndex
		self.compactionFrontier = compactionFrontier
	}

	public static let empty = AgentTranscript()

	public var allActivities: [AgentTranscriptActivity] {
		turns.flatMap(\.allActivities).sorted { lhs, rhs in
			if lhs.sequenceIndex == rhs.sequenceIndex {
				return lhs.timestamp < rhs.timestamp
			}
			return lhs.sequenceIndex < rhs.sequenceIndex
		}
	}
}

public enum AgentTranscriptCollapsedSummaryStatus: String, Codable, Sendable, Equatable {
	case neutral
	case running
	case warning
	case failure
}

public struct AgentTranscriptCollapsedSummaryDisplay: Codable, Sendable, Equatable {
	public let title: String
	public let count: Int?
	public let detailText: String?
	/// Narration text (assistant message excerpt), shown on the detail row when present.
	public let narrationText: String?
	/// Tool group chip text (e.g. "Read File ×11, Edit ×2"), shown on the title row when narration is present.
	public let toolGroupText: String?
	public let status: AgentTranscriptCollapsedSummaryStatus

	public init(
		title: String,
		count: Int? = nil,
		detailText: String? = nil,
		narrationText: String? = nil,
		toolGroupText: String? = nil,
		status: AgentTranscriptCollapsedSummaryStatus = .neutral
	) {
		self.title = title
		self.count = count
		self.detailText = detailText
		self.narrationText = narrationText
		self.toolGroupText = toolGroupText
		self.status = status
	}
}

/// Pre-computed tool group for display in collapsed cluster cards.
/// Built once in the service layer so the view doesn't need to recompute.
public struct ClusterToolGroup: Codable, Sendable, Equatable {
	public let icon: String
	public let label: String

	public init(icon: String, label: String) {
		self.icon = icon
		self.label = label
	}
}

public struct AgentTranscriptClusterSummary: Codable, Sendable, Equatable {
	public let toolCount: Int
	public let toolNames: [String]
	public let toolNameCounts: [String: Int]
	/// Pre-computed grouped chips (Navigation ×4, Edit ×2, etc.) — ready for direct rendering.
	public let toolGroups: [ClusterToolGroup]
	public let keyPaths: [String]
	public let containsRunningWork: Bool
	public let containsFailure: Bool
	public let containsWarning: Bool
	public let shortNarration: String?
	public let collapsedDisplay: AgentTranscriptCollapsedSummaryDisplay?

	public init(
		toolCount: Int,
		toolNames: [String],
		toolNameCounts: [String: Int] = [:],
		toolGroups: [ClusterToolGroup] = [],
		keyPaths: [String],
		containsRunningWork: Bool,
		containsFailure: Bool,
		containsWarning: Bool,
		shortNarration: String?,
		collapsedDisplay: AgentTranscriptCollapsedSummaryDisplay? = nil
	) {
		self.toolCount = toolCount
		self.toolNames = toolNames
		self.toolNameCounts = toolNameCounts
		self.toolGroups = toolGroups
		self.keyPaths = keyPaths
		self.containsRunningWork = containsRunningWork
		self.containsFailure = containsFailure
		self.containsWarning = containsWarning
		self.shortNarration = shortNarration
		self.collapsedDisplay = collapsedDisplay
	}
}

public struct AgentTranscriptGroupedHistorySummary: Codable, Sendable, Equatable {
	public let hiddenToolCardCount: Int
	public let hiddenAssistantCount: Int
	public let hiddenProgressCount: Int
	public let hiddenNoteCount: Int
	public let toolSummary: AgentTranscriptClusterSummary?
	public let collapsedDisplay: AgentTranscriptCollapsedSummaryDisplay?

	public init(
		hiddenToolCardCount: Int,
		hiddenAssistantCount: Int,
		hiddenProgressCount: Int,
		hiddenNoteCount: Int,
		toolSummary: AgentTranscriptClusterSummary?,
		collapsedDisplay: AgentTranscriptCollapsedSummaryDisplay? = nil
	) {
		self.hiddenToolCardCount = hiddenToolCardCount
		self.hiddenAssistantCount = hiddenAssistantCount
		self.hiddenProgressCount = hiddenProgressCount
		self.hiddenNoteCount = hiddenNoteCount
		self.toolSummary = toolSummary
		self.collapsedDisplay = collapsedDisplay
	}
}

public struct AgentTranscriptProjectionCounts: Codable, Sendable, Equatable {
	public let canonicalVisibleRowCount: Int
	public let defaultPresentedRowCount: Int

	public var hiddenArchivedRowCount: Int {
		max(0, canonicalVisibleRowCount - defaultPresentedRowCount)
	}

	public init(
		canonicalVisibleRowCount: Int = 0,
		defaultPresentedRowCount: Int = 0
	) {
		self.canonicalVisibleRowCount = max(0, canonicalVisibleRowCount)
		self.defaultPresentedRowCount = max(0, min(defaultPresentedRowCount, self.canonicalVisibleRowCount))
	}

	public static let zero = AgentTranscriptProjectionCounts()
}
