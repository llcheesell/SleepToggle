import Foundation

let helperVersion = "1.0.0"

/// XPC 越しに App / Control Center 拡張へ公開する実装。
final class HelperService: NSObject, SleepToggleHelperProtocol {
    func version(reply: @escaping (String) -> Void) {
        reply(helperVersion)
    }

    func readSleepDisabled(reply: @escaping (Bool) -> Void) {
        reply(PowerManagement.sleepDisabled())
    }

    func setSleepDisabled(_ disabled: Bool, reply: @escaping (Bool, String?) -> Void) {
        do {
            try PowerManagement.setSleepDisabled(disabled)
            NSLog("[SleepToggle] SleepDisabled=%d に設定しました", disabled ? 1 : 0)
            reply(true, nil)
        } catch {
            let message = (error as? PowerManagement.Failure)?.description
                ?? error.localizedDescription
            NSLog("[SleepToggle] 設定に失敗: %@", message)
            reply(false, message)
        }
    }
}

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    /// 接続が途絶えてからこの秒数で終了する。
    /// launchd の on-demand 起動なので、次の接続で設置済みの最新バイナリが立ち上がる。
    /// 常駐させると App を更新しても古いバイナリが動き続ける。
    private let idleTimeout: TimeInterval = 20
    private var activeConnections = 0
    private var generation = 0

    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // 署名要件を満たさない接続は、以降のメッセージ受信時に XPC 側で無効化される。
        // resume より前に、かつ一度だけ呼ぶこと（複数回呼ぶと XPC エラーになる）。
        newConnection.setCodeSigningRequirement(sleepToggleClientRequirement)
        newConnection.exportedInterface = NSXPCInterface(with: SleepToggleHelperProtocol.self)
        newConnection.exportedObject = HelperService()
        newConnection.invalidationHandler = { [weak self] in
            DispatchQueue.main.async { self?.connectionClosed() }
        }
        DispatchQueue.main.async { self.activeConnections += 1; self.generation += 1 }
        newConnection.resume()
        return true
    }

    private func connectionClosed() {
        activeConnections = max(0, activeConnections - 1)
        scheduleIdleExit()
    }

    func scheduleIdleExit() {
        let mine = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + idleTimeout) { [weak self] in
            guard let self, self.activeConnections == 0, self.generation == mine else { return }
            exit(0)
        }
    }
}

// launchd 以外から起動したときの動作確認用。XPC を張らずに現在値だけ出して終わる。
if CommandLine.arguments.contains("--status") {
    print(PowerManagement.sleepDisabled() ? "1" : "0")
    exit(0)
}

// `--set 0|1` は root で直接叩いて pmset 経路だけを検証するためのもの。
if let index = CommandLine.arguments.firstIndex(of: "--set"),
   index + 1 < CommandLine.arguments.count {
    let wanted = CommandLine.arguments[index + 1] == "1"
    do {
        try PowerManagement.setSleepDisabled(wanted)
        print("ok: SleepDisabled=\(wanted ? 1 : 0)")
        exit(0)
    } catch {
        let message = (error as? PowerManagement.Failure)?.description
            ?? error.localizedDescription
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
        exit(1)
    }
}

let delegate = ListenerDelegate()
let listener = NSXPCListener(machServiceName: sleepToggleMachServiceName)
listener.delegate = delegate
listener.resume()
// 起動要求が来たのに誰も繋がなかった場合も残らないようにする。
delegate.scheduleIdleExit()
NSLog("[SleepToggle] helper %@ 起動、%@ で待受", helperVersion, sleepToggleMachServiceName)
RunLoop.main.run()
