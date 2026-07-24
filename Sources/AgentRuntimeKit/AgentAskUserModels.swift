import Foundation
import CryptoKit

enum StableUserInteractionIdentity {
	static func uuid(from seed: String) -> UUID {
		let digest = Array(SHA256.hash(data: Data(seed.utf8)))
		let bytes: uuid_t = (
			digest[0], digest[1], digest[2], digest[3],
			digest[4], digest[5], digest[6], digest[7],
			digest[8], digest[9], digest[10], digest[11],
			digest[12], digest[13], digest[14], digest[15]
		)
		return UUID(uuid: bytes)
	}
}

public enum AgentAskUserValidationError: LocalizedError, Sendable, Equatable {
	case emptyQuestions
	case blankQuestionID(index: Int)
	case duplicateQuestionID(String)
	case blankQuestionText(id: String)
	case duplicateOptionLabel(questionID: String, label: String)
	case impossibleQuestion(questionID: String)
	case incompleteQuestion(String)
	case invalidSingleSelectAnswer(questionID: String)
	case invalidCustomAnswer(questionID: String)
	case unknownQuestionID(id: String, validIDs: [String])

	public var errorDescription: String? {
		switch self {
		case .emptyQuestions:
			return "ask_user requires at least one question."
		case .blankQuestionID(let index):
			return "ask_user question at index \(index) has a blank id."
		case .duplicateQuestionID(let id):
			return "ask_user question id '\(id)' is duplicated."
		case .blankQuestionText(let id):
			return "ask_user question '\(id)' has blank question text."
		case .duplicateOptionLabel(let questionID, let label):
			return "ask_user question '\(questionID)' has duplicate option label '\(label)'."
		case .impossibleQuestion(let questionID):
			return "ask_user question '\(questionID)' has no options and does not allow custom responses."
		case .incompleteQuestion(let questionID):
			return "ask_user question '\(questionID)' must be answered or skipped before submitting."
		case .invalidSingleSelectAnswer(let questionID):
			return "ask_user question '\(questionID)' accepts only one selected option or one custom response."
		case .invalidCustomAnswer(let questionID):
			return "ask_user question '\(questionID)' has an invalid custom response. Custom responses must be allowed and only one custom response may be provided."
		case .unknownQuestionID(let id, let validIDs):
			return "ask_user answer references unknown question_id '\(id)'. Known IDs: \(validIDs.joined(separator: ", "))."
		}
	}
}

public struct AgentAskUserOption: Sendable, Hashable {
	public let label: String
	public let description: String?

	public init(label: String, description: String? = nil) {
		self.label = label
		self.description = description
	}
}

public struct AgentAskUserQuestion: Sendable, Hashable {
	public let id: String
	public let header: String?
	public let question: String
	public let context: String?
	public let options: [AgentAskUserOption]
	public let allowsMultiple: Bool
	public let allowsCustom: Bool

	public init(
		id: String,
		header: String? = nil,
		question: String,
		context: String? = nil,
		options: [AgentAskUserOption] = [],
		allowsMultiple: Bool = false,
		allowsCustom: Bool = true
	) {
		self.id = id
		self.header = header
		self.question = question
		self.context = context
		self.options = options
		self.allowsMultiple = allowsMultiple
		self.allowsCustom = allowsCustom
	}

	public var optionLabels: [String] {
		options.map(\.label)
	}

	public func orderedSelectedOptions(from draft: AgentAskUserDraft) -> [String] {
		let selected = Set(draft.selectedOptionLabels)
		return optionLabels.filter { selected.contains($0) }
	}

	public func answer(from draft: AgentAskUserDraft) -> AgentAskUserAnswer {
		if draft.skipped {
			return AgentAskUserAnswer(answers: [], selectedOptions: [], customResponse: nil, skipped: true)
		}

		var selectedOptions = orderedSelectedOptions(from: draft)
		let trimmedCustom = allowsCustom
			? draft.customResponse.trimmingCharacters(in: .whitespacesAndNewlines)
			: ""
		let customResponse = trimmedCustom.isEmpty ? nil : trimmedCustom

		if !allowsMultiple, customResponse != nil {
			selectedOptions = []
		}

		var answers = selectedOptions
		if let customResponse {
			answers.append(customResponse)
		}
		return AgentAskUserAnswer(
			answers: answers,
			selectedOptions: selectedOptions,
			customResponse: customResponse,
			skipped: false
		)
	}

	public func validate(_ answer: AgentAskUserAnswer) throws {
		guard allowsMultiple || answer.answers.count <= 1 else {
			throw AgentAskUserValidationError.invalidSingleSelectAnswer(questionID: id)
		}
	}
}

public struct AgentAskUserDraft: Sendable, Hashable {
	public var selectedOptionLabels: [String]
	public var customResponse: String
	public var skipped: Bool

	public init(
		selectedOptionLabels: [String] = [],
		customResponse: String = "",
		skipped: Bool = false
	) {
		self.selectedOptionLabels = selectedOptionLabels
		self.customResponse = customResponse
		self.skipped = skipped
	}

	public var hasContent: Bool {
		skipped
			|| !selectedOptionLabels.isEmpty
			|| !customResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}
}

public struct AgentAskUserAnswer: Sendable, Hashable {
	public let answers: [String]
	public let selectedOptions: [String]
	public let customResponse: String?
	public let skipped: Bool

	public init(
		answers: [String],
		selectedOptions: [String],
		customResponse: String?,
		skipped: Bool
	) {
		self.answers = answers
		self.selectedOptions = selectedOptions
		self.customResponse = customResponse
		self.skipped = skipped
	}

	public var jsonObject: [String: Any] {
		[
			"answers": answers,
			"selected_options": selectedOptions,
			"custom_response": customResponse ?? NSNull(),
			"skipped": skipped
		]
	}
}

public struct AgentAskUserResponse: Sendable, Hashable {
	public let answersByQuestionID: [String: AgentAskUserAnswer]
	public let timedOut: Bool
	public let skipped: Bool
	public let elapsedSeconds: Int

	public init(
		answersByQuestionID: [String: AgentAskUserAnswer],
		timedOut: Bool,
		skipped: Bool,
		elapsedSeconds: Int
	) {
		self.answersByQuestionID = answersByQuestionID
		self.timedOut = timedOut
		self.skipped = skipped
		self.elapsedSeconds = elapsedSeconds
	}

	public var jsonObject: [String: Any] {
		[
			"answers": answersByQuestionID.reduce(into: [String: [String: Any]]()) { partialResult, entry in
				partialResult[entry.key] = entry.value.jsonObject
			},
			"timed_out": timedOut,
			"skipped": skipped,
			"elapsed_seconds": elapsedSeconds
		]
	}
}

public struct AgentAskUserInteraction: Identifiable, Sendable, Hashable {
	public let id: UUID
	public let title: String?
	public let context: String?
	public let timeoutSeconds: TimeInterval
	public let askedAt: Date
	public let questions: [AgentAskUserQuestion]

	public init(
		id: UUID = UUID(),
		title: String? = nil,
		context: String? = nil,
		timeoutSeconds: TimeInterval = 300,
		askedAt: Date = Date(),
		questions: [AgentAskUserQuestion]
	) {
		self.id = id
		self.title = title
		self.context = context
		self.timeoutSeconds = timeoutSeconds
		self.askedAt = askedAt
		self.questions = questions
	}

	public func validate() throws {
		guard !questions.isEmpty else {
			throw AgentAskUserValidationError.emptyQuestions
		}
		var seenIDs = Set<String>()
		for (index, question) in questions.enumerated() {
			let questionID = question.id.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !questionID.isEmpty else {
				throw AgentAskUserValidationError.blankQuestionID(index: index)
			}
			guard seenIDs.insert(questionID).inserted else {
				throw AgentAskUserValidationError.duplicateQuestionID(questionID)
			}
			guard !question.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
				throw AgentAskUserValidationError.blankQuestionText(id: questionID)
			}
			guard question.allowsCustom || !question.options.isEmpty else {
				throw AgentAskUserValidationError.impossibleQuestion(questionID: questionID)
			}

			var optionLabels = Set<String>()
			for option in question.options {
				let label = option.label.trimmingCharacters(in: .whitespacesAndNewlines)
				guard !label.isEmpty else {
					throw AgentAskUserValidationError.duplicateOptionLabel(questionID: questionID, label: "")
				}
				guard optionLabels.insert(label).inserted else {
					throw AgentAskUserValidationError.duplicateOptionLabel(questionID: questionID, label: label)
				}
			}
		}
	}

	public func emptyDrafts() -> [String: AgentAskUserDraft] {
		questions.reduce(into: [String: AgentAskUserDraft]()) { partialResult, question in
			partialResult[question.id] = AgentAskUserDraft()
		}
	}

	public func isComplete(drafts: [String: AgentAskUserDraft]) -> Bool {
		questions.allSatisfy { question in
			let answer = question.answer(from: drafts[question.id] ?? AgentAskUserDraft())
			return answer.skipped || !answer.answers.isEmpty
		}
	}

	public func drafts(from answersByQuestionID: [String: AgentAskUserAnswer]) throws -> [String: AgentAskUserDraft] {
		try validateAnswerQuestionIDs(answersByQuestionID.keys)
		return try questions.reduce(into: emptyDrafts()) { partialResult, question in
			guard let answer = answersByQuestionID[question.id] else { return }
			partialResult[question.id] = try draft(from: answer, for: question)
		}
	}

	public func drafts(fromFlatAnswers answersByQuestionID: [String: [String]]) throws -> [String: AgentAskUserDraft] {
		try validateAnswerQuestionIDs(answersByQuestionID.keys)
		return try questions.reduce(into: emptyDrafts()) { partialResult, question in
			guard let answers = answersByQuestionID[question.id] else { return }
			partialResult[question.id] = try draft(fromAnswers: answers, skipped: false, for: question)
		}
	}

	private func validateAnswerQuestionIDs<S: Sequence>(_ ids: S) throws where S.Element == String {
		let validIDs = questions.map(\.id)
		let validIDSet = Set(validIDs)
		if let unknownID = ids.first(where: { !validIDSet.contains($0) }) {
			throw AgentAskUserValidationError.unknownQuestionID(id: unknownID, validIDs: validIDs)
		}
	}

	private func draft(from answer: AgentAskUserAnswer, for question: AgentAskUserQuestion) throws -> AgentAskUserDraft {
		if answer.skipped {
			return AgentAskUserDraft(skipped: true)
		}
		let answers = answer.selectedOptions.isEmpty && answer.customResponse == nil
			? answer.answers
			: answer.selectedOptions + (answer.customResponse.map { [$0] } ?? [])
		return try draft(fromAnswers: answers, skipped: false, for: question)
	}

	private func draft(fromAnswers answers: [String], skipped: Bool, for question: AgentAskUserQuestion) throws -> AgentAskUserDraft {
		if skipped {
			return AgentAskUserDraft(skipped: true)
		}

		let optionLabels = question.optionLabels
		let optionSet = Set(optionLabels)
		var selectedSet = Set<String>()
		var customAnswers: [String] = []
		for answer in answers {
			let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !trimmed.isEmpty else { continue }
			if optionSet.contains(trimmed) {
				selectedSet.insert(trimmed)
			} else {
				guard question.allowsCustom else {
					throw AgentAskUserValidationError.invalidCustomAnswer(questionID: question.id)
				}
				customAnswers.append(trimmed)
			}
		}

		guard customAnswers.count <= 1 else {
			throw AgentAskUserValidationError.invalidCustomAnswer(questionID: question.id)
		}
		let selectedOptions = optionLabels.filter { selectedSet.contains($0) }
		let customResponse = customAnswers.first ?? ""
		let totalAnswerCount = selectedOptions.count + (customResponse.isEmpty ? 0 : 1)
		guard question.allowsMultiple || totalAnswerCount <= 1 else {
			throw AgentAskUserValidationError.invalidSingleSelectAnswer(questionID: question.id)
		}
		return AgentAskUserDraft(
			selectedOptionLabels: selectedOptions,
			customResponse: customResponse,
			skipped: false
		)
	}

	public func buildSubmittedResponse(
		drafts: [String: AgentAskUserDraft],
		elapsedSeconds: Int
	) throws -> AgentAskUserResponse {
		try buildResponse(drafts: drafts, timedOut: false, skipped: false, elapsedSeconds: elapsedSeconds, requireComplete: true)
	}

	public func buildTimedOutResponse(
		drafts: [String: AgentAskUserDraft],
		elapsedSeconds: Int
	) -> AgentAskUserResponse {
		(try? buildResponse(drafts: drafts, timedOut: true, skipped: false, elapsedSeconds: elapsedSeconds, requireComplete: false))
			?? AgentAskUserResponse(answersByQuestionID: [:], timedOut: true, skipped: false, elapsedSeconds: elapsedSeconds)
	}

	public func buildSkippedResponse(elapsedSeconds: Int) -> AgentAskUserResponse {
		let skippedAnswers = questions.reduce(into: [String: AgentAskUserAnswer]()) { partialResult, question in
			partialResult[question.id] = AgentAskUserAnswer(answers: [], selectedOptions: [], customResponse: nil, skipped: true)
		}
		return AgentAskUserResponse(
			answersByQuestionID: skippedAnswers,
			timedOut: false,
			skipped: true,
			elapsedSeconds: elapsedSeconds
		)
	}

	private func buildResponse(
		drafts: [String: AgentAskUserDraft],
		timedOut: Bool,
		skipped: Bool,
		elapsedSeconds: Int,
		requireComplete: Bool
	) throws -> AgentAskUserResponse {
		try validate()
		var answers = [String: AgentAskUserAnswer]()
		for question in questions {
			let answer = question.answer(from: drafts[question.id] ?? AgentAskUserDraft())
			try question.validate(answer)
			if requireComplete, !answer.skipped, answer.answers.isEmpty {
				throw AgentAskUserValidationError.incompleteQuestion(question.id)
			}
			answers[question.id] = answer
		}
		return AgentAskUserResponse(
			answersByQuestionID: answers,
			timedOut: timedOut,
			skipped: skipped,
			elapsedSeconds: elapsedSeconds
		)
	}
}

public struct AgentAskUserPendingState: Identifiable, Sendable, Hashable {
	public var interaction: AgentAskUserInteraction
	public var draftsByQuestionID: [String: AgentAskUserDraft]
	public var currentQuestionIndex: Int
	public var timeoutStartedAt: Date?

	public var id: UUID { interaction.id }

	public init(
		interaction: AgentAskUserInteraction,
		draftsByQuestionID: [String: AgentAskUserDraft]? = nil,
		currentQuestionIndex: Int = 0,
		timeoutStartedAt: Date? = nil
	) {
		self.interaction = interaction
		self.draftsByQuestionID = draftsByQuestionID ?? interaction.emptyDrafts()
		self.currentQuestionIndex = currentQuestionIndex
		self.timeoutStartedAt = timeoutStartedAt
	}

	public var currentQuestion: AgentAskUserQuestion? {
		guard interaction.questions.indices.contains(currentQuestionIndex) else { return nil }
		return interaction.questions[currentQuestionIndex]
	}

	public var isComplete: Bool {
		interaction.isComplete(drafts: draftsByQuestionID)
	}
}
