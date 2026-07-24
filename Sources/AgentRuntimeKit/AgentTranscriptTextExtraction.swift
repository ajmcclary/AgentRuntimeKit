import Foundation

/// Package-clean preview/error text extractors promoted from the app-side
/// `AgentTranscriptIO` (2026-07-16 transcript text-extraction tranche). Bodies
/// are byte-verbatim; only the namespace declaration and `public` widenings are new.
public enum AgentTranscriptTextExtraction {
	public static func flattenFullTranscript(_ transcript: AgentTranscript) -> [AgentChatItem] {
		var rows: [AgentChatItem] = []
		for turn in transcript.turns {
			if let request = turn.request {
				rows.append(request.toItem())
			}
			rows.append(contentsOf: turn.allActivities.map { $0.toItem() })
		}
		return rows.sorted { lhs, rhs in
			if lhs.sequenceIndex == rhs.sequenceIndex {
				return lhs.timestamp < rhs.timestamp
			}
			return lhs.sequenceIndex < rhs.sequenceIndex
		}
	}

	public static func latestAssistantPreviewText(from transcript: AgentTranscript) -> String? {
		for turn in transcript.turns.reversed() {
			if let text = latestAssistantPreviewText(in: turn) {
				return text
			}
		}
		return nil
	}

	/// Extract assistant preview text from a single turn.
	public static func latestAssistantPreviewText(in turn: AgentTranscriptTurn) -> String? {
		if let activity = conclusionActivity(in: turn),
			AgentDisplayableText.hasDisplayableBody(activity.text) {
			return activity.text.trimmingCharacters(in: .whitespacesAndNewlines)
		}
		for activity in turn.allActivities.reversed() where (activity.itemKind == .assistant || activity.itemKind == .assistantInline) && AgentDisplayableText.hasDisplayableBody(activity.text) {
			return activity.text.trimmingCharacters(in: .whitespacesAndNewlines)
		}
		return nil
	}

	/// Extract the latest error text from the transcript.
	public static func latestErrorText(from transcript: AgentTranscript, latestTurnOnly: Bool) -> String? {
		let turns = latestTurnOnly ? transcript.turns.suffix(1) : transcript.turns[...]
		for turn in turns.reversed() {
			for activity in turn.allActivities.reversed() where activity.itemKind == .error {
				let trimmed = activity.text.trimmingCharacters(in: .whitespacesAndNewlines)
				if !trimmed.isEmpty {
					return trimmed
				}
			}
		}
		return nil
	}

	// Widened from `private` (was `AgentTranscriptIO.conclusionActivity`) — retains an
	// app-side caller at `AgentTranscriptIO.swift` (buildSummary), which now qualifies it.
	public static func conclusionActivity(in turn: AgentTranscriptTurn) -> AgentTranscriptActivity? {
		guard let conclusionActivityID = turn.conclusionActivityID else { return nil }
		return turn.allActivities.first(where: { $0.id == conclusionActivityID })
	}
}
