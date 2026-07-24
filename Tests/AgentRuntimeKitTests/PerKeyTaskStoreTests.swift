import XCTest
@testable import AgentRuntimeKit

@MainActor
final class PerKeyTaskStoreTests: XCTestCase {
	func testSetReplacesAndCancelsExistingTask() async {
		let store = PerKeyTaskStore<String>()
		let firstCancelled = CancellationFlag()
		let secondCancelled = CancellationFlag()

		store.set("tab-a", task: Task {
			defer { firstCancelled.markCancelled() }
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		})
		store.set("tab-a", task: Task {
			defer { secondCancelled.markCancelled() }
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		})

		let firstWasCancelled = await waitForCondition(timeoutSeconds: 1.0) {
			firstCancelled.isCancelled()
		}
		XCTAssertTrue(firstWasCancelled)
		XCTAssertTrue(store.hasTask(for: "tab-a"))

		store.cancelAll()
		let secondWasCancelled = await waitForCondition(timeoutSeconds: 1.0) {
			secondCancelled.isCancelled()
		}
		XCTAssertTrue(secondWasCancelled)
	}

	func testCancelAndCancelAll() async {
		let store = PerKeyTaskStore<Int>()
		let firstCancelled = CancellationFlag()
		let secondCancelled = CancellationFlag()

		store.set(1, task: Task {
			defer { firstCancelled.markCancelled() }
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		})
		store.set(2, task: Task {
			defer { secondCancelled.markCancelled() }
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		})

		store.cancel(1)
		let firstWasCancelled = await waitForCondition(timeoutSeconds: 1.0) {
			firstCancelled.isCancelled()
		}
		XCTAssertTrue(firstWasCancelled)
		XCTAssertFalse(store.hasTask(for: 1))
		XCTAssertTrue(store.hasTask(for: 2))

		store.cancelAll()
		let secondWasCancelled = await waitForCondition(timeoutSeconds: 1.0) {
			secondCancelled.isCancelled()
		}
		XCTAssertTrue(secondWasCancelled)
		XCTAssertFalse(store.hasTask(for: 2))
	}

	func testCancelledWorkerCleanupCannotEvictReplacement() async {
		let store = PerKeyTaskStore<String>()
		let staleCleanupRan = CancellationFlag()

		store.setTask("tab") { token in
			Task {
				defer {
					store.remove("tab", ifCurrent: token)
					staleCleanupRan.markCancelled()
				}
				while !Task.isCancelled {
					try? await Task.sleep(nanoseconds: 10_000_000)
				}
			}
		}
		store.setTask("tab") { _ in
			Task {
				while !Task.isCancelled {
					try? await Task.sleep(nanoseconds: 10_000_000)
				}
			}
		}

		let cleanupRan = await waitForCondition(timeoutSeconds: 1.0) {
			staleCleanupRan.isCancelled()
		}
		XCTAssertTrue(cleanupRan)
		XCTAssertTrue(
			store.hasTask(for: "tab"),
			"stale worker cleanup must not evict its replacement from the registry"
		)
		store.cancelAll()
	}

	func testCompletedWorkerRemovesItselfWithCurrentToken() async {
		let store = PerKeyTaskStore<String>()

		store.setTask("tab") { token in
			Task {
				store.remove("tab", ifCurrent: token)
			}
		}

		let removed = await waitForCondition(timeoutSeconds: 1.0) {
			!store.hasTask(for: "tab")
		}
		XCTAssertTrue(removed, "a still-current worker must be able to remove its own registry entry")
	}

	func testLegacySetInvalidatesEarlierToken() async {
		let store = PerKeyTaskStore<String>()
		let firstCancelled = CancellationFlag()

		var earlierToken: PerKeyTaskStore<String>.RemovalToken?
		store.setTask("tab") { token in
			earlierToken = token
			return Task {
				defer { firstCancelled.markCancelled() }
				while !Task.isCancelled {
					try? await Task.sleep(nanoseconds: 10_000_000)
				}
			}
		}
		store.set("tab", task: Task {
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		})

		let firstWasCancelled = await waitForCondition(timeoutSeconds: 1.0) {
			firstCancelled.isCancelled()
		}
		XCTAssertTrue(firstWasCancelled)
		if let earlierToken {
			store.remove("tab", ifCurrent: earlierToken)
		}
		XCTAssertTrue(
			store.hasTask(for: "tab"),
			"a token issued before a legacy set must not remove the replacement"
		)
		store.cancelAll()
	}

	private func waitForCondition(
		timeoutSeconds: TimeInterval,
		condition: @escaping () async -> Bool
	) async -> Bool {
		let deadline = Date().addingTimeInterval(timeoutSeconds)
		while Date() < deadline {
			if await condition() {
				return true
			}
			try? await Task.sleep(nanoseconds: 20_000_000)
		}
		return await condition()
	}
}

private final class CancellationFlag: @unchecked Sendable {
	private let lock = NSLock()
	private var cancelled = false

	func markCancelled() {
		lock.lock()
		cancelled = true
		lock.unlock()
	}

	func isCancelled() -> Bool {
		lock.lock()
		defer { lock.unlock() }
		return cancelled
	}
}
