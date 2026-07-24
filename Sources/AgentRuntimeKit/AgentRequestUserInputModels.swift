import Foundation

// Codex request-user-input model family, moved from the app's
// UserInteractionModels.swift (2026-07-17). Stable identity derives from the
// module's shared StableUserInteractionIdentity (AgentAskUserModels.swift);
// the app-side duplicate implementation was deliberately not preserved.

public struct AgentRequestUserInputOption: Sendable, Hashable {
	public let label: String
	public let description: String

	public init(label: String, description: String) {
		self.label = label
		self.description = description
	}
}

public struct AgentRequestUserInputQuestion: Sendable, Hashable {
	public static let otherOptionLabel = "None of the above"

	public let id: String
	public let header: String
	public let question: String
	public let isOther: Bool
	public let isSecret: Bool
	public let options: [AgentRequestUserInputOption]

	public init(
		id: String,
		header: String,
		question: String,
		isOther: Bool,
		isSecret: Bool,
		options: [AgentRequestUserInputOption]
	) {
		self.id = id
		self.header = header
		self.question = question
		self.isOther = isOther
		self.isSecret = isSecret
		self.options = options
	}

	public var isOtherOptionEnabled: Bool {
		isOther && !options.isEmpty
	}
}

public struct AgentRequestUserInputQuestionDraft: Sendable, Hashable {
	public var selectedOptionIndex: Int?
	public var note: String

	public init(selectedOptionIndex: Int? = nil, note: String = "") {
		self.selectedOptionIndex = selectedOptionIndex
		self.note = note
	}
}

public struct AgentRequestUserInputResponse: Sendable, Hashable {
	public let answersByQuestionID: [String: [String]]

	public init(answersByQuestionID: [String: [String]]) {
		self.answersByQuestionID = answersByQuestionID
	}

	public var jsonObject: [String: Any] {
		let answers = answersByQuestionID.reduce(into: [String: [String: Any]]()) { partialResult, entry in
			partialResult[entry.key] = ["answers": entry.value]
		}
		return ["answers": answers]
	}
}

public struct AgentRequestUserInputRequest: Identifiable, Sendable, Hashable {
	public let id: UUID
	public let requestID: CodexAppServerRequestID
	public let method: String
	public let threadID: String
	public let turnID: String
	public let itemID: String
	public let askedAt: Date
	public let questions: [AgentRequestUserInputQuestion]

	public init(
		id: UUID? = nil,
		requestID: CodexAppServerRequestID,
		method: String,
		threadID: String,
		turnID: String,
		itemID: String,
		askedAt: Date = Date(),
		questions: [AgentRequestUserInputQuestion]
	) {
		self.id = id ?? Self.stableID(
			requestID: requestID,
			method: method,
			threadID: threadID,
			turnID: turnID,
			itemID: itemID
		)
		self.requestID = requestID
		self.method = method
		self.threadID = threadID
		self.turnID = turnID
		self.itemID = itemID
		self.askedAt = askedAt
		self.questions = questions
	}

	public static func stableID(
		requestID: CodexAppServerRequestID,
		method: String,
		threadID: String,
		turnID: String,
		itemID: String
	) -> UUID {
		StableUserInteractionIdentity.uuid(
			from: "request-user-input|\(requestID.displayValue)|\(method)|\(threadID)|\(turnID)|\(itemID)"
		)
	}

	public func buildResponse(from drafts: [String: AgentRequestUserInputQuestionDraft]) -> AgentRequestUserInputResponse {
		let answers = questions.reduce(into: [String: [String]]()) { partialResult, question in
			let draft = drafts[question.id]
			let trimmedNote = draft?.note.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
			var questionAnswers: [String] = []

			if let selectedIndex = draft?.selectedOptionIndex {
				if selectedIndex >= 0 && selectedIndex < question.options.count {
					questionAnswers.append(question.options[selectedIndex].label)
				} else if selectedIndex == question.options.count, question.isOtherOptionEnabled {
					questionAnswers.append(AgentRequestUserInputQuestion.otherOptionLabel)
				}
			}

			if !trimmedNote.isEmpty {
				questionAnswers.append("user_note: \(trimmedNote)")
			}

			partialResult[question.id] = questionAnswers
		}
		return AgentRequestUserInputResponse(answersByQuestionID: answers)
	}
}
