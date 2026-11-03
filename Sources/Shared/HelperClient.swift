import os
import Foundation

enum HelperError: LocalizedError {
    case unavailable
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "特権ヘルパに接続できません。App を開いてヘルパを登録してください。"
        case .failed(let message):
            return message
        }
    }
}

/// 特権ヘルパ（root LaunchDaemon）への XPC クライアント。
/// App と Control Center 拡張の両方から使う。
final class HelperClient {
    static let shared = HelperClient()

    private let lock = NSLock()
    private var connection: NSXPCConnection?

    private func proxy(
        onError: @escaping (Error) -> Void
    ) -> SleepToggleHelperProtocol? {
        lock.lock()
        defer { lock.unlock() }

        let target: NSXPCConnection
        if let existing = connection {
            target = existing
        } else {
            let fresh = NSXPCConnection(machServiceName: sleepToggleMachServiceName,
                                        options: .privileged)
            fresh.remoteObjectInterface = NSXPCInterface(with: SleepToggleHelperProtocol.self)
            // 偽のヘルパに接続して状態を誤認させられるのを防ぐ。
            fresh.setCodeSigningRequirement(sleepToggleHelperRequirement)

            let drop: @Sendable () -> Void = { [weak self] in
                guard let self else { return }
                self.lock.lock()
                self.connection = nil
                self.lock.unlock()
            }
            fresh.invalidationHandler = drop
            fresh.interruptionHandler = drop
            fresh.resume()

            connection = fresh
            target = fresh
        }

        return target.remoteObjectProxyWithErrorHandler(onError) as? SleepToggleHelperProtocol
    }

    /// XPC はエラーハンドラと reply の両方が呼ばれうるため、
    /// continuation の二重 resume を防ぐ。片方しか通さない。
    private func withSingleResume<T>(
        _ body: @escaping (@escaping (Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        let resumed = OSAllocatedUnfairLock(initialState: false)
        return try await withCheckedThrowingContinuation { continuation in
            body { result in
                let alreadyResumed = resumed.withLock { done -> Bool in
                    if done { return true }
                    done = true
                    return false
                }
                guard !alreadyResumed else { return }
                continuation.resume(with: result)
            }
        }
    }

    func setSleepDisabled(_ disabled: Bool) async throws {
        try await withSingleResume { (finish: @escaping (Result<Void, Error>) -> Void) in
            guard let proxy = self.proxy(onError: { finish(.failure($0)) }) else {
                finish(.failure(HelperError.unavailable))
                return
            }
            proxy.setSleepDisabled(disabled) { ok, message in
                finish(ok ? .success(()) : .failure(HelperError.failed(message ?? "不明なエラー")))
            }
        }
    }

    func readSleepDisabled() async throws -> Bool {
        try await withSingleResume { finish in
            guard let proxy = self.proxy(onError: { finish(.failure($0)) }) else {
                finish(.failure(HelperError.unavailable))
                return
            }
            proxy.readSleepDisabled { finish(.success($0)) }
        }
    }

    func version() async throws -> String {
        try await withSingleResume { finish in
            guard let proxy = self.proxy(onError: { finish(.failure($0)) }) else {
                finish(.failure(HelperError.unavailable))
                return
            }
            proxy.version { finish(.success($0)) }
        }
    }
}
