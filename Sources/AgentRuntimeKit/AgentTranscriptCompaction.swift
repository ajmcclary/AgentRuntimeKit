import Foundation

/// Neutral transcript compaction mode promoted to AgentRuntimeCore (transcript-core step 6).
/// Its compile closure is Foundation-only, so it is package-owned. `AgentTranscriptCompactor`
/// remains app-side (blocked on IO/Projection/visibility/instrumentation helpers).
public enum AgentTranscriptCompactionMode: Sendable, Equatable {
	case recomputeAll
	case preserveDurableFrontier
}
