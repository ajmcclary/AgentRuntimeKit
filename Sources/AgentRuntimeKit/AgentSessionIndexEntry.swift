import Foundation

public struct AgentSessionIndexEntry: Identifiable, Equatable, Sendable {
	public let id: UUID
	public let tabID: UUID
	public var name: String
	public var lastUserMessageAt: Date?
	public var savedAt: Date
	public var lastRunStateRaw: String?
	public var itemCount: Int
	public var agentKindRaw: String?
	public var agentModelRaw: String?
	public var agentReasoningEffortRaw: String?
	public var autoEditEnabled: Bool
	public var parentSessionID: UUID?
	public var hasUnknownConversationContent: Bool
	public var isMCPOriginated: Bool

	public init(
		id: UUID,
		tabID: UUID,
		name: String,
		lastUserMessageAt: Date? = nil,
		savedAt: Date,
		lastRunStateRaw: String? = nil,
		itemCount: Int,
		agentKindRaw: String? = nil,
		agentModelRaw: String? = nil,
		agentReasoningEffortRaw: String? = nil,
		autoEditEnabled: Bool,
		parentSessionID: UUID? = nil,
		hasUnknownConversationContent: Bool,
		isMCPOriginated: Bool
	) {
		self.id = id
		self.tabID = tabID
		self.name = name
		self.lastUserMessageAt = lastUserMessageAt
		self.savedAt = savedAt
		self.lastRunStateRaw = lastRunStateRaw
		self.itemCount = itemCount
		self.agentKindRaw = agentKindRaw
		self.agentModelRaw = agentModelRaw
		self.agentReasoningEffortRaw = agentReasoningEffortRaw
		self.autoEditEnabled = autoEditEnabled
		self.parentSessionID = parentSessionID
		self.hasUnknownConversationContent = hasUnknownConversationContent
		self.isMCPOriginated = isMCPOriginated
	}
}
