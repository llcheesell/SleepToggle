import SwiftUI

/// 主役のトグル。Control Center と同じ月＋斜線のシンボルを使う。
struct SleepButton: View {
    let isOn: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("moon.slash")
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(isOn ? Color.white : Color.secondary)
                .frame(width: 148, height: 148)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(
            // 不透明度を下げた tint はダークモードでほぼ見えず、ON/OFF の区別が文字色だけになる。
            isOn ? .regular.tint(.indigo).interactive() : .regular.interactive(),
            in: .circle
        )
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
        .animation(.snappy(duration: 0.2), value: isOn)
        .accessibilityLabel("スリープしない")
        .accessibilityValue(isOn ? "オン" : "オフ")
    }
}
