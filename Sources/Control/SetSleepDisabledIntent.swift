import AppIntents

/// Control Center のトグル本体。
/// `SetValueIntent` にしておくと Shortcuts / Spotlight からも同じ動作が呼べる。
struct SetSleepDisabledIntent: SetValueIntent {
    static let title: LocalizedStringResource = "スリープしないを切り替え"
    static let description = IntentDescription(
        "フタを閉じてもスリープしないかどうかを切り替えます。"
    )

    @Parameter(title: "スリープしない")
    var value: Bool

    func perform() async throws -> some IntentResult {
        // サンドボックス下なので pmset は叩けない。必ず特権ヘルパ経由。
        try await HelperClient.shared.setSleepDisabled(value)
        return .result()
    }
}
