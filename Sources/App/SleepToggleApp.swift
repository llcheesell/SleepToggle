import AppKit
import SwiftUI

@main
struct SleepToggleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("Sleep Toggle", id: "main") {
            ContentView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
    }
}

/// LSUIElement なので Dock にもメニューバーにも常駐しない。
/// その状態ではウィンドウが前面に来ないため、明示的にアクティブ化する。
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        bringToFront()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows flag: Bool) -> Bool {
        bringToFront()
        return true
    }

    /// 設定と状態を見るだけの App なので、閉じたら常駐せず終了する。
    /// Control Center の操作にこの App は要らない。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func bringToFront() {
        // Scene の生成が終わる前だと windows が空なので、次のループに回す。
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first { $0.canBecomeKey }?.makeKeyAndOrderFront(nil)
        }
    }
}
