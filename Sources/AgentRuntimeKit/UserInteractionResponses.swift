import Foundation

/// Response from user to a discovery question
public struct UserQuestionResponse: Sendable {
	public let text: String?
	public let timedOut: Bool
	public let elapsedSeconds: Int
	public let skipped: Bool

	public init(text: String?, timedOut: Bool, elapsedSeconds: Int, skipped: Bool) {
		self.text = text
		self.timedOut = timedOut
		self.elapsedSeconds = elapsedSeconds
		self.skipped = skipped
	}

	public static func answered(_ text: String, elapsedSeconds: Int) -> UserQuestionResponse {
		UserQuestionResponse(text: text, timedOut: false, elapsedSeconds: elapsedSeconds, skipped: false)
	}

	public static func timeout(elapsedSeconds: Int) -> UserQuestionResponse {
		UserQuestionResponse(text: nil, timedOut: true, elapsedSeconds: elapsedSeconds, skipped: false)
	}

	public static func skipped(elapsedSeconds: Int) -> UserQuestionResponse {
		UserQuestionResponse(text: nil, timedOut: false, elapsedSeconds: elapsedSeconds, skipped: true)
	}
}

/// Response from user instruction input in Agent mode
public struct UserInstructionResponse: Sendable {
	public let text: String?
	public let timedOut: Bool
	public let elapsedSeconds: Int

	public init(text: String?, timedOut: Bool, elapsedSeconds: Int) {
		self.text = text
		self.timedOut = timedOut
		self.elapsedSeconds = elapsedSeconds
	}
}
