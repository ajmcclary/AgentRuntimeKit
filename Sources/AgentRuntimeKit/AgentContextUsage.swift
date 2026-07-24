import Foundation

public struct AgentContextUsage: Codable, Equatable, Sendable {
	public var modelContextWindow: Int?
	public var lastTotalTokens: Int?
	public var totalTotalTokens: Int?

	public init(
		modelContextWindow: Int? = nil,
		lastTotalTokens: Int? = nil,
		totalTotalTokens: Int? = nil
	) {
		self.modelContextWindow = modelContextWindow
		self.lastTotalTokens = lastTotalTokens
		self.totalTotalTokens = totalTotalTokens
	}
}
