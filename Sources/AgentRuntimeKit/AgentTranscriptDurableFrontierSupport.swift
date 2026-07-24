import Foundation

/// Durable compaction-frontier support promoted from the app-side
/// `AgentTranscriptIO.swift` (2026-07-16 transcript text-extraction tranche).
/// Bodies are byte-verbatim; only the `public` widenings are new. Keeping the
/// name stable lets its `AgentTranscriptIO`/`AgentTranscriptCompaction` callers
/// resolve via the `@_exported` umbrella with zero edits.
public enum AgentTranscriptDurableFrontierSupport {
	public static let supportedVersion = 1

	public static func establishedFrontier(for transcript: AgentTranscript) -> AgentTranscriptCompactionFrontier? {
		let frozenPrefix = transcript.turns.prefix { $0.retentionTier != .full }
		guard let lastFrozenTurn = frozenPrefix.last else { return nil }
		return AgentTranscriptCompactionFrontier(
			version: supportedVersion,
			frozenPrefixTurnCount: frozenPrefix.count,
			lastFrozenTurnID: lastFrozenTurn.id
		)
	}

	public static func normalizedTranscript(_ transcript: AgentTranscript) -> AgentTranscript {
		var normalized = transcript
		normalized.compactionFrontier = establishedFrontier(for: transcript)
		return normalized
	}

	public static func validatedFrozenPrefixTurnCountForIncrementalReuse(in transcript: AgentTranscript) -> Int? {
		guard !transcript.turns.isEmpty else { return nil }
		guard let frontier = transcript.compactionFrontier else {
			return transcript.turns.dropLast().allSatisfy({ $0.retentionTier == .full }) ? 0 : nil
		}
		let frozenPrefixTurnCount = frontier.frozenPrefixTurnCount
		guard frontier.version == supportedVersion,
			frozenPrefixTurnCount > 0,
			frozenPrefixTurnCount < transcript.turns.count,
			transcript.turns.indices.contains(frozenPrefixTurnCount - 1),
			transcript.turns[frozenPrefixTurnCount - 1].id == frontier.lastFrozenTurnID,
			transcript.turns.prefix(frozenPrefixTurnCount).allSatisfy({ $0.retentionTier != .full }),
			transcript.turns.dropFirst(frozenPrefixTurnCount).dropLast().allSatisfy({ $0.retentionTier == .full })
		else {
			return nil
		}
		return frozenPrefixTurnCount
	}
}
