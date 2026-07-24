import Foundation

/// State of an agent run within a session
public enum AgentSessionRunState: String, Codable, Sendable, Equatable {
	case idle
	case running
	case waitingForUser
	case waitingForQuestion
	case waitingForApproval
	case completed
	case cancelled
	case failed

	public var isActive: Bool {
		switch self {
		case .running, .waitingForUser, .waitingForQuestion, .waitingForApproval:
			return true
		case .idle, .completed, .cancelled, .failed:
			return false
		}
	}

	/// Whether entering this state should refresh sidebar-visible activity.
	/// Running/output-only liveness is tracked separately so live output does
	/// not reorder sidebar rows by itself.
	public var touchesSidebarVisibleActivityOnTransition: Bool {
		switch self {
		case .waitingForUser, .waitingForQuestion, .waitingForApproval,
				.completed, .cancelled, .failed:
			return true
		case .idle, .running:
			return false
		}
	}
}
