import Foundation

/// Neutral transcript import policy promoted to AgentRuntimeCore (transcript-core step 6).
/// Its compile closure is Foundation-only, so it is package-owned. `AgentTranscriptSummaryTextFormatter`
/// remains app-side (blocked on `ClusterToolCategory`).
public struct AgentTranscriptImportPolicy: Sendable, Equatable {
	public var hideAlwaysHiddenTools: Bool
	public var hidePendingQuestionToolCall: Bool

	public init(
		hideAlwaysHiddenTools: Bool = true,
		hidePendingQuestionToolCall: Bool = false
	) {
		self.hideAlwaysHiddenTools = hideAlwaysHiddenTools
		self.hidePendingQuestionToolCall = hidePendingQuestionToolCall
	}

	public static let canonical = AgentTranscriptImportPolicy()

	public static func liveSession(hidePendingQuestionToolCall: Bool) -> AgentTranscriptImportPolicy {
		AgentTranscriptImportPolicy(
			hideAlwaysHiddenTools: true,
			hidePendingQuestionToolCall: hidePendingQuestionToolCall
		)
	}
}
