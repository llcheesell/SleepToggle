import ServiceManagement
import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 18) {
            SleepButton(isOn: model.sleepDisabled, enabled: model.helperReady && !model.busy) {
                Task { await model.toggle() }
            }
            .padding(.top, 8)

            VStack(spacing: 4) {
                Text(model.sleepDisabled ? "スリープしない" : "通常")
                    .font(.title3.weight(.semibold))
                Text(model.sleepDisabled ? "フタを閉じても起きたままです" : "フタを閉じるとスリープします")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .contentTransition(.opacity)
            .animation(.default, value: model.sleepDisabled)

            notice

            HStack {
                Text("Control Center から切り替えられます")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("設定")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 26)
        .padding(.bottom, 14)
        .frame(width: 300)
        .task { await model.bootstrap() }
        // Control Center / Shortcuts 側で切り替えられても表示を追従させる。
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.refresh() }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(model: model)
        }
    }

    /// 手当てが必要なときだけ出す一行。問題が無ければ何も表示しない。
    @ViewBuilder private var notice: some View {
        if model.needsApproval {
            VStack(spacing: 6) {
                Text("System設定で SleepToggle のバックグラウンド動作を許可してください")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                Button("System設定を開く") { model.openLoginItems() }
                    .controlSize(.small)
            }
        } else if let message = model.errorMessage {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// ふだん触らないものだけを置く。
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("設定").font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Toggle("フタを閉じたら音で知らせる", isOn: Binding(
                        get: { model.soundEnabled },
                        set: { on in Task { await model.setSoundEnabled(on) } }
                    ))
                    Spacer()
                    Button("試聴") { LidWarningSound.play() }
                        .controlSize(.small)
                }
                Text("スリープしない設定のままフタを閉じたときだけ鳴ります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                LabeledContent("特権ヘルパ") {
                    Text(statusText(model.helperStatus))
                        .foregroundStyle(model.helperReady ? Color.secondary : Color.orange)
                }
                Text("スリープ設定の変更には管理者権限が要るため、小さなヘルパを使っています。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("ヘルパを登録し直す") { Task { await model.reinstallHelper() } }
                    .controlSize(.small)
                    .disabled(model.busy)
            }

            Text("この設定は再起動しても残ります。使い終わったら戻してください。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("閉じる") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func statusText(_ status: SMAppService.Status) -> String {
        switch status {
        case .enabled: return "有効"
        case .requiresApproval: return "許可待ち"
        // 登録前は plist が存在していても notFound が返る。
        case .notRegistered, .notFound: return "未登録"
        @unknown default: return "不明"
        }
    }
}
