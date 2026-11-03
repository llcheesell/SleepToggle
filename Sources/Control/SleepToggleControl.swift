import AppIntents
import SwiftUI
import WidgetKit

struct SleepDisabledValueProvider: ControlValueProvider {
    let previewValue = false

    func currentValue() async throws -> Bool {
        // appex は App Sandbox 必須で pmset を exec できないため、ヘルパ経由で読む。
        try await HelperClient.shared.readSleepDisabled()
    }
}

struct SleepToggleControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: sleepToggleControlKind,
            provider: SleepDisabledValueProvider()
        ) { isOn in
            // Control Center は SF Symbol かカスタムシンボル（.symbolset）しか描かない。
            // 普通の画像アセットを渡すと「?」になる。
            ControlWidgetToggle(isOn: isOn, action: SetSleepDisabledIntent()) {
                Label("スリープしない", image: "moon.slash")
            }
        }
        .displayName("スリープしない")
        .description("フタを閉じてもスリープしないように切り替えます。")
    }
}
