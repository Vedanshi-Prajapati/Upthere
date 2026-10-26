import Foundation

/// A deterministic, manual sleeper actor holding checked continuations for testing asynchronous timeouts.
actor ManualSleeper {
    private var continuations: [CheckedContinuation<Void, Never>?] = []
    private var sleepCount: Int = 0
    private var waiters: [(threshold: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func sleep(_ duration: Duration) async throws {
        try Task.checkCancellation()
        guard duration > .zero else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            continuations.append(cont)
            sleepCount += 1
            checkWaiters()
        }
        try Task.checkCancellation()
    }

    private func checkWaiters() {
        waiters.removeAll { waiter in
            if sleepCount >= waiter.threshold {
                waiter.continuation.resume()
                return true
            }
            return false
        }
    }

    func waitForRequests(_ count: Int) async {
        if sleepCount >= count { return }
        await withCheckedContinuation { cont in
            waiters.append((count, cont))
        }
    }

    /// Suspends until at least `n` requests have been received, then resumes the continuation at `index`.
    /// If `index` is nil, it defaults to the (n - 1)-th request.
    func fire(afterRequests n: Int = 1, index: Int? = nil) async {
        await waitForRequests(n)
        let targetIndex = index ?? (n - 1)
        guard targetIndex >= 0 && targetIndex < continuations.count else { return }
        if let cont = continuations[targetIndex] {
            continuations[targetIndex] = nil
            cont.resume()
        }
    }

    func fire(index: Int, afterRequests n: Int = 1) async {
        await fire(afterRequests: n, index: index)
    }

    func resumeAll() {
        for cont in continuations.compactMap({ $0 }) {
            cont.resume()
        }
        continuations.removeAll()
    }

    deinit {
        for cont in continuations.compactMap({ $0 }) {
            cont.resume()
        }
        for waiter in waiters {
            waiter.continuation.resume()
        }
    }
}
