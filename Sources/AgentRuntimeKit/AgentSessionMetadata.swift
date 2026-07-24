import Foundation

// MARK: - Agent Session Data Error

public enum AgentSessionDataError: Error {
	case invalidFilename(String)
	case invalidStoragePath(String)
	case decodingFailed(Error)
	case loadFailed(Error)
	case saveFailed(Error)
	case noActiveWorkspace
	/// The persisted session file exceeds the documented I/O resource bound and was
	/// refused BEFORE being read or decoded (thirteenth round, finding 4). Fail-closed:
	/// an arbitrarily large file (e.g. a hostile provider-usage array) never forces
	/// proportional parsing/allocation.
	case sessionFileTooLarge(bytes: Int, limit: Int)
	/// The persisted session path did not resolve to a regular file — a symlink (the
	/// loader opens with `O_NOFOLLOW`), a directory, or another special file (fourteenth
	/// round, finding 2). Fail-closed: a substituted filesystem object is never read.
	case sessionFileNotRegular(path: String)
	/// The persisted session file could not be opened, validated, or read through the
	/// single bound descriptor (fourteenth round, finding 2). Fail-closed: a metadata or
	/// read failure never falls through to an unbounded read.
	case sessionFileUnreadable(path: String, code: Int32)
}

// MARK: - Agent Session Metadata

/// Lightweight metadata for agent session listing
public struct AgentSessionMeta {
	public let id: UUID
	public let composeTabID: UUID?
	public let name: String
	public let lastModified: Date
	public let itemCount: Int
	public let agentKind: String?
	public let agentModel: String?
	public let lastRunState: String?
	public let parentSessionID: UUID?
	public let isMCPOriginated: Bool

	public init(
		id: UUID,
		composeTabID: UUID?,
		name: String,
		lastModified: Date,
		itemCount: Int,
		agentKind: String?,
		agentModel: String?,
		lastRunState: String?,
		parentSessionID: UUID?,
		isMCPOriginated: Bool
	) {
		self.id = id
		self.composeTabID = composeTabID
		self.name = name
		self.lastModified = lastModified
		self.itemCount = itemCount
		self.agentKind = agentKind
		self.agentModel = agentModel
		self.lastRunState = lastRunState
		self.parentSessionID = parentSessionID
		self.isMCPOriginated = isMCPOriginated
	}
}
