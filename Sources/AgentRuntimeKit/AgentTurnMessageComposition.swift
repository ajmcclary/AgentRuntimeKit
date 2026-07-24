import Foundation

/// Neutral turn-message composition policies promoted to AgentRuntimeCore
/// (turn-preparation slice 1). Bodies verbatim from the facade's
/// `composeInitialThreadMessage`, `composeSessionHandoffPayload`,
/// `composeClaudeResumeRecoveryHandoffPayload`, `escapePromptXMLAttribute`,
/// and `renderSlashSkillUserInstructions`.
public enum AgentTurnMessageComposition {
	public static func composeInitialThreadMessage(
		initialMessage: String,
		fileTree: String,
		promptText: String?
	) -> String {
		let trimmedTree = fileTree.trimmingCharacters(in: .whitespacesAndNewlines)
		let trimmedPrompt = promptText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
		let trimmedInstruction = initialMessage.trimmingCharacters(in: .whitespacesAndNewlines)
		var contextSections: [String] = []
		if !trimmedTree.isEmpty {
			contextSections.append("""
<file_map>
\(trimmedTree)
</file_map>
""")
		}
		if !trimmedPrompt.isEmpty {
			contextSections.append("""
<current_prompt_content>
\(trimmedPrompt)
</current_prompt_content>
""")
		}
		guard !contextSections.isEmpty else { return initialMessage }
		guard !trimmedInstruction.isEmpty else {
			return contextSections.joined(separator: "\n\n")
		}
		return [initialMessage, contextSections.joined(separator: "\n\n")].joined(separator: "\n\n")
	}

	public static func composeClaudeResumeRecoveryHandoffPayload(
		sourceTabName: String,
		sourceAgentName: String,
		transcriptXML: String,
		initialThreadContextBlock: String?,
		deliveryID: String
	) -> String {
		let trimmedTranscriptXML = transcriptXML.trimmingCharacters(in: .whitespacesAndNewlines)
		let trimmedInitialThreadContextBlock = initialThreadContextBlock?
			.trimmingCharacters(in: .whitespacesAndNewlines)

		var payloadSections: [String] = []
		if let trimmedInitialThreadContextBlock,
			!trimmedInitialThreadContextBlock.isEmpty {
			payloadSections.append(
				"""
				<original_thread_context>
				\(trimmedInitialThreadContextBlock)
				</original_thread_context>
				"""
			)
		}
		if !trimmedTranscriptXML.isEmpty {
			payloadSections.append(trimmedTranscriptXML)
		}

		let payloadBody = payloadSections.joined(separator: "\n\n")
		return """
		<forked_session source="\(sourceTabName)" delivery_id="\(deliveryID)">
		You are continuing a session that was restarted after a native resume failed for \(sourceAgentName). Use the recovered transcript below, plus any preserved thread context, to continue seamlessly. The delivery_id identifies this handoff; if this payload appears again, treat it as a duplicate resend and do not re-apply it.

		\(payloadBody)
		</forked_session>
		"""
	}

	public static func composeSessionHandoffPayload(
		sourceTabName: String,
		sourceAgentName: String,
		sourceModelName: String,
		fileContentsBlock: String?,
		transcriptXML: String,
		deliveryID: String
	) -> String {
		let trimmedFileContentsBlock = fileContentsBlock?
			.trimmingCharacters(in: .whitespacesAndNewlines)
		let trimmedTranscriptXML = transcriptXML.trimmingCharacters(in: .whitespacesAndNewlines)

		var payloadSections: [String] = []
		if let trimmedFileContentsBlock,
			!trimmedFileContentsBlock.isEmpty {
			payloadSections.append(trimmedFileContentsBlock)
		}
		if !trimmedTranscriptXML.isEmpty {
			payloadSections.append(trimmedTranscriptXML)
		}

		let payloadBody = payloadSections.joined(separator: "\n\n")
		return """
		<forked_session source="\(sourceTabName)" delivery_id="\(deliveryID)">
		You are continuing a session started with \(sourceAgentName) (\(sourceModelName)). Below is a snapshot of the file system state analyzed by that agent, along with the exchange made with the user up until this point. The delivery_id identifies this handoff; if this payload appears again, treat it as a duplicate resend and do not re-apply it.

		\(payloadBody)
		</forked_session>
		"""
	}

	public static func escapePromptXMLAttribute(_ text: String) -> String {
		text
			.replacingOccurrences(of: "&", with: "&amp;")
			.replacingOccurrences(of: "\"", with: "&quot;")
			.replacingOccurrences(of: "<", with: "&lt;")
			.replacingOccurrences(of: ">", with: "&gt;")
	}

	public static func renderSlashSkillUserInstructions(_ argsText: String) -> String {
		let trimmedArgs = argsText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedArgs.isEmpty else {
			return ""
		}
		return """
		<user_instructions>
		\(trimmedArgs)
		</user_instructions>
		"""
	}
}
