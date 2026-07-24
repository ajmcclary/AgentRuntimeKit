import Foundation

public struct AgentMCPElicitationRequest: Identifiable, Sendable, Hashable {
	public let id: UUID
	public let requestID: CodexAppServerRequestID
	public let method: String
	public let threadID: String
	public let turnID: String
	public let itemID: String
	public let serverName: String?
	public let toolName: String?
	public let title: String
	public let prompt: String?
	public let message: String?
	public let schemaJSON: String?
	public let defaultContentJSON: String?
	public let rawParamsJSON: String
	public let details: [AgentApprovalDetail]

	public init(
		id: UUID? = nil,
		requestID: CodexAppServerRequestID,
		method: String,
		threadID: String,
		turnID: String,
		itemID: String,
		serverName: String? = nil,
		toolName: String? = nil,
		title: String = "MCP Elicitation Requested",
		prompt: String? = nil,
		message: String? = nil,
		schemaJSON: String? = nil,
		defaultContentJSON: String? = nil,
		rawParamsJSON: String,
		details: [AgentApprovalDetail] = []
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
		self.serverName = serverName
		self.toolName = toolName
		self.title = title
		self.prompt = prompt
		self.message = message
		self.schemaJSON = schemaJSON
		self.defaultContentJSON = defaultContentJSON
		self.rawParamsJSON = rawParamsJSON
		self.details = details
	}

	public static func stableID(
		requestID: CodexAppServerRequestID,
		method: String,
		threadID: String,
		turnID: String,
		itemID: String
	) -> UUID {
		StableUserInteractionIdentity.uuid(
			from: "mcp-elicitation-request|\(requestID.displayValue)|\(method)|\(threadID)|\(turnID)|\(itemID)"
		)
	}
}

public struct AgentApprovalDetail: Identifiable, Sendable, Hashable {
	public let id: UUID
	public let label: String
	public let value: String
	public let isCode: Bool

	public static func stableID(
		requestSeed: String,
		index: Int,
		label: String,
		value: String,
		isCode: Bool
	) -> UUID {
		StableUserInteractionIdentity.uuid(
			from: "approval-detail|\(requestSeed)|\(index)|\(label)|\(isCode)|\(value)"
		)
	}

	private static func defaultStableID(
		label: String,
		value: String,
		isCode: Bool
	) -> UUID {
		StableUserInteractionIdentity.uuid(from: "approval-detail-default|\(label)|\(isCode)|\(value)")
	}

	public init(id: UUID? = nil, label: String, value: String, isCode: Bool = false) {
		self.id = id ?? Self.defaultStableID(label: label, value: value, isCode: isCode)
		self.label = label
		self.value = value
		self.isCode = isCode
	}
}

public enum AgentApprovalKind: String, Sendable, Hashable {
	case commandExecution
	case fileChange
}

public enum AgentApprovalDecision: Sendable, Hashable {
	case accept
	case acceptForSession
	case acceptWithExecpolicyAmendment(String)
	case decline
	case cancel
}

public enum AgentApprovalRequestID: Sendable, Hashable {
	case codex(CodexAppServerRequestID)
	case claudeControl(String)
	case acp(String)

	public var displayValue: String {
		switch self {
		case .codex(let id):
			return id.displayValue
		case .claudeControl(let id):
			return id
		case .acp(let id):
			return id
		}
	}
}

public struct AgentPermissionsRequest: Identifiable, Sendable, Hashable {
	public let id: UUID
	public let requestID: CodexAppServerRequestID
	public let method: String
	public let threadID: String
	public let turnID: String
	public let itemID: String
	public let cwd: String
	public let reason: String?
	public let permissionsJSON: String
	public let details: [AgentApprovalDetail]

	public init(
		id: UUID? = nil,
		requestID: CodexAppServerRequestID,
		method: String,
		threadID: String,
		turnID: String,
		itemID: String,
		cwd: String,
		reason: String? = nil,
		permissionsJSON: String,
		details: [AgentApprovalDetail] = []
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
		self.cwd = cwd
		self.reason = reason
		self.permissionsJSON = permissionsJSON
		self.details = details
	}

	public static func stableID(
		requestID: CodexAppServerRequestID,
		method: String,
		threadID: String,
		turnID: String,
		itemID: String
	) -> UUID {
		StableUserInteractionIdentity.uuid(
			from: "permissions-request|\(requestID.displayValue)|\(method)|\(threadID)|\(turnID)|\(itemID)"
		)
	}

	public var title: String {
		"Permissions Approval"
	}

	public var permissionsObject: [String: Any] {
		guard let data = permissionsJSON.data(using: .utf8),
			let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
		else {
			return [:]
		}
		return object
	}
}

public struct AgentApprovalRequest: Identifiable, Sendable, Hashable {
	public let id: UUID
	public let requestID: AgentApprovalRequestID
	public let method: String
	public let kind: AgentApprovalKind
	public let threadID: String
	public let turnID: String
	public let itemID: String
	public let reason: String?
	public let command: String?
	public let cwd: String?
	public let grantRoot: String?
	public let proposedExecpolicyAmendmentJSON: String?
	public let details: [AgentApprovalDetail]
	/// Whether a session-scoped "always allow" decision is actually available for THIS
	/// request. Tenth round, finding 6: this was a hardcoded `true`, so the ACP approval
	/// card offered "Always Allow" even when the provider advertised no session-scoped
	/// option — the decision then fell through to a per-call option, or to an empty
	/// `optionId`. Providers that always support the affordance (Codex, Claude) keep the
	/// default; ACP sets it from the validated option set.
	public let supportsAlwaysAllow: Bool

	public init(
		id: UUID? = nil,
		requestID: AgentApprovalRequestID,
		method: String,
		kind: AgentApprovalKind,
		threadID: String,
		turnID: String,
		itemID: String,
		reason: String? = nil,
		command: String? = nil,
		cwd: String? = nil,
		grantRoot: String? = nil,
		proposedExecpolicyAmendmentJSON: String? = nil,
		details: [AgentApprovalDetail] = [],
		supportsAlwaysAllow: Bool = true
	) {
		self.supportsAlwaysAllow = supportsAlwaysAllow
		self.id = id ?? Self.stableID(
			requestID: requestID,
			method: method,
			kind: kind,
			threadID: threadID,
			turnID: turnID,
			itemID: itemID
		)
		self.requestID = requestID
		self.method = method
		self.kind = kind
		self.threadID = threadID
		self.turnID = turnID
		self.itemID = itemID
		self.reason = reason
		self.command = command
		self.cwd = cwd
		self.grantRoot = grantRoot
		self.proposedExecpolicyAmendmentJSON = proposedExecpolicyAmendmentJSON
		self.details = details
	}

	public static func stableID(
		requestID: AgentApprovalRequestID,
		method: String,
		kind: AgentApprovalKind,
		threadID: String,
		turnID: String,
		itemID: String
	) -> UUID {
		StableUserInteractionIdentity.uuid(
			from: "approval-request|\(requestID.displayValue)|\(method)|\(kind.rawValue)|\(threadID)|\(turnID)|\(itemID)"
		)
	}

	public var title: String {
		switch kind {
		case .commandExecution:
			return "Command Approval"
		case .fileChange:
			return "File Change Approval"
		}
	}

}
