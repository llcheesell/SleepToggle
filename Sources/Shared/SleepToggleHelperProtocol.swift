import Foundation

/// 特権ヘルパの Mach サービス名。
/// LaunchDaemon plist の `MachServices` キーと必ず一致させること。
public let sleepToggleMachServiceName = "com.llcheesell.SleepToggle.helper"

/// ヘルパが接続を受け入れるクライアントの条件。
///
/// Mach サービス名は秘密ではないため、名前を知っているだけの無関係なプロセスから
/// スリープ設定を書き換えられないよう、Team ID とバンドル識別子の両方を要求する。
public let sleepToggleClientRequirement = """
anchor apple generic \
and certificate leaf[subject.OU] = "KCA45GR99A" \
and (identifier "com.llcheesell.SleepToggle" \
or identifier "com.llcheesell.SleepToggle.Control")
"""

/// クライアント側がヘルパを検証するための条件。
/// 偽のヘルパに繋いで状態を誤認させられるのを防ぐ。
public let sleepToggleHelperRequirement = """
anchor apple generic \
and certificate leaf[subject.OU] = "KCA45GR99A" \
and identifier "com.llcheesell.SleepToggle.helper"
"""

/// App / Control Center 拡張から特権ヘルパを呼ぶためのインターフェース。
@objc public protocol SleepToggleHelperProtocol {
    /// SleepDisabled を設定する。成功時 `errorMessage` は nil。
    func setSleepDisabled(_ disabled: Bool,
                          reply: @escaping (_ ok: Bool, _ errorMessage: String?) -> Void)

    /// 現在の SleepDisabled を返す。
    func readSleepDisabled(reply: @escaping (_ disabled: Bool) -> Void)

    /// ヘルパのバージョン。App 更新後に古いデーモンが動いたままなのを検出するために使う。
    func version(reply: @escaping (_ version: String) -> Void)
}
