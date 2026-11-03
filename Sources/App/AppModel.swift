import Foundation
import ServiceManagement
import WidgetKit

/// App の状態とセットアップ。
///
/// 日常の操作は Control Center で完結するので、この App は
/// 「初回に必要なものを登録する」「状態を見る」ためだけにある。
/// 手順を踏ませないよう、起動時に必要な登録は自動で済ませる。
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var sleepDisabled = false
    @Published private(set) var helperStatus: SMAppService.Status = .notRegistered
    @Published private(set) var watcherStatus: SMAppService.Status = .notRegistered
    @Published private(set) var busy = false
    @Published var errorMessage: String?

    private let helper = SMAppService.daemon(plistName: "com.llcheesell.SleepToggle.helper.plist")
    // 音はユーザーセッションでしか鳴らせないため、デーモンではなくエージェント。
    private let watcher = SMAppService.agent(plistName: "com.llcheesell.SleepToggle.watcher.plist")
    private let defaults = UserDefaults.standard

    var helperReady: Bool { helperStatus == .enabled }
    var needsApproval: Bool {
        helperStatus == .requiresApproval || watcherStatus == .requiresApproval
    }
    var soundEnabled: Bool { watcherStatus == .enabled }

    // MARK: - 起動時

    func bootstrap() async {
        // ヘルパは無いと何もできないので、未登録なら黙って登録する。
        // 初回は macOS が「バックグラウンド項目」の許可を求める。
        if helper.status == .notRegistered || helper.status == .notFound {
            try? helper.register()
        }
        // 警告音は既定で有効。ユーザーが一度でも切ったら以後は触らない。
        if !defaults.bool(forKey: "didSetUpSound") {
            try? watcher.register()
            defaults.set(true, forKey: "didSetUpSound")
        }
        restartWatcherIfUpdated()
        await refresh()
    }

    /// 監視エージェントは KeepAlive で常駐するので、App を更新しても古いバイナリが動き続ける。
    /// 版が変わった最初の起動でだけ入れ替える。
    private func restartWatcherIfUpdated() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        guard defaults.string(forKey: "lastLaunchedVersion") != version else { return }
        defaults.set(version, forKey: "lastLaunchedVersion")
        guard watcher.status == .enabled else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["kickstart", "-k", "gui/\(getuid())/com.llcheesell.SleepToggle.watcher"]
        try? task.run()
    }

    func refresh() async {
        helperStatus = helper.status
        watcherStatus = watcher.status
        // 読み取りに root は不要なので、ヘルパの状態に関わらず表示できる。
        sleepDisabled = PowerManagement.sleepDisabled()
    }

    // MARK: - 操作

    func toggle() async {
        busy = true
        defer { busy = false }
        do {
            try await HelperClient.shared.setSleepDisabled(!sleepDisabled)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        await refresh()
        // Control Center 側の表示を追従させる。
        ControlCenter.shared.reloadControls(ofKind: sleepToggleControlKind)
    }

    func setSoundEnabled(_ on: Bool) async {
        do {
            if on { try watcher.register() } else { try await watcher.unregister() }
            errorMessage = nil
        } catch {
            errorMessage = "警告音を切り替えられませんでした: \(error.localizedDescription)"
        }
        await refresh()
    }

    /// ヘルパの登録を作り直す。うまく動かないときの最終手段。
    func reinstallHelper() async {
        busy = true
        defer { busy = false }
        try? await helper.unregister()
        do {
            try helper.register()
            errorMessage = nil
        } catch {
            errorMessage = "ヘルパを登録できませんでした: \(error.localizedDescription)"
        }
        await refresh()
    }

    func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
