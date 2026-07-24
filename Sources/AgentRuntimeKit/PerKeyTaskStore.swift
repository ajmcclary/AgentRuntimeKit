import Foundation

@MainActor
public final class PerKeyTaskStore<Key: Hashable> {
	/// Issued by `setTask(_:makeTask:)`; `remove(_:ifCurrent:)` only removes the
	/// entry the token was issued for, so a cancelled/stale worker's cleanup can
	/// never evict a replacement task that was registered after it.
	public struct RemovalToken: Hashable, Sendable {
		fileprivate let generation: UInt64
	}

	private var tasks: [Key: (generation: UInt64, task: Task<Void, Never>)] = [:]
	private var nextGeneration: UInt64 = 0

	public init() {}

	public func hasTask(for key: Key) -> Bool {
		tasks[key] != nil
	}

	public func set(_ key: Key, task: Task<Void, Never>) {
		if let existing = tasks.removeValue(forKey: key) {
			existing.task.cancel()
		}
		tasks[key] = (generation: allocateGeneration(), task: task)
	}

	/// Registers a task whose body can safely self-remove: the closure receives
	/// the token identifying this registration, valid until the key is replaced,
	/// cancelled, or removed.
	@discardableResult
	public func setTask(_ key: Key, makeTask: (RemovalToken) -> Task<Void, Never>) -> RemovalToken {
		let token = RemovalToken(generation: allocateGeneration())
		let task = makeTask(token)
		if let existing = tasks.removeValue(forKey: key) {
			existing.task.cancel()
		}
		tasks[key] = (generation: token.generation, task: task)
		return token
	}

	public func remove(_ key: Key) {
		_ = tasks.removeValue(forKey: key)
	}

	public func remove(_ key: Key, ifCurrent token: RemovalToken) {
		guard tasks[key]?.generation == token.generation else { return }
		tasks[key] = nil
	}

	public func cancel(_ key: Key) {
		guard let entry = tasks.removeValue(forKey: key) else { return }
		entry.task.cancel()
	}

	public func cancelAll() {
		let activeTasks = tasks.values.map(\.task)
		tasks.removeAll()
		for task in activeTasks {
			task.cancel()
		}
	}

	private func allocateGeneration() -> UInt64 {
		nextGeneration &+= 1
		return nextGeneration
	}
}
